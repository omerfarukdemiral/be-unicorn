import SwiftUI

@main
struct UnicornApp: App {
    init() {
        FontRegistrar.register()
        AudioManager.shared.configure()   // SFX havuzu + ambient müzik (CC0 ses asset'leri)
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}
