import SwiftUI

@main
struct BeamerPresenterApp: App {
    @StateObject private var presentationManager = PresentationManager()
    
    var body: some Scene {
        WindowGroup(id: "presenter-window") {
            ContentView()
                .environmentObject(presentationManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.automatic)
    }
}
