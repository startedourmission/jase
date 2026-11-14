import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    let recalibrate: () -> Void
    static let site = URL(string: "https://startedourmission.github.io/jase/")!

    var body: some View {
        Form {
            Section(L("일반", "General")) {
                Picker(L("언어", "Language"), selection: $settings.language) {
                    Text("한국어").tag(Lang.ko)
                    Text("English").tag(Lang.en)
                }
                .pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 6) {
                    Picker(L("CPU 사용", "CPU use"), selection: $settings.power) {
                        Text(L("적음", "Low")).tag(Power.low)
                        Text(L("보통", "Medium")).tag(Power.medium)
                        Text(L("많음", "High")).tag(Power.high)
                    }
                    .pickerStyle(.segmented)
                    note(L("카메라를 초당 몇 번 볼지 정해요 (\(Int(settings.power.fps))번). 적을수록 배터리를 아끼지만 짧은 깜빡임을 놓칠 수 있어요.",
                           "How often jase looks at the camera (\(Int(settings.power.fps)) times a second). Lower saves battery but can miss quick blinks."))
                }
            }

            Section(L("눈", "Eyes")) {
                slider(L("깜빡임 경고", "Blink warning"), $settings.dryAfter, 4...30, 1,
                       L("\(Int(settings.dryAfter))초", "\(Int(settings.dryAfter)) s"),
                       L("이만큼 안 깜빡이면 눈 아이콘이 빨갛게 깜빡거려요.", "The eye icon flashes red after this long without a blink."))
            }

            Section(L("자세", "Posture")) {
                slider(L("화면과의 거리", "Distance to screen"), $settings.closePercent, 5...60, 1,
                       "\(Int(settings.closePercent))%",
                       L("기준 자세보다 이만큼 가까워지면 빨개져요.", "Turns red when you're this much closer than your baseline."))
                slider(L("고개 기울임", "Head tilt"), $settings.tiltDegrees, 10...40, 1,
                       "\(Int(settings.tiltDegrees))°",
                       L("고개가 이만큼 기울면 빨개져요.", "Turns red when your head tilts this far."))
                slider(L("내려앉음", "Slouch"), $settings.dropCm, 3...15, 0.5,
                       L(String(format: "약 %.1fcm", settings.dropCm), String(format: "about %.1f cm", settings.dropCm)),
                       L("얼굴이 기준보다 이만큼 내려가면 빨개져요.", "Turns red when your face drops this far below your baseline."))
                HStack {
                    Button(L("기준 자세 다시 재기", "Set baseline again"), action: recalibrate)
                    Spacer()
                    Button(L("기본값으로", "Reset to defaults")) { settings.resetThresholds() }
                }
            }

            Section(L("정보", "About")) {
                HStack(alignment: .top, spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("jase \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")").font(.headline)
                        Text(L("자세와 눈 깜빡임을 노치에서 조용히 알려 주는 앱", "A quiet posture and blink monitor that lives in your notch"))
                        note(L("영상은 이 Mac 안에서만 처리하고, 저장하거나 밖으로 보내지 않아요.", "Video is processed on this Mac only. Nothing is saved or sent anywhere."))
                        Link(L("웹사이트", "Website"), destination: Self.site).font(.callout)
                    }
                }
                Toggle(L("수치 보기 (기준값을 맞출 때)", "Show numbers (for tuning)"), isOn: $settings.showNumbers)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 760)
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }

    private func slider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, _ step: Double, _ shown: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(shown).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
            note(detail)
        }
    }
}
