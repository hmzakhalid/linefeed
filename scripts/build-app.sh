#!/bin/zsh
# Builds, signs, and opens .build/Linefeed.app.
set -euo pipefail

project_dir=${0:A:h:h}
cd "$project_dir"
app_dir=".build/Linefeed.app"

swift build -c release

if pgrep -x Linefeed >/dev/null; then
  osascript -e 'tell application id "app.linefeed.desktop" to quit'
  for _ in {1..50}; do
    pgrep -x Linefeed >/dev/null || break
    sleep 0.1
  done
  if pgrep -x Linefeed >/dev/null; then
    print -u2 "Linefeed did not quit cleanly; close it and run the build again."
    exit 1
  fi
fi

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp ".build/release/Linefeed" "$app_dir/Contents/MacOS/Linefeed"
cp "Info.plist" "$app_dir/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
cp LICENSE NOTICE.md "$app_dir/Contents/Resources/"
fluidaudio=".build/checkouts/FluidAudio"
mkdir -p "$app_dir/Contents/Resources/Licenses"
cp "$fluidaudio/LICENSE" "$app_dir/Contents/Resources/Licenses/FluidAudio-LICENSE"
cp "$fluidaudio"/ThirdPartyLicenses/* "$app_dir/Contents/Resources/Licenses/"

# Apple Intelligence cleanup must not stop the app from launching before macOS 26.
if otool -L "$app_dir/Contents/MacOS/Linefeed" | grep FoundationModels | grep -vq weak; then
  print -u2 "FoundationModels is linked strongly; Linefeed would not launch before macOS 26."
  exit 1
fi

# macOS ties privacy permissions to the signing identity, so a stable local
# identity keeps them across rebuilds. Ad-hoc signing works but forgets them.
local_identity_name=${LINEFEED_LOCAL_IDENTITY_NAME:-"Linefeed Local Development"}
available_identities=$(security find-identity -v -p codesigning)
preferred_identity=$(
  print -r -- "$available_identities" \
    | awk -v name="$local_identity_name" 'index($0, "\"" name "\"") { print $2; exit }'
)
signing_identity=${LINEFEED_SIGNING_IDENTITY:-${preferred_identity:-"-"}}
if [[ "$signing_identity" == "-" ]]; then
  print -u2 "No Linefeed signing identity found; signing ad hoc."
  print -u2 "Run ./scripts/setup-signing-identity.sh once to keep privacy permissions across builds."
fi
codesign --force --sign "$signing_identity" "$app_dir"
codesign --verify --deep --strict "$app_dir"

if [[ ${LINEFEED_SKIP_OPEN:-0} != 1 ]]; then
  open -n "$app_dir"
fi
