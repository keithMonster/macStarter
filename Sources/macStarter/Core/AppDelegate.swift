import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var launcherWindow: LauncherWindow!
    var appService = AppService()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the window
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let windowRect = NSRect(x: (screenRect.width - 800) / 2, y: (screenRect.height - 600) / 2, width: 800, height: 600)
        
        launcherWindow = LauncherWindow(contentRect: windowRect, backing: .buffered, defer: false)
        
        // Host SwiftUI Content
        let hostingView = NSHostingView(rootView: ContentView(appService: appService))
        hostingView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        hostingView.autoresizingMask = [.width, .height]
        
        // Add hosting view to the visual effect view (contentView of window)
        if let visualEffectView = launcherWindow.contentView as? NSVisualEffectView {
            visualEffectView.addSubview(hostingView)
        }
        
        // Local Event Monitor for Esc/Arrows when window is active
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.launcherWindow.isVisible else { return event }
            
            if event.keyCode == 53 { // ESC
                self.launcherWindow.orderOut(nil)
                return nil // Consume event
            }
            return event
        }
        
        // Global Monitor for double-tap Command
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
             self?.handleGlobalKey(event)
        }
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
             self?.handleGlobalKey(event)
             return event
        }
        
        launcherWindow.center()
        launcherWindow.orderFrontRegardless()
    }
    
    private var lastCommandTapTime: TimeInterval = 0
    
    private func handleGlobalKey(_ event: NSEvent) {
        // Check if Command is pressed (and only Command)
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
            let now = Date().timeIntervalSince1970
            if now - lastCommandTapTime < 0.3 {
                toggleWindow()
                lastCommandTapTime = 0
            } else {
                lastCommandTapTime = now
            }
        }
    }
    
    private func toggleWindow() {
        if launcherWindow.isVisible {
            launcherWindow.orderOut(nil)
        } else {
             // Activate app and show window
            NSApp.activate(ignoringOtherApps: true)
            launcherWindow.makeKeyAndOrderFront(nil)
            launcherWindow.center()
        }
    }
}
