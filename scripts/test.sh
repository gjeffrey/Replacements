#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
export CLANG_MODULE_CACHE_PATH="$project_root/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_root/.build/ModuleCache"
args=(--package-path "$project_root" --cache-path "$project_root/.build/cache" --disable-sandbox)
if [[ -n "${REPLACEMENTS_TEST_BUILD_DIR:-}" ]]; then args+=(--scratch-path "$REPLACEMENTS_TEST_BUILD_DIR"); fi
# SwiftPM on this Command Line Tools installation omits the testing framework search path.
developer_dir="$(xcode-select -p)"
for candidate in "$developer_dir/Library/Developer/Frameworks" "$developer_dir/Platforms/MacOSX.platform/Developer/Library/Frameworks"; do
    if [[ -d "$candidate/Testing.framework" ]]; then
        args+=(-Xswiftc -F -Xswiftc "$candidate" -Xlinker -F -Xlinker "$candidate" -Xlinker -rpath -Xlinker "$candidate" -Xlinker -rpath -Xlinker "$developer_dir/Library/Developer/usr/lib")
        break
    fi
done
swift test "${args[@]}"
