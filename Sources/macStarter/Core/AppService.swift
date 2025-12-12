import Foundation
import AppKit
import Combine

@MainActor
class AppService: ObservableObject {
    @Published var apps: [AppModel] = []
    
    private let searchDirectories: [FileManager.SearchPathDirectory] = [
        .applicationDirectory
    ]
    
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
        }
    }
}
