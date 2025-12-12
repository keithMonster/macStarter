// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI

@main
struct macStarterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

