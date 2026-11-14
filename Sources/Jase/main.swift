import AppKit
import SwiftUI

let app = NSApplication.shared

// 개발용: 설정 화면을 창을 띄우지 않고 그림으로 저장 (jase --snapshot-settings 출력.png [ko|en])
if let index = CommandLine.arguments.firstIndex(of: "--snapshot-settings"), CommandLine.arguments.count > index + 1 {
    if CommandLine.arguments.count > index + 2, let lang = Lang(rawValue: CommandLine.arguments[index + 2]) { Settings.shared.language = lang }
    let view = NSHostingView(rootView: SettingsView(recalibrate: {}))
    let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 480, height: 760), styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = view
    view.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.5))
    let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: rep)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
    exit(0)
}

let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
