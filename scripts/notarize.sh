#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="${REPLACEMENTS_OUTPUT_DIR:-$(dirname "$project_root")}"
bundle="$output_dir/Replacements.app"
: "${REPLACEMENTS_NOTARY_PROFILE:?Set REPLACEMENTS_NOTARY_PROFILE to an existing notarytool keychain profile.}"
[[ -d "$bundle" ]] || { echo "Build the app first." >&2; exit 1; }
# Finder metadata is presentation data, not a security attribute. Keep quarantine intact.
xattr -dr com.apple.FinderInfo "$bundle" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$bundle" 2>/dev/null || true
codesign --verify --strict --verbose=2 "$bundle"
signature="$(codesign -dv --verbose=2 "$bundle" 2>&1)"
[[ "$signature" == *"Authority=Developer ID Application:"* ]] || { echo "Developer ID Application signing is required; ad-hoc builds cannot be notarized." >&2; exit 1; }
submission_file="$output_dir/notarization-submission.json"
if [[ "${1:-}" != "--resume" ]]; then
    [[ ! -e "$submission_file" ]] || { echo "A submission record already exists. Use --resume; do not submit again blindly." >&2; exit 1; }
    archive="$output_dir/Replacements-notary.zip"
    ditto -c -k --keepParent "$bundle" "$archive"
    # Save the ID as soon as upload finishes, before waiting for Apple processing.
    xcrun notarytool submit "$archive" --keychain-profile "$REPLACEMENTS_NOTARY_PROFILE" --output-format json > "$submission_file"
    shasum -a 256 "$archive" > "$output_dir/notarization-archive.sha256"
fi
submission_id="$(/usr/bin/python3 - "$submission_file" <<'PY'
import json,sys,uuid
result=json.load(open(sys.argv[1])); print(uuid.UUID(result['id']))
PY
)"
printf 'Waiting on notarization submission %s\n' "$submission_id"
# A wait timeout leaves the same saved ID ready for --resume; it never resubmits.
xcrun notarytool wait "$submission_id" --keychain-profile "$REPLACEMENTS_NOTARY_PROFILE" --timeout 5m --output-format json > "$output_dir/notarization-result.json"
xcrun notarytool log "$submission_id" --keychain-profile "$REPLACEMENTS_NOTARY_PROFILE" "$output_dir/notarization-log.json"
/usr/bin/python3 - "$output_dir/notarization-result.json" <<'PY'
import json,sys
result=json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    print('Notarization was not accepted. Inspect notarization-log.json before rebuilding or resubmitting.', file=sys.stderr)
    sys.exit(1)
PY
xcrun stapler staple "$bundle"
xcrun stapler validate "$bundle"
codesign --verify --strict --verbose=2 "$bundle"
spctl --assess --type execute --verbose=2 "$bundle"
ditto -c -k --keepParent "$bundle" "$output_dir/Replacements.zip"
