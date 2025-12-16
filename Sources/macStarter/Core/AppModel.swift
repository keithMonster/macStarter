import Foundation
import AppKit
import CoreServices // Required for MDItem

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
        
        // Custom Localized Name Logic using MDItem (Spotlight Metadata)
        // This is more robust than FileManager.displayName which depends on process locale,
        // as MDItem usually reflects the indexed system-wide localized name (e.g. "企业微信").
        var resolvedName: String?
        if let mdItem = MDItemCreate(kCFAllocatorDefault, url.path as CFString) {
            if let displayName = MDItemCopyAttribute(mdItem, kMDItemDisplayName) as? String {
                resolvedName = displayName
            }
        }
        
        let finalName = resolvedName ?? FileManager.default.displayName(atPath: url.path)
        
        self.name = finalName
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        
        // Generate Pinyin
        let mutableString = NSMutableString(string: finalName)
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
        let pinyinStr = String(mutableString).lowercased()
        self.pinyin = pinyinStr.replacingOccurrences(of: " ", with: "")
        
        // Generate Initials (e.g. "Wei Xin" -> "wx")
        let components = pinyinStr.components(separatedBy: .whitespacesAndNewlines)
        if components.count > 1 {
            self.initials = components.compactMap { $0.first }.map { String($0) }.joined()
        } else {
            self.initials = finalName.lowercased()
        }
    }

}
