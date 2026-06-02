import SwiftUI

/// HUD'un hemen altında beliren "çünkü" nedensellik çipi.
///
/// Bir eylem (işe alım, reklam bütçesi) ya da bir eşik geçişi (moral düştü, runway kısaldı)
/// bir metriği NEDEN etkilediğini ANLIK olarak söyler. Oyunun gizli simülasyon zincirlerini
/// (moral→üretim/churn, reklam→CAC, ekip→burn→runway) sayı-tablosundan HİSSE çevirir — bu
/// "dashboard değil oyun" hissinin en doğrudan kaldıracı (Faz 2).
///
/// Tek aktif çip: yeni bir not gelince öncekini değiştirir. ~2.4 sn görünür, yumuşakça gelir/gider.
struct CausalChipOverlay: View {
    @ObservedObject var model: GameModel

    @State private var note: CausalNote? = nil
    @State private var shown = false
    @State private var dismissWork: DispatchWorkItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let n = note {
                chip(n)
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : -14)
                    .scaleEffect(shown ? 1 : 0.92, anchor: .top)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: shown)
        .allowsHitTesting(false)
        .onReceive(model.$pendingCausalNote) { incoming in
            guard let incoming else { return }
            present(incoming)
        }
    }

    /// Yeni notu göster + öncekinin gizlenme işini iptal et + 2.4 sn sonra gizle.
    private func present(_ n: CausalNote) {
        dismissWork?.cancel()
        note = n
        shown = true
        let work = DispatchWorkItem { shown = false }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: work)
    }

    private func tint(_ t: CausalNote.Tone) -> Color {
        switch t {
        case .good: return Palette.success
        case .warn: return Palette.warning
        case .bad:  return Palette.danger
        }
    }

    private func chip(_ n: CausalNote) -> some View {
        let c = tint(n.tone)
        return HStack(spacing: 7) {
            Image(systemName: n.icon)
                .font(.system(size: 12, weight: .bold))
            Text(n.text)
                .font(.appText(12, .semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(c)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            Capsule().fill(.ultraThinMaterial)
            Capsule().fill(c.opacity(0.14))
        }
        .overlay(Capsule().stroke(c.opacity(0.4), lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 8, y: 3)
        .frame(maxWidth: 320)
        .padding(.horizontal, Space.s4)
    }
}
