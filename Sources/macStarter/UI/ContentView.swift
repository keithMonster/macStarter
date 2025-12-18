import SwiftUI
import AppKit

@MainActor
struct ContentView: View {
    @ObservedObject var appService: AppService
    @State private var hoveredAppId: UUID?
    @FocusState private var isFocused: Bool
    
    // Fixed columns for predictable keyboard navigation
    let columns = Array(repeating: GridItem(.fixed(110), spacing: 8), count: 8)
    
    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 20))
                    TextField("搜索...", text: $appService.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 24))
                        .focused($isFocused)
                }
                .padding(12)
                .background(Color.white.opacity(0.15))
                .cornerRadius(16)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(appService.displayApps.enumerated()), id: \.element.section) { index, section in
                            if !section.apps.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    if index > 0 {
                                        Divider()
                                            .background(Color.white.opacity(0.05))
                                            .padding(.horizontal, 24)
                                            .padding(.bottom, 8)
                                    }
                                    
                                     LazyVGrid(columns: columns, spacing: 16) {
                                         ForEach(section.apps) { app in
                                             let globalIndex = appService.flatAppList.firstIndex(where: { $0.id == app.id }) ?? 0
                                             AppItemView(
                                                 app: app,
                                                 isHovered: hoveredAppId == app.id,
                                                 isSelected: appService.selectedIndex == globalIndex
                                             )
                                             .onHover { isHovering in
                                                 hoveredAppId = isHovering ? app.id : nil
                                                 if isHovering {
                                                     NSCursor.pointingHand.push()
                                                 } else {
                                                     NSCursor.pop()
                                                 }
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
                 .onChange(of: appService.selectedIndex) { _, newIndex in
                     if let newIndex = newIndex, newIndex < appService.flatAppList.count {
                         proxy.scrollTo(appService.flatAppList[newIndex].id, anchor: .center)
                     }
                 }
             }
             .clipShape(RoundedRectangle(cornerRadius: 20))
             .overlay(
                 RoundedRectangle(cornerRadius: 20)
                     .stroke(Color.white.opacity(0.1), lineWidth: 1)
             )
        }
        .frame(minWidth: 1000, minHeight: 800)
        .onAppear {
            appService.scanApps()
            isFocused = appService.isSearchFocused
        }
        .onChange(of: appService.isSearchFocused) { _, newValue in
            isFocused = newValue
        }
        .onChange(of: isFocused) { _, newValue in
            appService.isSearchFocused = newValue
        }
        .onChange(of: appService.searchText) { _, _ in
            // When search text changes, reset focus to search bar and clear selection
            appService.selectedIndex = nil
            appService.isSearchFocused = true
        }
    }
    
    private func launchApp(_ app: AppModel) {
        appService.recordLaunch(app: app)
        NSWorkspace.shared.open(app.url)
        NSApp.hide(nil)
        appService.searchText = ""
    }
}

struct AppItemView: View {
    let app: AppModel
    let isHovered: Bool
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .shadow(radius: isSelected ? 8 : (isHovered ? 4 : 0))
                .scaleEffect(isSelected ? 1.05 : (isHovered ? 1.02 : 1.0))
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected || isHovered)
            
            Text(app.name)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .foregroundColor(isSelected ? .white : (isHovered ? .primary : .primary.opacity(0.8)))
                .frame(height: 20, alignment: .top)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color.white.opacity(0.12) : (isHovered ? Color.white.opacity(0.06) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.white.opacity(0.15) : Color.clear, lineWidth: 1)
        )
    }
}
