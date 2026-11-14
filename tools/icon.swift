// 앱 아이콘을 그려 PNG(1024)로 저장: swift tools/icon.swift <출력.png>
// 어두운 화면 위쪽의 노치, 그 아래 초록 자세 아이콘(한쪽 눈은 깜빡)
import AppKit

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
func rgb(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

// 바탕: macOS 아이콘 모양의 둥근 사각형
let plate = NSRect(x: 100, y: 100, width: 824, height: 824)
let plateShape = NSBezierPath(roundedRect: plate, xRadius: 186, yRadius: 186)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
rgb(0x0c0d10).setFill()
plateShape.fill()
ctx.restoreGState()
ctx.saveGState()
plateShape.addClip()
NSGradient(starting: rgb(0x2b2f38), ending: rgb(0x0c0d10))!.draw(in: plate, angle: -90)

// 노치: 위쪽 가운데의 검은 자리
let notch = NSBezierPath()
let nw: CGFloat = 340, nh: CGFloat = 92, nr: CGFloat = 30, top = plate.maxY, cx = plate.midX
notch.move(to: NSPoint(x: cx - nw / 2, y: top))
notch.line(to: NSPoint(x: cx - nw / 2, y: top - nh + nr))
notch.appendArc(withCenter: NSPoint(x: cx - nw / 2 + nr, y: top - nh + nr), radius: nr, startAngle: 180, endAngle: 270)
notch.line(to: NSPoint(x: cx + nw / 2 - nr, y: top - nh))
notch.appendArc(withCenter: NSPoint(x: cx + nw / 2 - nr, y: top - nh + nr), radius: nr, startAngle: 270, endAngle: 360)
notch.line(to: NSPoint(x: cx + nw / 2, y: top))
notch.close()
NSColor.black.setFill()
notch.fill()

// 자세 아이콘: 어깨
let green = rgb(0x3fdb6b)
let shoulders = NSBezierPath()
let sw: CGFloat = 500, sy: CGFloat = 100, sh: CGFloat = 300, sr: CGFloat = 170
shoulders.move(to: NSPoint(x: cx - sw / 2, y: sy))
shoulders.line(to: NSPoint(x: cx - sw / 2, y: sy + sh - sr))
shoulders.appendArc(withCenter: NSPoint(x: cx - sw / 2 + sr, y: sy + sh - sr), radius: sr, startAngle: 180, endAngle: 90, clockwise: true)
shoulders.line(to: NSPoint(x: cx + sw / 2 - sr, y: sy + sh))
shoulders.appendArc(withCenter: NSPoint(x: cx + sw / 2 - sr, y: sy + sh - sr), radius: sr, startAngle: 90, endAngle: 0, clockwise: true)
shoulders.line(to: NSPoint(x: cx + sw / 2, y: sy))
shoulders.close()
green.setFill()
shoulders.fill()

// 머리 (어깨와 떨어져 보이게 어두운 테두리)
let head = NSRect(x: cx - 150, y: 430, width: 300, height: 300)
rgb(0x15171c).setFill()
NSBezierPath(ovalIn: head.insetBy(dx: -34, dy: -34)).fill()
green.setFill()
NSBezierPath(ovalIn: head).fill()

// 눈: 왼쪽은 뜨고, 오른쪽은 깜빡
let dark = rgb(0x0f1114)
dark.setFill()
NSBezierPath(ovalIn: NSRect(x: cx - 62 - 25, y: head.midY + 4 - 25, width: 50, height: 50)).fill()
let wink = NSBezierPath()
wink.move(to: NSPoint(x: cx + 26, y: head.midY + 14))
wink.curve(to: NSPoint(x: cx + 98, y: head.midY + 14), controlPoint1: NSPoint(x: cx + 44, y: head.midY - 18), controlPoint2: NSPoint(x: cx + 80, y: head.midY - 18))
wink.lineWidth = 22
wink.lineCapStyle = .round
dark.setStroke()
wink.stroke()
ctx.restoreGState()

try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
