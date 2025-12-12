import SwiftUI

struct ContentView: View {
    @ObservedObject var appService: AppService
    @State private var hoveredAppId: UUID?
    @State private var selectedAppId: UUID?
    
    let columns = [
        GridItem(.adaptive(minimum: 80))
    ]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(appService.apps) { app in
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
        .frame(minWidth: 600, minHeight: 400)
        .background(EventMonitorView(onKeyDown: handleKeyDown))
        .onAppear {
            appService.scanApps()
        }
    }
    
    private func launchApp(_ app: AppModel) {
        NSWorkspace.shared.open(app.url)
        NSApp.hide(nil) // Hide launcher after launch
    }
    
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard !appService.apps.isEmpty else { return false }
        
        // Find current index
        let currentIndex = appService.apps.firstIndex { $0.id == selectedAppId } ?? -1
        var nextIndex = currentIndex
        
        switch event.keyCode {
        case 123: // Left
            nextIndex = max(0, currentIndex - 1)
        case 124: // Right
            nextIndex = min(appService.apps.count - 1, currentIndex + 1)
        case 125: // Down
            // Estimate columns count based on width is hard in pure SwiftUI logic without GeometryReader
            // Fallback: just +1 or logic to jump. For now simpler: +1 like Right, or try to jump rows.
            // Let's assume standard grid flow
             nextIndex = min(appService.apps.count - 1, currentIndex + 1) // Todo: proper grid nav
        case 126: // Up
             nextIndex = max(0, currentIndex - 1)
        case 36: // Enter
            if let selected = selectedAppId, let app = appService.apps.first(where: { $0.id == selected }) {
                launchApp(app)
                return true
            }
        default:
            return false
        }
        
        if nextIndex != currentIndex {
            selectedAppId = appService.apps[nextIndex].id
            return true
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
