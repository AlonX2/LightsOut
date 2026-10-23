import SwiftUI
import AppKit

@main
struct LightsOutApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    let displaysViewModel = DisplaysViewModel()
    let popoverService = PopoverService()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = MenuBarView()
            .environmentObject(displaysViewModel)
        popoverService.contentViewController = NSHostingController(rootView: contentView)
    }
    
}

#Preview {
    MenuBarView()
        .environmentObject(DisplaysViewModel())
}
