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
        guard var state = try? JSONDecoder().decode(GameState.self, from: data) else { return nil }
        state.normalize()
        return state
    }

    static func wipe() {
        try? FileManager.default.removeItem(at: url)
    }
}
