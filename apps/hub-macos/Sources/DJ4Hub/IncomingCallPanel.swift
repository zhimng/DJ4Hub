import AppKit
import SwiftUI

@MainActor final class IncomingCallPanel {
    private weak var store: HubStore?
    private let panel: NSPanel
    private var ringingTimer: Timer?
    private var ringtone: NSSound?
    init(store: HubStore) {
        self.store = store
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 190), styleMask: [.titled, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "DJ 4G Hub · 来电"
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: IncomingCallView(store: store))
    }
    func update(_ calls: [HubValue]) {
        guard !PhonePresentation.ringing(calls).isEmpty else { stop(); return }
        if !panel.isVisible {
            if let screen = NSScreen.main {
                let frame = screen.visibleFrame
                panel.setFrameTopLeftPoint(NSPoint(x: frame.maxX - 380, y: frame.maxY - 24))
            }
            panel.orderFrontRegardless()
        }
        if store?.notifications.incomingSound == true {
            if ringingTimer == nil {
                ring()
                ringingTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.ring() }
                }
            }
        } else { stopSound() }
    }
    private func ring() {
        guard let store, store.notifications.incomingSound, !PhonePresentation.ringing(store.calls).isEmpty else { stopSound(); return }
        ringtone = NSSound(named: NSSound.Name("Glass"))
        ringtone?.play()
    }
    private func stopSound() { ringingTimer?.invalidate(); ringingTimer = nil; ringtone?.stop(); ringtone = nil }
    func stop() { panel.orderOut(nil); stopSound() }
}

struct IncomingCallView: View {
    @ObservedObject var store: HubStore
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("电话呼入").font(.headline)
            ForEach(Array(PhonePresentation.ringing(store.calls).enumerated()), id: \.offset) { _, call in
                Text(PhonePresentation.caller(call)).font(.title2).textSelection(.enabled)
            }
            HStack {
                Button("接听") { respond("answer") }.tint(.green)
                Button("拒接") { respond("hangup") }.tint(.red)
                if store.busy { ProgressView().controlSize(.small) }
            }.disabled(store.busy || store.voice.busy || PhonePresentation.ringing(store.calls).count != 1)
            Text("接听将使用已选择的麦克风与扬声器").font(.caption).foregroundStyle(.secondary)
        }.padding(20).frame(width: 320)
    }
    private func respond(_ action: String) {
        guard let call = PhonePresentation.ringing(store.calls).first,
              let token = store.notifications.callToken(call["id"].text) else { return }
        store.respondToIncoming(action, id: call["id"].text, token: token)
    }
}
