import SwiftUI

/// 노치 왼쪽에 늘 떠 있는 아이콘 둘: 자세(거리·기울임·내려앉음)와 눈(안 깜빡인 시간).
/// 좋으면 초록, 나빠질수록 노랑 → 빨강. 가장 빨간 상태면 깜빡거린다.
/// 글자는 기준 자세를 잴 때와 카메라를 못 쓸 때만 노치 아래로 펼쳐서 보여 준다.
struct NotchView: View {
    @ObservedObject var model: Model
    @ObservedObject var settings = Settings.shared
    let notch: CGSize
    private let ear: CGFloat = 66   // 노치 왼쪽으로 나오는 폭 (아이콘 두 개 자리)

    private var active: Bool { model.phase == .running && model.hasFace }
    private var guiding: Bool { model.phase != .running || model.savedNote }
    private var open: Bool { guiding || settings.showNumbers }
    private var size: CGSize {
        CGSize(width: notch.width + ear * (open ? 2 : 1), height: notch.height + (guiding ? 50 : 0) + (settings.showNumbers ? 24 : 0))
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                UnevenRoundedRectangle(bottomLeadingRadius: open ? 18 : 12, bottomTrailingRadius: open ? 18 : 12).fill(.black)
                HStack(spacing: 10) {
                    icon(level: model.postureLevel) {
                        PostureIcon(tilt: active ? model.tilt : 0, drop: active ? model.dropLevel : 0, close: active ? model.closeLevel : 0)
                    }
                    icon(level: model.dryLevel) {
                        if model.phase == .noCamera { Image(systemName: "eye.slash.fill").font(.system(size: 14, weight: .semibold)) }
                        else if model.eyeShut { ClosedEye().stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round)).frame(width: 18, height: 11) }
                        else { Image(systemName: "eye.fill").font(.system(size: 14, weight: .semibold)) }
                    }
                    .frame(width: 22)
                }
                .padding(.leading, 6)
                .frame(width: ear, height: notch.height)
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 4) {
                    if guiding { guide.frame(height: 42) }
                    if settings.showNumbers { numbers.frame(height: 20) }
                }
                .padding(.top, notch.height)
                .padding(.horizontal, 18)
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            .offset(x: open ? 0 : -ear / 2)   // 평소엔 왼쪽으로만, 펼칠 땐 양쪽으로
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.34, dampingFraction: 0.8), value: open)
        .animation(.spring(response: 0.34, dampingFraction: 0.8), value: guiding)
    }

    /// 기준 자세 안내
    @ViewBuilder private var guide: some View {
        if model.phase == .noCamera {
            line(L("카메라를 쓸 수 없어요", "Can't use the camera"), L("시스템 설정 › 개인정보 보호 및 보안 › 카메라에서 jase를 허용해 주세요", "Allow jase in System Settings › Privacy & Security › Camera"))
        } else if model.savedNote {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(red: 0.25, green: 0.86, blue: 0.42))
                Text(L("기준 자세를 저장했어요", "Saved your baseline posture")).foregroundStyle(.white)
            }
            .font(.system(size: 14, weight: .semibold))
        } else if !model.hasFace {
            line(L("기준 자세를 잴게요", "Let's set your baseline"), L("카메라에 얼굴이 보이게 앉아 주세요", "Sit so the camera can see your face"))
        } else {
            VStack(spacing: 6) {
                Text(model.calibrationProgress < 0.4
                     ? L("허리를 펴고, 평소 거리에서 화면을 봐 주세요", "Sit up straight and look at the screen from your usual distance")
                     : L("좋아요. 그대로 잠깐만 있어 주세요", "Good. Hold still for a moment"))
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
                GeometryReader { box in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.18))
                        Capsule().fill(Color(red: 0.25, green: 0.86, blue: 0.42)).frame(width: box.size.width * model.calibrationProgress)
                    }
                }
                .frame(height: 4)
                .animation(.linear(duration: 0.15), value: model.calibrationProgress)
            }
        }
    }

    private func line(_ title: String, _ detail: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            Text(detail).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.6)).lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private var numbers: some View {
        Text(model.hasFace
             ? String(format: L("거리 %.2f×  ·  눈 %.2f / %.2f  ·  깜빡임 %d회/분  ·  %d초 전", "distance %.2f×  ·  eye %.2f / %.2f  ·  %d blinks/min  ·  %ds ago"),
                      model.distance, model.eye, model.eyeOpen, model.blinksPerMinute, model.secondsSinceBlink)
             : L("얼굴이 안 보여요", "No face in view"))
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
            .lineLimit(1).minimumScaleFactor(0.7)
    }

    private func icon<Content: View>(level: Double, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .foregroundStyle(active ? color(level) : Color.gray.opacity(0.7))   // 얼굴이 없거나 기준을 재는 중이면 회색
            .opacity(active && level >= 1 && !model.flashOn ? 0.15 : 1)        // 가장 빨갈 때 점멸
    }

    /// 0(초록) → 0.55(노랑) → 1(빨강)
    private func color(_ value: Double) -> Color {
        let green = (0.25, 0.86, 0.42), yellow = (1.0, 0.82, 0.22), red = (1.0, 0.27, 0.25)
        let (a, b, t) = value < 0.55 ? (green, yellow, value / 0.55) : (yellow, red, (value - 0.55) / 0.45)
        return Color(red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t)
    }
}

/// 감은 눈: 아래로 휜 눈꺼풀 선과 속눈썹 셋
struct ClosedEye: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + 1, y: r.minY + r.height * 0.3))
        p.addQuadCurve(to: CGPoint(x: r.maxX - 1, y: r.minY + r.height * 0.3), control: CGPoint(x: r.midX, y: r.minY + r.height * 1.05))
        for (x, dx) in [(0.24, -0.09), (0.5, 0.0), (0.76, 0.09)] {
            let y = x == 0.5 ? 0.68 : 0.58
            p.move(to: CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y))
            p.addLine(to: CGPoint(x: r.minX + r.width * (x + dx), y: r.minY + r.height * (y + 0.34)))
        }
        return p
    }
}

/// 자세 아이콘: 어깨 위의 머리가 사용자를 따라 움직인다. 고개를 기울이면 기울고, 내려앉으면 어깨 사이로 내려가고, 가까워지면 커진다
struct PostureIcon: View {
    let tilt: Double    // 라디안, 시계 방향 +
    let drop: Double    // 0~1
    let close: Double   // 0~1

    var body: some View {
        ZStack(alignment: .bottom) {
            UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6).frame(width: 20, height: 7)
            ZStack {
                Circle().stroke(Color.black, lineWidth: 3)   // 어깨와 겹칠 때 머리 윤곽이 보이게
                Circle()
                HStack(spacing: 2.6) {
                    Circle().frame(width: 2, height: 2)
                    Circle().frame(width: 2, height: 2)
                }
                .foregroundStyle(Color.black)
                .offset(y: -0.5)
            }
            .frame(width: 12, height: 12)
            .scaleEffect(1 + 0.3 * close, anchor: .bottom)
            .rotationEffect(.radians(tilt * 1.3), anchor: UnitPoint(x: 0.5, y: 1.5))   // 목 아래를 축으로 기움
            .offset(y: -8 + drop * 5.5)
        }
        .frame(width: 24, height: 24, alignment: .bottom)
        .animation(.easeOut(duration: 0.18), value: tilt)
        .animation(.easeOut(duration: 0.18), value: drop)
        .animation(.easeOut(duration: 0.18), value: close)
    }
}
