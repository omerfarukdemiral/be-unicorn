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
            // .statusBarHidden() KALDIRILDI: gizliyken üst safe-area daralıp HUD'u Dynamic
            // Island'ın altına itiyordu ("GARAJ" eyebrow ada ile çakışıyordu). Status bar
            // açık → OS island'ı korur (içerik net altta başlar) + saat/batarya üstteki
            // accent aurora'nın üzerinde durur = safe-area'nın markalı kullanımı.
        }
    }
}
