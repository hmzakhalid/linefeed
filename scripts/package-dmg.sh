#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
cd "$project_dir"

app_path=${1:-".build/Linefeed.app"}
dmg_path=${2:-".build/Linefeed-macOS-arm64.dmg"}
volume_name=${LINEFEED_DMG_VOLUME_NAME:-"Linefeed"}

if [[ ! -d "$app_path" ]]; then
  print -u2 "Linefeed app not found at $app_path. Run ./scripts/build-app.sh first."
  exit 1
fi

mkdir -p "${dmg_path:h}"
package_work_dir=$(mktemp -d /tmp/linefeed-dmg.XXXXXX)
staging_dir="$package_work_dir/staging"
mount_dir="$package_work_dir/mount"
mounted=0

cleanup() {
  if (( mounted )); then
    hdiutil detach "$mount_dir" -quiet || true
  fi
  rm -rf "$package_work_dir"
}
trap cleanup EXIT

mkdir -p "$staging_dir" "$mount_dir"
ditto "$app_path" "$staging_dir/Linefeed.app"
ln -s /Applications "$staging_dir/Applications"

hdiutil create \
  -volname "$volume_name" \
  -srcfolder "$staging_dir" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  "$dmg_path" \
  >/dev/null

hdiutil verify "$dmg_path" >/dev/null
hdiutil attach "$dmg_path" -nobrowse -readonly -mountpoint "$mount_dir" -quiet
mounted=1

codesign --verify --deep --strict --verbose=2 "$mount_dir/Linefeed.app"
if [[ ! -L "$mount_dir/Applications" || "$(readlink "$mount_dir/Applications")" != "/Applications" ]]; then
  print -u2 "The Applications shortcut is missing or invalid."
  exit 1
fi

hdiutil detach "$mount_dir" -quiet
mounted=0

print "Created $dmg_path"
shasum -a 256 "$dmg_path"
