#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
archive="${1:?Usage: generate-update.sh final-notarized.zip [output-appcast.xml] [release-notes.md]}"
output="${2:-$project_root/appcast.xml}"
tools_dir="${REPLACEMENTS_SPARKLE_BIN:-$project_root/.build/artifacts/sparkle/Sparkle/bin}"
account="${REPLACEMENTS_SPARKLE_ACCOUNT:-com.gabrieljeffrey.replacements}"
repository="${REPLACEMENTS_GITHUB_REPOSITORY:-gjeffrey/Replacements}"
[[ "$repository" =~ ^[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+$ ]] || { echo "Invalid GitHub repository." >&2; exit 1; }
[[ -x "$tools_dir/generate_appcast" ]] || { echo "Resolve Sparkle or set REPLACEMENTS_SPARKLE_BIN to its official bin directory." >&2; exit 1; }
stage="$(mktemp -d "${TMPDIR:-/private/tmp}/replacements-appcast.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/updates" "$stage/check"
cp "$archive" "$stage/updates/Replacements.zip"
ditto -x -k "$stage/updates/Replacements.zip" "$stage/check"
bundle="$stage/check/Replacements.app"
codesign --verify --deep --strict "$bundle"
signature="$(codesign -dv --verbose=2 "$bundle" 2>&1)"
[[ "$signature" == *"Authority=Developer ID Application:"* ]] || { echo "Developer ID signing is required." >&2; exit 1; }
xcrun stapler validate "$bundle"
spctl --assess --type execute "$bundle"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$bundle/Contents/Info.plist")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "A three-part release version is required." >&2; exit 1; }
embedded_key="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$bundle/Contents/Info.plist")"
public_key="$("$tools_dir/generate_keys" --account "$account" -p)"
[[ "$embedded_key" == "$public_key" ]] || { echo "The Keychain signing key does not match the app's public key." >&2; exit 1; }
if [[ -n "${3:-}" ]]; then cp "$3" "$stage/updates/Replacements.md"; fi
"$tools_dir/generate_appcast" --account "$account" --maximum-deltas 0 --embed-release-notes \
    --download-url-prefix "https://github.com/$repository/releases/download/v$version/" \
    --link "https://github.com/$repository/releases/tag/v$version" \
    -o "$stage/updates/appcast.xml" "$stage/updates"
cp "$stage/updates/appcast.xml" "$output"
printf 'Generated signed update feed: %s\nUpload the exact archive before publishing this feed.\n' "$output"
