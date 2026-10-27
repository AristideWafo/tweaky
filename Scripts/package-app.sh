#!/usr/bin/env bash
set -euo pipefail

configuration="${1:-release}"
repository_root="$(cd "$(dirname "$0")/.." && pwd)"
output_root="$repository_root/dist"
app_root="$output_root/Tweaky.app"
contents_root="$app_root/Contents"

cd "$repository_root"
swift build -c "$configuration"
binary_root="$(swift build -c "$configuration" --show-bin-path)"

if [[ "$app_root" != "$repository_root/dist/Tweaky.app" ]]; then
    echo "Refusing to clean unexpected package path: $app_root" >&2
    exit 1
fi
rm -rf "$app_root"
install -d "$contents_root/MacOS" "$contents_root/Resources"
install -m 755 "$binary_root/Tweaky" "$contents_root/MacOS/Tweaky"
install -m 644 "$repository_root/Resources/Info.plist" "$contents_root/Info.plist"
install -m 644 "$repository_root/Resources/AppIcon.png" "$contents_root/Resources/AppIcon.png"

if [[ "${TWEAKY_ADHOC_SIGN:-1}" == "1" ]]; then
    codesign --force --deep --sign - "$app_root"
fi

echo "$app_root"
