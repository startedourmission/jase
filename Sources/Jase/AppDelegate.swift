import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = Model()
    private let settings = Settings.shared
    private var monitor: Monitor!
    private var panel: NSPanel!
    private var status: NSStatusItem!
    private var window: NSWindow?
    private var timer: Timer?
    private var watching: Set<AnyCancellable> = []
    private let canvas = CGSize(width: 520, height: 150)  // 노치 아래로 펼쳐질 자리

    func applicationDidFinishLaunching(_ notification: Notification) {
        makePanel()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let symbol = ["figure.seated.side.right", "figure.seated.side", "figure.stand"].first { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil } ?? "eye"
        status.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "jase")
        makeMenu()
        monitor = Monitor(model: model)
        monitor.start()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.model.refresh() }
        NotificationCenter.default.addObserver(self, selector: #selector(place), name: NSApplication.didChangeScreenParametersNotification, object: nil)

        // 설정이 바뀌면 바로 반영 (@Published는 바뀌기 직전에 알리므로 한 박자 뒤에 읽음)
        settings.$language.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.makeMenu()
            self?.window?.title = L("jase 설정", "jase Settings")
        }.store(in: &watching)
        settings.$power.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] power in self?.monitor.setRate(power.fps) }.store(in: &watching)
        settings.$showNumbers.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] on in
            self?.monitor.setLogging(on)
            self?.makeMenu()
        }.store(in: &watching)
    }

    /// 노치가 있는 화면 (없으면 주 화면 위쪽 가운데에 노치만 한 자리를 가정)
    private var screen: NSScreen? { NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main }

    private func notchSize(_ screen: NSScreen) -> CGSize {
        guard screen.safeAreaInsets.top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else {
            return CGSize(width: 200, height: 32)
        }
        return CGSize(width: screen.frame.width - left.width - right.width, height: screen.safeAreaInsets.top)
    }

    private func makePanel() {
        panel = NSPanel(contentRect: CGRect(origin: .zero, size: canvas), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        place()
        panel.orderFrontRegardless()
    }

    @objc private func place() {
        guard let screen else { return }
        panel.contentView = NSHostingView(rootView: NotchView(model: model, notch: notchSize(screen)))
        panel.setFrame(CGRect(x: screen.frame.midX - canvas.width / 2, y: screen.frame.maxY - canvas.height, width: canvas.width, height: canvas.height), display: true)
    }

    private func makeMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: L("설정…", "Settings…"), action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: L("기준 자세 다시 재기", "Set Baseline Again"), action: #selector(recalibrate), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L("jase 종료", "Quit jase"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        status.menu = menu
    }

    @objc private func recalibrate() {
        model.startCalibration()
        monitor.recalibrate()
    }

    @objc private func openSettings() {
        if window == nil {
            let made = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            made.contentView = NSHostingView(rootView: SettingsView(recalibrate: { [weak self] in self?.recalibrate() }))
            made.isReleasedWhenClosed = false
            made.setContentSize(made.contentView!.fittingSize)
            made.center()
            window = made
        }
        window?.title = L("jase 설정", "jase Settings")
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
