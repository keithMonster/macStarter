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
        
        // Custom Localized Name Logic
        let resolvedName = AppModel.getLocalizedName(for: url)
        self.name = resolvedName
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        
        // Generate Pinyin
        let mutableString = NSMutableString(string: resolvedName)
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
        let pinyinStr = String(mutableString).lowercased()
        self.pinyin = pinyinStr.replacingOccurrences(of: " ", with: "")
        
        // Generate Initials (e.g. "Wei Xin" -> "wx")
        let components = pinyinStr.components(separatedBy: .whitespacesAndNewlines)
        if components.count > 1 {
            self.initials = components.compactMap { $0.first }.map { String($0) }.joined()
        } else {
            self.initials = resolvedName.lowercased()
        }
    }
    
    static func getLocalizedName(for url: URL) -> String {
        let bundle = Bundle(url: url)
        
        // 1. Try to find Chinese resources specifically
        // Common Chinese language codes
        let chineseLangs = ["zh-Hans", "zh-Hans-CN", "zh_CN", "zh_Hans"]
        
        for lang in chineseLangs {
            if let lprojPath = bundle?.path(forResource: lang, ofType: "lproj"),
               let stringsDict = NSDictionary(contentsOfFile: (lprojPath as NSString).appendingPathComponent("InfoPlist.strings")) {
                
                if let displayName = stringsDict["CFBundleDisplayName"] as? String, !displayName.isEmpty {
                    return displayName
                }
                if let bundleName = stringsDict["CFBundleName"] as? String, !bundleName.isEmpty {
                    return bundleName
                }
            }
        }
        
        // 2. Fallback to standard localized info dictionary (System default assumption)
        if let localizedDict = bundle?.localizedInfoDictionary,
           let name = localizedDict["CFBundleDisplayName"] as? String ?? localizedDict["CFBundleName"] as? String, !name.isEmpty {
            return name
        }
        
        // 3. Fallback to Info.plist
        if let info = bundle?.infoDictionary,
           let name = info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String, !name.isEmpty {
            return name
        }
        
        // 4. Fallback to file system name
        return (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName) 
            ?? url.deletingPathExtension().lastPathComponent
    }
}
