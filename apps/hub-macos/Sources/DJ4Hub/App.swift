import SwiftUI
import AppKit

@MainActor final class HubDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var store: HubStore?
    weak var mainWindow: NSWindow?
    func attach(_ window: NSWindow) { mainWindow = window; window.delegate = self }
    func hideToMenuBar() { mainWindow?.orderOut(nil); NSApp.setActivationPolicy(.accessory) }
    func showWindow() { NSApp.setActivationPolicy(.regular); mainWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    func windowShouldClose(_ sender: NSWindow) -> Bool { hideToMenuBar(); return false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    private var finishing = false
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if finishing { return .terminateNow }
        finishing = true
        store?.stopBackgroundPreparation(shutdown: true)
        store?.voice.stopStreams()
        Task {
            await store?.voice.release()
            store?.service.stopOwned()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
@main struct DJ4HubApp: App {
    @NSApplicationDelegateAdaptor(HubDelegate.self) var delegate
    @StateObject private var store = HubStore()
    var body: some Scene {
        WindowGroup("DJ 4G Hub", id: "main") {
            HubRoot(store: store, service: store.service)
                .background(UnifiedWindowAppearance(delegate: delegate))
                .onAppear { delegate.store = store; store.notifications.openIncomingCall = { store.page = .phone; delegate.showWindow() } }
        }.defaultSize(width: 1150, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) { Button("打开 Web 控制台") { store.service.openWeb() } }
        }
        MenuBarExtra("DJ 4G Hub", systemImage: "antenna.radiowaves.left.and.right") {
            Text("本机号码：" + store.ownNumber)
            ForEach(Array(PhonePresentation.ringing(store.calls).enumerated()), id: \.offset) { _, call in Text("来电：" + PhonePresentation.caller(call)) }
            Button("显示客户端") { delegate.showWindow() }
            Button("打开 Web") { store.service.openWeb() }
            Divider()
            Button("仅菜单栏运行") { delegate.hideToMenuBar() }
            Button("完全退出") { NSApp.terminate(nil) }
        }
    }
}

/// Configure only the owning window; never alter sheets or other app windows.
struct UnifiedWindowAppearance: NSViewRepresentable {
    var delegate: HubDelegate
    final class WindowView: NSView {
        weak var hubDelegate: HubDelegate?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            hubDelegate?.attach(window)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.styleMask.insert(.fullSizeContentView)
        }
    }
    func makeNSView(context: Context) -> WindowView { let view = WindowView(); view.hubDelegate = delegate; return view }
    func updateNSView(_ nsView: WindowView, context: Context) {}
}
