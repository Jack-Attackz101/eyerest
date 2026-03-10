import AppKit; import SwiftUI
final class OverlayWindowController: NSObject {
    private var windows: [NSWindow] = []
    func showOverlay() {
        for screen in NSScreen.screens {
            let win = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
            win.level = .screenSaver; win.backgroundColor = .black; win.isOpaque = true; win.canHide = false
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            win.isReleasedWhenClosed = false; win.ignoresMouseEvents = false
            let host = NSHostingView(rootView: OverlayView().environmentObject(TimerManager.shared))
            host.frame = win.contentView!.bounds; host.autoresizingMask = [.width, .height]
            win.contentView = host; windows.append(win)
            win.alphaValue = 0; win.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.5; $0.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut); win.animator().alphaValue = 1 }
        }
    }
    func hideOverlay() {
        let wins = windows; windows = []
        NSAnimationContext.runAnimationGroup { $0.duration = 0.3; wins.forEach { $0.animator().alphaValue = 0 } } completionHandler: { wins.forEach { $0.orderOut(nil) } }
    }
}
