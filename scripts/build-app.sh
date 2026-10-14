#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
configuration="${REPLACEMENTS_BUILD_CONFIGURATION:-release}"
output_dir="${REPLACEMENTS_OUTPUT_DIR:-$(dirname "$project_root")}"
cache_dir="$project_root/.build/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$cache_dir"
export SWIFTPM_MODULECACHE_OVERRIDE="$cache_dir"
mkdir -p "$output_dir"
build_args=(--package-path "$project_root" --cache-path "$project_root/.build/cache" --disable-sandbox -c "$configuration" --product Replacements)
if [[ "${1:-}" == "--universal" ]]; then
    # Build slices separately: SwiftPM's multi-arch path requires full Xcode's xcbuild.
    # Separate target triples and lipo also work with Command Line Tools.
    slice_paths=()
    for architecture in arm64 x86_64; do
        slice_args=("${build_args[@]}" --scratch-path "$project_root/.build/slices/$architecture" --triple "$architecture-apple-macosx15.0")
        swift build "${slice_args[@]}"
        slice_dir="$(swift build "${slice_args[@]}" --show-bin-path)"
        slice_paths+=("$slice_dir/Replacements")
    done
    bin_dir="$project_root/.build/universal/$configuration"
    mkdir -p "$bin_dir"
    lipo -create "${slice_paths[@]}" -output "$bin_dir/Replacements"
else
    swift build "${build_args[@]}"
    bin_dir="$(swift build "${build_args[@]}" --show-bin-path)"
fi
bundle="$output_dir/Replacements.app"
# Stage a fresh bundle; never replace a different product or touch /Applications.
staging="$(mktemp -d "${TMPDIR:-/private/tmp}/replacements-build.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
mkdir -p "$staging/Replacements.app/Contents/MacOS" "$staging/Replacements.app/Contents/Resources"
cp "$bin_dir/Replacements" "$staging/Replacements.app/Contents/MacOS/Replacements"
cp "$project_root/Resources/Info.plist" "$staging/Replacements.app/Contents/Info.plist"
cp "$project_root/Resources/Acknowledgements.md" "$staging/Replacements.app/Contents/Resources/"
cp "$project_root/LICENSE" "$staging/Replacements.app/Contents/Resources/"
cp "$project_root/Resources/AppIcon.icns" "$staging/Replacements.app/Contents/Resources/"
cp "$project_root/Resources/AppIcon.png" "$staging/Replacements.app/Contents/Resources/"
if [[ -n "${REPLACEMENTS_BUNDLE_ID:-}" ]]; then /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $REPLACEMENTS_BUNDLE_ID" "$staging/Replacements.app/Contents/Info.plist"; fi
# Remove only Finder presentation metadata that codesign rejects. Preserve quarantine and other attributes.
/usr/bin/xattr -dr com.apple.FinderInfo "$staging/Replacements.app" 2>/dev/null || true
/usr/bin/xattr -dr com.apple.ResourceFork "$staging/Replacements.app" 2>/dev/null || true
identity="${REPLACEMENTS_SIGNING_IDENTITY:--}"
if [[ "$identity" == "-" ]]; then
    codesign --force --sign - --options runtime "$staging/Replacements.app"
else
    codesign --force --sign "$identity" --options runtime --timestamp "$staging/Replacements.app"
fi
codesign --verify --strict --verbose=2 "$staging/Replacements.app"
if [[ -e "$bundle" ]]; then
    bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$bundle/Contents/Info.plist")"
    [[ "$bundle_id" == "local.replacements.mac" || "$bundle_id" == "${REPLACEMENTS_BUNDLE_ID:-local.replacements.mac}" ]] || { echo "Refusing to replace a different app." >&2; exit 1; }
    rm -rf "$bundle"
fi
mv "$staging/Replacements.app" "$bundle"
printf 'Built %s\n' "$bundle"
