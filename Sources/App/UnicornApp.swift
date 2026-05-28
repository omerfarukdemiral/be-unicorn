import SwiftUI

@main
struct UnicornApp: App {
    init() { FontRegistrar.register() }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}
