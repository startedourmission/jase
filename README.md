# jase

자세와 눈 깜빡임을 MacBook 노치 옆 작은 아이콘 둘로 보여 주는 앱.

- **자세 아이콘**: 화면에 다가가면 머리가 커지고, 고개를 기울이면 같이 기울고, 내려앉으면 어깨 사이로 내려간다. 좋으면 초록, 나빠질수록 노랑 → 빨강, 한계에 닿으면 깜빡거린다.
- **눈 아이콘**: 깜빡일 때마다 잠깐 감겼다가 초록으로 돌아온다. 오래 안 깜빡일수록 빨개진다.
- 영상은 Apple Vision 프레임워크로 메모리에서만 분석하고 저장하지 않는다. 네트워크를 쓰지 않는다.

소개 페이지: https://startedourmission.github.io/jase/

받기: [jase.dmg](https://github.com/startedourmission/jase/releases/latest/download/jase.dmg) (무료, Apple 공증)

## 빌드

macOS 14 이상, Xcode 명령줄 도구.

```sh
./build.sh            # build/jase.app (ad-hoc 서명)
open build/jase.app
```

배포 파일은 `./release.sh` (Developer ID 서명 → DMG → 공증, 준비물은 스크립트 머리말 참고).

처음 켜면 카메라 허용을 묻고, 노치 아래 안내에 따라 몇 초 동안 기준 자세를 잰다. 다시 빌드하면 카메라 허용을 다시 물을 수 있다.

## 구조

| 파일 | 하는 일 |
|---|---|
| `Sources/Jase/Monitor.swift` | 카메라 → 얼굴 자리와 눈 윤곽 → 거리·기울임·높이·깜빡임 |
| `Sources/Jase/Model.swift` | 잰 값을 아이콘 색과 움직임으로 |
| `Sources/Jase/NotchView.swift` | 노치 옆 아이콘과 기준 자세 안내 |
| `Sources/Jase/SettingsView.swift`, `Settings.swift` | 설정 창과 저장 (언어, CPU 사용, 경고 기준) |
| `tools/make-icon.sh` | 앱 아이콘 다시 만들기 |
| `docs/` | 소개 페이지 (GitHub Pages) |

설정 화면 그림은 `build/jase.app/Contents/MacOS/Jase --snapshot-settings docs/settings-ko.png ko` 로 다시 만든다.

jase는 의료 기기가 아니다.
