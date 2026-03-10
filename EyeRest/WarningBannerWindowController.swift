import AppKit; import SwiftUI
final class WarningBannerWindowController: NSObject {
    private var panel: NSPanel?
    func showBanner() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let mh = NSStatusBar.system.thickness
        let pw: CGFloat = 320, ph: CGFloat = 72
        let x = screen.frame.midX - pw/2, yHide = screen.frame.maxY + ph, yShow = screen.frame.maxY - mh - ph - 8
        let p = NSPanel(contentRect: NSRect(x: x, y: yHide, width: pw, height: ph),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false, screen: screen)
        p.level = .floating; p.backgroundColor = .clear; p.isOpaque = false; p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; p.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: WarningBannerView { self.hideBanner() }.environmentObject(TimerManager.shared))
        host.frame = p.contentView!.bounds; host.autoresizingMask = [.width, .height]; p.contentView = host
        self.panel = p; p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.4; $0.timingFunction = CAMediaTimingFunction(name: .easeOut)
            p.animator().setFrame(NSRect(x: x, y: yShow, width: pw, height: ph), display: true) }
    }
    func hideBanner() {
        guard let p = panel else { return }
        let f = p.frame
        NSAnimationContext.runAnimationGroup { $0.duration = 0.3; $0.timingFunction = CAMediaTimingFunction(name: .easeIn)
            p.animator().setFrame(NSRect(x: f.origin.x, y: f.origin.y + f.height + 80, width: f.width, height: f.height), display: true)
        } completionHandler: { p.orderOut(nil); self.panel = nil }
    }
}
