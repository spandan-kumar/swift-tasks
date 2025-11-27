import SwiftUI

@main
struct MenuBarTodoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager = MenuBarManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // MenuBarManager is already initialized
    }
}
