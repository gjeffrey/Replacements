#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
iconset="$project_root/.build/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$project_root/Resources/AppIcon.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    retina_size=$((size*2))
    sips -z "$retina_size" "$retina_size" "$project_root/Resources/AppIcon.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$project_root/Resources/AppIcon.icns"
