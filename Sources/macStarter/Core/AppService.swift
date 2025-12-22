import Foundation
import AppKit
import Combine

@MainActor
class AppService: ObservableObject {
    @Published var apps: [AppModel] = []
    @Published var recentApps: [AppModel] = []
    @Published var frequentApps: [AppModel] = []
    
    // Navigation State
    @Published var searchText: String = ""
    @Published var selectedIndex: Int?
    @Published var isSearchFocused: Bool = true
    
    let columnCount = 8
    
    var displayApps: [(section: String, apps: [AppModel])] {
        if !searchText.isEmpty {
            let lowerQuery = searchText.lowercased()
            let filtered = apps.filter { app in
                app.name.lowercased().contains(lowerQuery) ||
                app.pinyin.contains(lowerQuery) ||
                app.initials.contains(lowerQuery)
            }
            return [("搜索结果", filtered)]
        } else {
            var sections: [(String, [AppModel])] = []
            if !recentApps.isEmpty {
                sections.append(("最近打开", recentApps))
            }
            sections.append(("所有应用", apps))
            return sections
        }
    }
    
    var flatAppList: [AppModel] {
        displayApps.flatMap { $0.apps }
    }
    
    func moveSelection(direction: NavigationDirection) {
        let sections = displayApps
        if sections.isEmpty { return }
        
        let flatList = flatAppList
        let count = flatList.count
        if count == 0 && direction != .down { return }
        
        // Helper to find section and relative index for a given flat index
        func findCoords(for flatIndex: Int) -> (sectionIndex: Int, itemIndex: Int)? {
            var offset = 0
            for (sIdx, section) in sections.enumerated() {
                if flatIndex < offset + section.apps.count {
                    return (sIdx, flatIndex - offset)
                }
                offset += section.apps.count
            }
            return nil
        }
        
        // Helper to find flat index from section and relative index
        func findFlatIndex(sectionIndex: Int, itemIndex: Int) -> Int? {
            if sectionIndex < 0 || sectionIndex >= sections.count { return nil }
            var offset = 0
            for i in 0..<sectionIndex {
                offset += sections[i].apps.count
            }
            if itemIndex < 0 || itemIndex >= sections[sectionIndex].apps.count { return nil }
            return offset + itemIndex
        }
        
        switch direction {
        case .down:
            if isSearchFocused {
                isSearchFocused = false
                selectedIndex = 0
            } else if let current = selectedIndex, let coords = findCoords(for: current) {
                let currentColumn = coords.itemIndex % columnCount
                let nextItemInSameSection = coords.itemIndex + columnCount
                
                if nextItemInSameSection < sections[coords.sectionIndex].apps.count {
                    // Next row in same section
                    selectedIndex = findFlatIndex(sectionIndex: coords.sectionIndex, itemIndex: nextItemInSameSection)
                } else {
                    // Try next section
                    var nextSectionIdx = coords.sectionIndex + 1
                    while nextSectionIdx < sections.count {
                        if !sections[nextSectionIdx].apps.isEmpty {
                            // Find first row in next section, same column
                            let targetItemIdx = min(currentColumn, sections[nextSectionIdx].apps.count - 1)
                            selectedIndex = findFlatIndex(sectionIndex: nextSectionIdx, itemIndex: targetItemIdx)
                            return
                        }
                        nextSectionIdx += 1
                    }
                }
            }
        case .up:
            if let current = selectedIndex, let coords = findCoords(for: current) {
                let currentColumn = coords.itemIndex % columnCount
                let prevItemInSameSection = coords.itemIndex - columnCount
                
                if prevItemInSameSection >= 0 {
                    // Previous row in same section
                    selectedIndex = findFlatIndex(sectionIndex: coords.sectionIndex, itemIndex: prevItemInSameSection)
                } else {
                    // Try previous section
                    var prevSectionIdx = coords.sectionIndex - 1
                    while prevSectionIdx >= 0 {
                        if !sections[prevSectionIdx].apps.isEmpty {
                            let sCount = sections[prevSectionIdx].apps.count
                            let lastRowStart = (sCount - 1) / columnCount * columnCount
                            let targetItemIdx = min(lastRowStart + currentColumn, sCount - 1)
                            selectedIndex = findFlatIndex(sectionIndex: prevSectionIdx, itemIndex: targetItemIdx)
                            return
                        }
                        prevSectionIdx -= 1
                    }
                    // No more sections above, back to search
                    selectedIndex = nil
                    isSearchFocused = true
                }
            }
        case .left:
            if let current = selectedIndex, current > 0 {
                selectedIndex = current - 1
            }
        case .right:
            if let current = selectedIndex, current < count - 1 {
                selectedIndex = current + 1
            }
        }
    }
    
    func launchSelected() {
        if let index = selectedIndex, index < flatAppList.count {
            let app = flatAppList[index]
            recordLaunch(app: app)
            NSWorkspace.shared.open(app.url)
            NSApp.hide(nil)
            searchText = ""
        }
    }
    
    enum NavigationDirection {
        case up, down, left, right
    }
    
    private var launchHistory: [String: Int] = [:] // id string -> count
    private var lastLaunched: [String] = [] // list of ids
    
    private let searchDirectories: [FileManager.SearchPathDirectory] = [
        .applicationDirectory
    ]
    
    init() {
        loadHistory()
    }
    
    func recordLaunch(app: AppModel) {
        let idStr = app.url.path
        launchHistory[idStr, default: 0] += 1
        
        lastLaunched.removeAll { $0 == idStr }
        lastLaunched.insert(idStr, at: 0)
        if lastLaunched.count > 8 { lastLaunched.removeLast() }
        
        saveHistory()
        updateLists()
    }
    
    private func loadHistory() {
        launchHistory = UserDefaults.standard.dictionary(forKey: "LaunchCounts") as? [String: Int] ?? [:]
        lastLaunched = UserDefaults.standard.stringArray(forKey: "LastLaunched") ?? []
    }
    
    private func saveHistory() {
        UserDefaults.standard.set(launchHistory, forKey: "LaunchCounts")
        UserDefaults.standard.set(lastLaunched, forKey: "LastLaunched")
    }
    
    private func updateLists() {
        // Map paths back to current scan results
        let appMap = Dictionary(grouping: apps, by: { $0.url.path }).compactMapValues { $0.first }
        
        self.recentApps = Array(lastLaunched.prefix(8).compactMap { appMap[$0] })
        
        let sortedByCount = launchHistory.sorted { $0.value > $1.value }
        self.frequentApps = sortedByCount.prefix(10).compactMap { appMap[$0.key] }
    }

    func scanApps() {
        Task {
            var foundApps: [AppModel] = []
            let fileManager = FileManager.default
            
            // Simpler approach: fixed paths
            let paths = [
                "/Applications",
                "/Applications/Utilities",
                "/System/Applications",
                "/System/Applications/Utilities",
                URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications").path
            ]
            
            for path in paths {
                let url = URL(fileURLWithPath: path)
                guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isApplicationKey], options: [.skipsHiddenFiles]) else { continue }
                
                for itemUrl in contents {
                    if itemUrl.pathExtension == "app" {
                        foundApps.append(AppModel(url: itemUrl))
                    }
                }
            }
            
            let result = foundApps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            self.apps = result
            self.updateLists()
        }
    }
}
