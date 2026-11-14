import Foundation
import Combine

enum Lang: String, CaseIterable { case ko, en }

/// CPU를 얼마나 쓸지 = 초당 몇 장을 분석할지. 적게 보면 배터리를 아끼지만 짧은 깜빡임을 놓칠 수 있다
enum Power: String, CaseIterable {
    case low, medium, high
    var fps: Double { switch self { case .low: 6; case .medium: 10; case .high: 15 } }
}

/// 사용자가 바꿀 수 있는 값. UserDefaults에 저장
final class Settings: ObservableObject {
    static let shared = Settings()
    private let store = UserDefaults.standard

    @Published var language: Lang { didSet { store.set(language.rawValue, forKey: "language") } }
    @Published var power: Power { didSet { store.set(power.rawValue, forKey: "power") } }
    /// 이만큼(초) 안 깜빡이면 눈 아이콘이 가장 빨개짐
    @Published var dryAfter: Double { didSet { store.set(dryAfter, forKey: "dryAfter") } }
    /// 기준보다 이만큼(%) 가까워지면 자세 아이콘이 가장 빨개짐
    @Published var closePercent: Double { didSet { store.set(closePercent, forKey: "closePercent") } }
    /// 고개가 이만큼(도) 기울면 가장 빨개짐
    @Published var tiltDegrees: Double { didSet { store.set(tiltDegrees, forKey: "tiltDegrees") } }
    /// 얼굴이 이만큼(cm, 어림) 내려가면 가장 빨개짐
    @Published var dropCm: Double { didSet { store.set(dropCm, forKey: "dropCm") } }
    @Published var showNumbers = false

    static let defaults = (dryAfter: 10.0, closePercent: 20.0, tiltDegrees: 22.0, dropCm: 7.5)

    private init() {
        let system: Lang = (Locale.preferredLanguages.first ?? "en").hasPrefix("ko") ? .ko : .en
        language = Lang(rawValue: store.string(forKey: "language") ?? "") ?? system
        power = Power(rawValue: store.string(forKey: "power") ?? "") ?? .medium
        dryAfter = store.object(forKey: "dryAfter") as? Double ?? Self.defaults.dryAfter
        closePercent = store.object(forKey: "closePercent") as? Double ?? Self.defaults.closePercent
        tiltDegrees = store.object(forKey: "tiltDegrees") as? Double ?? Self.defaults.tiltDegrees
        dropCm = store.object(forKey: "dropCm") as? Double ?? Self.defaults.dropCm
    }

    func resetThresholds() {
        dryAfter = Self.defaults.dryAfter
        closePercent = Self.defaults.closePercent
        tiltDegrees = Self.defaults.tiltDegrees
        dropCm = Self.defaults.dropCm
    }

    /// 기준 자세: 두 눈 사이 간격(영상 폭 대비)과 눈 높이(영상 높이 대비). 한 번 재면 다음 실행에도 씀
    var baseline: (width: Double, height: Double)? {
        get {
            guard let width = store.object(forKey: "baselineWidth") as? Double, let height = store.object(forKey: "baselineHeight") as? Double, width > 0 else { return nil }
            return (width, height)
        }
        set {
            store.set(newValue?.width, forKey: "baselineWidth")
            store.set(newValue?.height, forKey: "baselineHeight")
        }
    }
}

/// 지금 언어에 맞는 글
func L(_ ko: String, _ en: String) -> String { Settings.shared.language == .ko ? ko : en }
