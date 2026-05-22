import SwiftUI

@main
struct BeamerPresenterApp: App {
    @StateObject private var presentationManager = PresentationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(presentationManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
