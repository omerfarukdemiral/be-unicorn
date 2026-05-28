import Foundation

/// GameState'i Documents/save.json içinde saklar.
enum SaveManager {
    private static var url: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("save.json")
    }

    static func save(_ state: GameState) {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Kayıt hatası: \(error)")
        }
    }

    static func load() -> GameState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            var state = try JSONDecoder().decode(GameState.self, from: data)
            state = migrate(state)
            state.normalize()
            return state
        } catch {
            // Decode patladı (bozuk/uyumsuz şema). Save'i SİLME — .bak'a yedekle ki
            // ileride kurtarma/teşhis mümkün olsun; oyuncu ilerlemesi sessizce yok olmasın.
            print("Save decode hatası, .bak'a yedekleniyor: \(error)")
            let backup = url.deletingPathExtension().appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
            return nil
        }
    }

    /// Şema sürümleri arası migration zinciri. Şimdilik v1 → no-op; ileride
    /// alan dönüşümleri burada sürüm sürüm uygulanır (state.schemaVersion'ı bumpla).
    private static func migrate(_ state: GameState) -> GameState {
        var s = state
        // örn: if s.schemaVersion < 2 { ...dönüştür...; s.schemaVersion = 2 }
        s.schemaVersion = max(s.schemaVersion, 1)
        return s
    }

    static func wipe() {
        try? FileManager.default.removeItem(at: url)
    }
}
