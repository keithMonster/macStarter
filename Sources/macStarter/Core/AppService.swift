import Foundation
import AppKit
import Combine

@MainActor
class AppService: ObservableObject {
    @Published var apps: [AppModel] = []
    @Published var recentApps: [AppModel] = []
    @Published var frequentApps: [AppModel] = []
    
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
        if lastLaunched.count > 10 { lastLaunched.removeLast() }
        
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
        
        self.recentApps = lastLaunched.compactMap { appMap[$0] }
        
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
                "/System/Applications",
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
