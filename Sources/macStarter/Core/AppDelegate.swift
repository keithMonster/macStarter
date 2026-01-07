import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var launcherWindow: LauncherWindow!
    var appService = AppService()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the window
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1000, height: 800)
        let windowRect = NSRect(x: (screenRect.width - 1000) / 2, y: (screenRect.height - 800) / 2, width: 1000, height: 800)
        
        launcherWindow = LauncherWindow(contentRect: windowRect, backing: .buffered, defer: false)
        launcherWindow.delegate = self
        
        // Host SwiftUI Content
        let hostingView = NSHostingView(rootView: ContentView(appService: appService))
        hostingView.frame = NSRect(x: 0, y: 0, width: 1000, height: 800)
        hostingView.autoresizingMask = [.width, .height]
        
        // Add hosting view to the visual effect view (contentView of window)
        if let visualEffectView = launcherWindow.contentView as? NSVisualEffectView {
            visualEffectView.addSubview(hostingView)
        }
        
        // Local Event Monitor for Esc/Arrows when window is active
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.lastCommandTapTime = 0
            guard let self = self, self.launcherWindow.isVisible else { return event }
            
            if event.keyCode == 53 { // ESC
                self.launcherWindow.orderOut(nil)
                return nil
            }
            
            // Intercept navigation keys
            switch event.keyCode {
            case 126: // Up
                self.appService.moveSelection(direction: .up)
                return nil
            case 125: // Down
                self.appService.moveSelection(direction: .down)
                return nil
            case 123: // Left
                if self.appService.isSearchFocused { return event }
                self.appService.moveSelection(direction: .left)
                return nil
            case 124: // Right
                if self.appService.isSearchFocused { return event }
                self.appService.moveSelection(direction: .right)
                return nil
            case 36: // Enter
                self.appService.launchSelected()
                return nil
            default:
                break
            }
            
            return event
        }
        
        // Global Monitor to reset timer on any key press
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            self?.lastCommandTapTime = 0
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
    
    func applicationDidResignActive(_ notification: Notification) {
        // Hide the window when the application loses focus
        launcherWindow.orderOut(nil)
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // Hide the window when it loses keyboard focus
        launcherWindow.orderOut(nil)
    }
    
    private var lastCommandTapTime: TimeInterval = 0
    
    private func handleGlobalKey(_ event: NSEvent) {
        // Only trigger on Command key press (Left: 55, Right: 54)
        guard event.keyCode == 55 || event.keyCode == 54 else { return }
        
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
