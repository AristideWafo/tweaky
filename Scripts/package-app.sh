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
install -m 644 "$repository_root/Resources/MenuBarIcon.png" "$repository_root/Resources/MenuBarIcon@2x.png" "$contents_root/Resources/"

# File-provider workspaces can attach Finder metadata that invalidates a code signature.
xattr -cr "$app_root"

if [[ -n "${TWEAKY_SIGNING_IDENTITY:-}" ]]; then
    codesign --force --deep --options runtime --timestamp --sign "$TWEAKY_SIGNING_IDENTITY" "$app_root"
elif [[ "${TWEAKY_ADHOC_SIGN:-1}" == "1" ]]; then
    codesign --force --deep --sign - "$app_root"
fi

# A synchronized workspace may reattach FinderInfo while signing; remove it again.
xattr -cr "$app_root"

echo "$app_root"
