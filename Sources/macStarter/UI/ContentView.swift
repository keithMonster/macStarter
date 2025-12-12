import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var appService: AppService
    @State private var hoveredAppId: UUID?
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
                .padding(12)
                .background(Color.white.opacity(0.15))
                .cornerRadius(16)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(displayApps.enumerated()), id: \.element.section) { index, section in
                            if !section.apps.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    // Remove text headers, replace with Divider for subsequent sections
                                    if index > 0 {
                                        Divider()
                                            .background(Color.white.opacity(0.05))
                                            .padding(.horizontal, 24)
                                            .padding(.bottom, 8)
                                    }
                                    
                                    LazyVGrid(columns: columns, spacing: 8) {
                                        ForEach(section.apps) { app in
                                            AppItemView(
                                                app: app,
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
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .frame(minWidth: 1000, minHeight: 800)
        .background(EventMonitorView(onKeyDown: handleKeyDown))
        .onAppear {
            appService.scanApps()
            isSearchFocused = true
        }
        .onAppear {
            appService.scanApps()
            isSearchFocused = true
        }
    }
    
    private func launchApp(_ app: AppModel) {
        appService.recordLaunch(app: app)
        NSWorkspace.shared.open(app.url)
        NSApp.hide(nil)
        searchText = ""
    }
    
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        // Escape Handling to hide window
        if event.keyCode == 53 { // ESC
            NSApp.hide(nil)
            return true
        }
        return false
    }
}

struct AppItemView: View {
    let app: AppModel
    let isHovered: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80) // Larger Icon
                .shadow(radius: isHovered ? 8 : 0)
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
            
            Text(app.name)
                .font(.system(size: 14, weight: .medium)) // Larger Font
                .lineLimit(1) // Force 1 line
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .frame(height: 20, alignment: .top) // Reduced fixed height for single line
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.clear, lineWidth: 1)
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
