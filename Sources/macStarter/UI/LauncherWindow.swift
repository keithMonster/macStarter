import AppKit
import SwiftUI

class LauncherWindow: NSPanel {
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView], backing: backing, defer: flag)
        
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = false
        self.isReleasedWhenClosed = false
        self.backgroundColor = .clear
        
        // Visual Effect View for Blur Background
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .hudWindow
        visualEffect.frame = contentRect
        visualEffect.autoresizingMask = [.width, .height]
        
        self.contentView = visualEffect
    }
    
    // Allow panel to become key window on click/keypress even if .nonactivatingPanel
    override var canBecomeKey: Bool {
        return true
    }
}
