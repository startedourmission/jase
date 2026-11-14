#!/bin/zsh
# jase.app을 만든다 (ad-hoc 서명). 다시 빌드하면 카메라 허용을 다시 물어볼 수 있음
set -euo pipefail
cd "${0:A:h}"
swift build -c release
app=build/jase.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
cp .build/release/Jase "$app/Contents/MacOS/Jase"
cp Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
echo "$app"
