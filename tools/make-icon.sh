#!/bin/zsh
# 아이콘 그림을 다시 만들어 Resources/AppIcon.icns 와 docs/icon.png 로 저장
set -euo pipefail
cd "${0:A:h}/.."
tmp=$(mktemp -d)
swift tools/icon.swift "$tmp/1024.png"
set=$tmp/AppIcon.iconset
mkdir "$set"
for s in 16 32 128 256 512; do
  sips -z $s $s "$tmp/1024.png" --out "$set/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$tmp/1024.png" --out "$set/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$set" -o Resources/AppIcon.icns
sips -z 512 512 "$tmp/1024.png" --out docs/icon.png >/dev/null
rm -rf "$tmp"
