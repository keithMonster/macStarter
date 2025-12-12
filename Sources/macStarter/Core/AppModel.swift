import Foundation
import AppKit

struct AppModel: Identifiable, Hashable {
    let id: UUID
    let name: String
    let url: URL
    let icon: NSImage
    let pinyin: String
    let initials: String
    
    init(url: URL) {
        self.id = UUID()
        self.url = url
        let rawName = (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName) 
            ?? url.deletingPathExtension().lastPathComponent
        self.name = rawName
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        
        // Generate Pinyin
        let mutableString = NSMutableString(string: rawName)
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
        let pinyinStr = String(mutableString).lowercased()
        self.pinyin = pinyinStr.replacingOccurrences(of: " ", with: "")
        
        // Generate Initials (e.g. "Wei Xin" -> "wx")
        let components = pinyinStr.components(separatedBy: .whitespacesAndNewlines)
        if components.count > 1 {
            self.initials = components.compactMap { $0.first }.map { String($0) }.joined()
        } else {
            self.initials = rawName.lowercased() // Fallback if no spaces
        }
    }
}
