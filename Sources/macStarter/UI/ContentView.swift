import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var appService: AppService
    @State private var hoveredAppId: UUID?
    @State private var selectedAppId: UUID?
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    // Increased column width for larger icons
    let columns = [
        GridItem(.adaptive(minimum: 100))
    ]
    
    // Combined list for display (Recent + Frequent + All) or Filtered
    var displayApps: [(section: String, apps: [AppModel])] {
        if !searchText.isEmpty {
            let lowerQuery = searchText.lowercased()
            let filtered = appService.apps.filter { app in
                app.name.lowercased().contains(lowerQuery) ||
                app.pinyin.contains(lowerQuery) ||
                app.initials.contains(lowerQuery)
            }
            return [("搜索结果", filtered)]
        } else {
            var sections: [(String, [AppModel])] = []
            if !appService.recentApps.isEmpty {
                sections.append(("最近打开", appService.recentApps))
            }
            // "Frequent Apps" section removed as per request
            sections.append(("所有应用", appService.apps))
            return sections
        }
    }
    
    // Flattened list for keyboard navigation index
    var flatAppList: [AppModel] {
        displayApps.flatMap { $0.apps }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 20))
                    TextField("搜索...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 24))
                        .focused($isSearchFocused)
                }
                .padding(16)
                .background(Color.white.opacity(0.15))
                .cornerRadius(16)
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(displayApps, id: \.section) { section in
                            if !section.apps.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(section.section)
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(.horizontal, 24)
                                    
                                    LazyVGrid(columns: columns, spacing: 24) {
                                        ForEach(section.apps) { app in
                                            AppItemView(
                                                app: app,
                                                isSelected: selectedAppId == app.id,
                                                isHovered: hoveredAppId == app.id
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
                                    .padding(.horizontal, 24)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .onChange(of: selectedAppId) { newId in
                if let newId = newId {
                    withAnimation {
                        proxy.scrollTo(newId, anchor: .center)
                    }
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 800)
        .background(EventMonitorView(onKeyDown: handleKeyDown))
        .onAppear {
            appService.scanApps()
            isSearchFocused = true
        }
        .onChange(of: searchText) { _ in
            if let first = flatAppList.first {
                selectedAppId = first.id
            }
        }
    }
    
    private func launchApp(_ app: AppModel) {
        appService.recordLaunch(app: app)
        NSWorkspace.shared.open(app.url)
        NSApp.hide(nil)
        searchText = ""
    }
    
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let apps = flatAppList
        guard !apps.isEmpty else { return false }
        
        // Find current index
        let currentIndex = apps.firstIndex { $0.id == selectedAppId } ?? -1
        var nextIndex = currentIndex
        
        // Escape Handling to hide window
        if event.keyCode == 53 { // ESC
            NSApp.hide(nil)
            return true
        }
        
        // Approximate column count for grid navigation
        // Window width ~800, item width ~100+spacing -> approx 6-7 items per row
        // Ideally we calculated this dynamically, but fixed estimate is okay for MVP
        let columnsCount = 6 
        
        switch event.keyCode {
        case 123: // Left
            nextIndex = max(0, currentIndex - 1)
        case 124: // Right
            nextIndex = min(apps.count - 1, currentIndex + 1)
        case 125: // Down
            nextIndex = min(apps.count - 1, currentIndex + columnsCount)
        case 126: // Up
            nextIndex = max(0, currentIndex - columnsCount)
        case 36: // Enter
            if let selected = selectedAppId, let app = apps.first(where: { $0.id == selected }) {
                launchApp(app)
                return true
            }
        default:
            return false
        }
        
        if nextIndex != currentIndex {
            // Clamp roughly
            if nextIndex < 0 { nextIndex = 0 }
            if nextIndex >= apps.count { nextIndex = apps.count - 1 }
            
            selectedAppId = apps[nextIndex].id
            return true
        }
        
        return false
    }
}

struct AppItemView: View {
    let app: AppModel
    let isSelected: Bool
    let isHovered: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80) // Larger Icon
                .shadow(radius: isSelected || isHovered ? 8 : 0)
                .scaleEffect(isSelected || isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
            
            Text(app.name)
                .font(.system(size: 14, weight: .medium)) // Larger Font
                .lineLimit(1) // Force 1 line
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(height: 20, alignment: .top) // Reduced fixed height for single line
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color.blue.opacity(0.4) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(isSelected ? 0.3 : 0), lineWidth: 1)
        )
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
