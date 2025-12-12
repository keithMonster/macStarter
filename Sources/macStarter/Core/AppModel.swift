import Foundation
import AppKit

struct AppModel: Identifiable, Hashable {
    let id: UUID
    let name: String
    let url: URL
    let icon: NSImage
    
    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName) 
            ?? url.deletingPathExtension().lastPathComponent
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
    }
}
