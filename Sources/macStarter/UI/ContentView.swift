import SwiftUI

struct ContentView: View {
    @ObservedObject var appService: AppService
    @State private var hoveredAppId: UUID?
    @State private var selectedAppId: UUID?
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    let columns = [
        GridItem(.adaptive(minimum: 80))
    ]
    
    var filteredApps: [AppModel] {
        if searchText.isEmpty {
            return appService.apps
        } else {
            let lowerQuery = searchText.lowercased()
            return appService.apps.filter { app in
                app.name.lowercased().contains(lowerQuery) ||
                app.pinyin.contains(lowerQuery) ||
                app.initials.contains(lowerQuery)
            }
        }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("搜索...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.title2)
                        .focused($isSearchFocused)
                }
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 20)
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(filteredApps) { app in
                            VStack {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 64, height: 64)
                                    .scaleEffect(hoveredAppId == app.id || selectedAppId == app.id ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hoveredAppId)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedAppId)
                                
                                Text(app.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundColor(selectedAppId == app.id ? .white : .primary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedAppId == app.id ? Color.blue.opacity(0.3) : Color.clear)
                            )
                            .onHover { isHovering in
                                hoveredAppId = isHovering ? app.id : nil
                            }
                            .onTapGesture {
                                launchApp(app)
                            }
                            .id(app.id)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(EventMonitorView(onKeyDown: handleKeyDown))
        .onAppear {
            appService.scanApps()
            isSearchFocused = true
        }
        .onChange(of: searchText) { _ in
            if let first = filteredApps.first {
                selectedAppId = first.id
            }
        }
    }
    
    private func launchApp(_ app: AppModel) {
        NSWorkspace.shared.open(app.url)
        NSApp.hide(nil)
        searchText = "" // Reset search
    }
    
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let apps = filteredApps
        guard !apps.isEmpty else { return false }
        
        // Find current index
        let currentIndex = apps.firstIndex { $0.id == selectedAppId } ?? -1
        var nextIndex = currentIndex
        
        // Escape Handling to hide window
        if event.keyCode == 53 { // ESC
            NSApp.hide(nil)
            return true
        }
        
        switch event.keyCode {
        case 123: // Left
            nextIndex = max(0, currentIndex - 1)
        case 124: // Right
            nextIndex = min(apps.count - 1, currentIndex + 1)
        case 125: // Down
             nextIndex = min(apps.count - 1, currentIndex + 1) // Todo: proper grid nav
        case 126: // Up
             nextIndex = max(0, currentIndex - 1)
        case 36: // Enter
            if let selected = selectedAppId, let app = apps.first(where: { $0.id == selected }) {
                launchApp(app)
                return true
            }
        default:
            return false
        }
        
        if nextIndex != currentIndex {
            if nextIndex >= 0 && nextIndex < apps.count {
                 selectedAppId = apps[nextIndex].id
                 return true
            }
        }
        
        return false
    }
}

// invisible view to handle key events
struct EventMonitorView: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.onKeyDown = onKeyDown
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    class KeyView: NSView {
        var onKeyDown: ((NSEvent) -> Bool)?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func keyDown(with event: NSEvent) {
            if let handler = onKeyDown, handler(event) {
                return
            }
            super.keyDown(with: event)
        }
    }
}
