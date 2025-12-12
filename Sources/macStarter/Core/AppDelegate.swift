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
        
        launcherWindow.center()
        launcherWindow.orderFrontRegardless()
    }
}
