import SwiftUI

@main
struct UnicornApp: App {
    init() {
        FontRegistrar.register()
        AudioManager.shared.configure()   // hafif UI sesi altyapısı (asset'siz ton sentezi)
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}
