import SwiftUI

/// Şirket evresine göre değişen palet — şirket büyüdükçe arayüz güzelleşir.
struct Theme {
    let bg: Color
    let surface: Color
    let accent: Color
    let stage: Int

    @MainActor
    init(model: GameModel) {
        bg = Color(hex: model.stageBgHex)
        surface = Color(hex: model.stageSurfaceHex)
        accent = Color(hex: model.stageAccentHex)
        stage = model.stageIndex
    }

    // MARK: Metin (Palette üzerinden — tek kaynak)
    var text: Color { Palette.textPrimary }
    var textSecondary: Color { Palette.textSecondary }
    /// Etiket fısıltısı.
    var subtle: Color { Palette.textTertiary }
    var textQuaternary: Color { Palette.textQuaternary }

    // MARK: Yüzey katmanları (Aurora Dark — koyu baz üstünde katman netliği)
    /// Panel zemini (evre yüzeyi, #161B26 ailesi).
    var surfaceLow: Color { surface }
    /// Yükseltilmiş yüzey tabanı (~#1F2735) — overlay/öne çıkan panel için.
    var surfaceElevated: Color { Color(hex: "1F2735") }
    /// Panel içi yükseltilmiş hücre: yüzey üstüne beyaz tint + hafif accent sıcaklığı,
    /// evre büyüdükçe ışıltı artar.
    var surfaceHigh: Color { .white.opacity(0.05 + Double(stage) * 0.006) }

    // MARK: Kenarlık
    /// Standart kart stroke — evre büyüdükçe hafif ışıldar.
    var hairline: Color { .white.opacity(0.09 + Double(stage) * 0.012) }
    /// Seçili / aktif kart kenarlığı.
    var hairlineStrong: Color { accent.opacity(0.4) }

    // MARK: Köşe / elevation (evre-duyarlı "güzelleşme")
    /// PanelCard köşesi — 16…22 arası, yumuşak büyüme.
    var cardCorner: CGFloat { min(22, 16 + CGFloat(stage) * 1.2) }
    /// Taban gölge yarıçapı — stage 0'da bile hafif derinlik.
    var shadowRadius: CGFloat { 8 + CGFloat(stage) * 1.5 }
}

/// Ortak kart yüzeyi — evre arttıkça daha rafine.
struct PanelCard<Content: View>: View {
    let theme: Theme
    /// Aktif/seçili kart için accent kenarlık + glow.
    var highlighted: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Space.s4)
            .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: theme.cardCorner))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cardCorner)
                    .stroke(highlighted ? theme.hairlineStrong : theme.hairline,
                            lineWidth: highlighted ? 1.5 : 1)
            )
            // Koyu baz üstünde net derinlik.
            .shadow(color: .black.opacity(0.28), radius: theme.shadowRadius, y: 3)
            // Aurora glow: seçili kartta accent ışıması, evre büyüdükçe biraz daha güçlü.
            .shadow(color: highlighted ? theme.accent.opacity(0.22 + Double(theme.stage) * 0.02) : .clear,
                    radius: highlighted ? 12 + CGFloat(theme.stage) : 0, y: 4)
    }
}

// MARK: - İç hücre yüzeyi yardımcısı
extension View {
    /// Kart içi yükseltilmiş hücre (surfaceHigh) — katman netliği.
    func cellSurface(_ theme: Theme, corner: CGFloat = Radius.s) -> some View {
        self.background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: corner))
    }
}
