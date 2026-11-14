import Foundation
import Combine

enum Phase { case noCamera, calibrating, running }

/// 카메라 한 장에서 잰 값
struct Sample {
    var distance = 1.0      // 두 눈 사이 간격 ÷ 기준 (1보다 크면 가까움)
    var roll = 0.0          // 고개 기울임 (라디안, 화면 기준 시계 방향 +)
    var drop = 0.0          // 기준보다 내려간 정도 (두 눈 사이 간격의 배수)
    var eye = 0.0           // 눈 높이/폭 비
    var eyeOpen = 0.0       // 평소 뜬 눈의 비
    var blinked = false
    var progress: Double?   // 기준 자세를 재는 중이면 진행 정도 (0~1)
}

/// 노치에 그릴 상태. 메인 스레드에서만 만짐
final class Model: ObservableObject {
    @Published var phase: Phase
    @Published var hasFace = false
    @Published var calibrationProgress = 0.0
    @Published var savedNote = false     // "기준 자세를 저장했어요"를 잠깐 보여 줌
    @Published var eyeShut = false       // 방금 깜빡임: 눈 아이콘을 잠깐 감음
    /// 아이콘 색을 정하는 값 (0 = 좋음, 1 = 가장 빨강)
    @Published var dryLevel = 0.0        // 마지막 깜빡임 뒤로 흐른 시간
    @Published var closeLevel = 0.0      // 기준보다 얼마나 가까운지. 자세 아이콘의 머리가 따라 커짐
    @Published var tilt = 0.0            // 고개 기울임 (라디안). 자세 아이콘이 따라 기움
    @Published var dropLevel = 0.0       // 얼굴이 내려간 정도. 자세 아이콘이 따라 내려감
    @Published var flashOn = true        // 점멸용: 0.4초마다 켜짐/꺼짐
    // 수치 보기용
    @Published var distance = 1.0
    @Published var eye = 0.0
    @Published var eyeOpen = 0.0
    @Published var blinksPerMinute = 0
    @Published var secondsSinceBlink = 0

    private let settings = Settings.shared
    private var lastBlink = Date()
    private var blinks: [Date] = []
    private var shutUntil = Date.distantPast
    private var savedUntil = Date.distantPast
    private var lastFace = Date.distantPast
    private var lastNumbers = Date.distantPast
    private var smoothDistance = 1.0, smoothRoll = 0.0, smoothDrop = 0.0
    private var ticks = 0

    init() { phase = Settings.shared.baseline == nil ? .calibrating : .running }

    /// 자세 아이콘의 색: 거리·기울임·내려앉음 중 가장 나쁜 값
    var postureLevel: Double {
        let degrees = abs(tilt) * 180 / .pi, free = 6.0   // 6도까지의 기울임은 괜찮음
        return max(closeLevel, dropLevel, min(1, max(0, (degrees - free) / max(1, settings.tiltDegrees - free))))
    }

    func cameraUnavailable() { phase = .noCamera }
    func startCalibration() { if phase != .noCamera { phase = .calibrating; calibrationProgress = 0 } }
    func calibrated() {
        phase = .running
        savedUntil = Date().addingTimeInterval(1.8)
        savedNote = true
        lastBlink = Date()
    }
    /// 기준을 재는 중에 얼굴이 사라짐
    func calibrationLostFace() { if calibrationProgress != 0 { calibrationProgress = 0 } }

    func frame(_ s: Sample) {
        let now = Date()
        lastFace = now
        if let progress = s.progress {
            let step = (progress * 40).rounded() / 40
            if step != calibrationProgress { calibrationProgress = step }
            lastBlink = now
            refresh()
            return
        }
        // 화면을 다시 그리게 하는 값은 눈에 띄게 달라졌을 때만 바꿈 (매 장 바꾸면 CPU를 많이 씀)
        smoothDistance += (s.distance - smoothDistance) * 0.15
        smoothRoll += (s.roll - smoothRoll) * 0.3
        smoothDrop += (s.drop - smoothDrop) * 0.3
        let near = min(1, max(0, (smoothDistance - 1) / max(0.01, settings.closePercent / 100)))
        if abs(near - closeLevel) >= 0.03 || (near != closeLevel && (near == 0 || near == 1)) { closeLevel = near }
        let step = 3 * Double.pi / 180                                   // 3도 단위로만 움직임
        let angle = (max(-0.7, min(0.7, smoothRoll)) / step).rounded() * step
        if angle != tilt { tilt = angle }
        let sink = (min(1, max(0, smoothDrop / (settings.dropCm / 6.3))) * 10).rounded() / 10   // 두 눈 사이는 약 6.3cm
        if sink != dropLevel { dropLevel = sink }
        if settings.showNumbers, now.timeIntervalSince(lastNumbers) > 0.25 {
            lastNumbers = now
            distance = s.distance; eye = s.eye; eyeOpen = s.eyeOpen
        }
        if s.blinked {
            lastBlink = now
            blinks.append(now)
            shutUntil = now.addingTimeInterval(0.3)
            dryLevel = 0
        }
        refresh()
    }

    /// 시간이 흐르는 것만으로 바뀌는 상태 (0.2초마다)
    func refresh() {
        let now = Date()
        ticks += 1
        let flash = dryLevel >= 1 || postureLevel >= 1 ? (ticks / 2) % 2 == 0 : true
        if flash != flashOn { flashOn = flash }
        let face = now.timeIntervalSince(lastFace) < 1.5
        if face != hasFace { hasFace = face }
        if !face { lastBlink = now }   // 자리에 없으면 세지 않음
        if !face, closeLevel != 0 || tilt != 0 || dropLevel != 0 { closeLevel = 0; tilt = 0; dropLevel = 0 }
        blinks.removeAll { now.timeIntervalSince($0) > 60 }
        if blinks.count != blinksPerMinute { blinksPerMinute = blinks.count }
        let seconds = Int(now.timeIntervalSince(lastBlink))
        if seconds != secondsSinceBlink { secondsSinceBlink = seconds }
        let dry = (min(1, now.timeIntervalSince(lastBlink) / max(1, settings.dryAfter)) * 25).rounded() / 25
        if dry != dryLevel { dryLevel = dry }
        let shut = now < shutUntil
        if shut != eyeShut { eyeShut = shut }
        let saved = now < savedUntil
        if saved != savedNote { savedNote = saved }
    }
}
