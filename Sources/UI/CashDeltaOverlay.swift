import SwiftUI

/// HUD üzerinde, nakit değiştiğinde kısa süre yüzen ±tutar çipi.
/// Kazanç → yeşil, harcama → kırmızı. Yukarı süzülüp kaybolur — rahatsız etmez.
struct CashDeltaOverlay: View {
    @ObservedObject var model: GameModel

    /// Yüzen bir delta çipi (kısa ömürlü).
    private struct Floater: Identifiable, Equatable {
        let id = UUID()
        let amount: Double
        let createdAt: Date
        var offsetY: CGFloat = 4
        var opacity: Double = 0
        var scale: CGFloat = 0.85
    }

    @State private var floaters: [Floater] = []

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(floaters) { f in
                chip(amount: f.amount)
                    .offset(y: f.offsetY)
                    .opacity(f.opacity)
                    .scaleEffect(f.scale)
            }
        }
        .allowsHitTesting(false)
        .onReceive(model.$lastCashDelta) { event in
            guard let event else { return }
            spawn(amount: event.amount)
        }
    }

    /// Tek çip: renk + ikon + tutar (BigNumber kısaltması).
    private func chip(amount: Double) -> some View {
        let positive = amount >= 0
        let tint = positive ? Palette.success : Palette.danger
        let symbol = positive ? "arrow.up.right" : "arrow.down.right"
        let sign = positive ? "+" : "−"
        let body = "\(sign)\(BigNumber.money(abs(amount)))"
        return HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 9, weight: .heavy))
            Text(body).font(.appNumber(12, .heavy))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(tint.opacity(0.14), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 0.6))
    }

    /// Yeni çipi ekle + giriş animasyonu (spring) + kısa bekleme + yukarı süzülerek kaybolma.
    private func spawn(amount: Double) {
        let f = Floater(amount: amount, createdAt: Date())
        floaters.append(f)
        // Giriş: yaylı pop (aşağıdan hafif yukarı).
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            mutate(id: f.id) { $0.offsetY = 0; $0.opacity = 1; $0.scale = 1 }
        }
        // 350ms sonra: yukarı süzül + sol (kayboluş).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.75)) {
                mutate(id: f.id) { $0.offsetY = -34; $0.opacity = 0; $0.scale = 0.95 }
            }
        }
        // Tamamen kaldır.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            floaters.removeAll { $0.id == f.id }
        }
    }

    private func mutate(id: UUID, _ block: (inout Floater) -> Void) {
        guard let idx = floaters.firstIndex(where: { $0.id == id }) else { return }
        block(&floaters[idx])
    }
}
