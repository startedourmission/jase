#!/bin/zsh
# 배포 파일 만들기: build.sh로 빌드 → Developer ID로 다시 서명 → DMG → Apple 공증 → 확인
#
# 처음 한 번 (Apple 개발자 프로그램 가입 후):
#   1) Xcode > Settings > Accounts > Manage Certificates > + > "Developer ID Application"
#   2) 공증용 암호를 키체인에 저장 (앱 암호는 account.apple.com > 로그인 및 보안 > 앱 암호에서)
#      xcrun notarytool store-credentials jase-notary --apple-id <Apple ID> --team-id <팀 ID> --password <앱 암호>
#
# 실행:
#   ./release.sh                       # 키체인에 Developer ID Application 인증서가 하나면 알아서 고름
#   JASE_SIGN_ID="Developer ID Application: 이름 (팀 ID)" ./release.sh
#
# 결과: build/jase-<버전>.dmg
# 평소 개발용 빌드는 그대로 build.sh (ad-hoc 서명)
set -euo pipefail
cd "${0:A:h}"

SIGN_ID=${JASE_SIGN_ID:-$(security find-identity -v -p codesigning | grep -v REVOKED | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)}
# 공증 프로필은 계정에 딸린 것이라 Twinkle용으로 저장해 둔 것도 그대로 쓸 수 있음
PROFILE=${JASE_NOTARY_PROFILE:-}
if [[ -z "$PROFILE" ]]; then
    for name in jase-notary twinkle-notary; do
        if xcrun notarytool history --keychain-profile $name >/dev/null 2>&1; then PROFILE=$name; break; fi
    done
fi
[[ -n "$PROFILE" ]] || { echo "공증 프로필이 없습니다 (위의 '처음 한 번' 2번)" >&2; exit 1; }
case "$SIGN_ID" in
    "Developer ID Application:"*) ;;
    *) echo "Developer ID Application 인증서가 없습니다 (Apple Development 인증서는 배포용이 아니고, 폐기된 걸로 서명하면 macOS가 앱을 지움). security find-identity -v -p codesigning 으로 확인해 주세요" >&2; exit 1 ;;
esac

./build.sh
APP=build/jase.app
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")

# 공증에는 Hardened Runtime(--options runtime)과 보안 타임스탬프가 필요
codesign --force --options runtime --timestamp --entitlements Resources/jase.entitlements --sign "$SIGN_ID" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

# DMG: 앱 + 응용 프로그램 폴더 바로 가기 (끌어다 놓아 설치)
DMG="build/jase-$VERSION.dmg"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/jase.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "jase" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
codesign --force --timestamp --sign "$SIGN_ID" "$DMG"

# 공증 (몇 분 걸림). 인증서가 폐기됐거나 문제가 있으면 여기서 거절됨
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"

# 받은 사람 Mac에서처럼 Gatekeeper가 받아 주는지 확인. "source=Notarized Developer ID"가 나와야 함
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
echo "완료: $DMG"
