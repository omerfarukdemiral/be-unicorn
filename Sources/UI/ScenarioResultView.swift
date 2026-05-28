import SwiftUI

/// Programlı senaryonun deadline'ında üretilen sonuç ekranı. Başarı veya başarısızlık,
/// uygulanan etkilerin özeti, kapatma butonu. Funding/sprint kapanış kartlarıyla aynı dilde.
struct ScenarioResultView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let result: ScenarioResult
    @State private var appeared = false

    private var kind: ScenarioKind { result.scenario.scenarioKind }
    private var tint: Color { result.success ? Palette.success : Palette.danger }

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
                .onTapGesture { dismiss() }
            card
                .scaleEffect(appeared ? 1 : 0.92).opacity(appeared ? 1 : 0)
                .padding(.horizontal, Space.s5)
        }
        .onAppear { withAnimation(Motion.snappy) { appeared = true } }
    }

    private var card: some View {
        VStack(spacing: 0) {
            // Tepe — hero ikon + sonuç şeridi.
            ZStack {
                Circle().fill(tint.opacity(0.22)).frame(width: 86, height: 86)
                Image(systemName: kind.icon)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .offset(y: 18).zIndex(1)

            VStack(spacing: Space.s3) {
                // Sonuç şeridi (BAŞARILDI / KAÇIRILDI).
                Text(result.success ? "BAŞARILDI" : "KAÇIRILDI")
                    .font(.appText(11, .black)).kerning(1.2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Space.s3).padding(.vertical, 4)
                    .background(tint, in: Capsule())

                Text(kind.displayName).font(.titleL).foregroundStyle(theme.text)
                    .multilineTextAlignment(.center)
                Text(blurbForResult).font(.bodyText)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.s3)

                // Etki özeti — uygulanan değişikliklerin listesi.
                if !rewardLines.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(rewardLines.indices, id: \.self) { i in
                            rewardRow(rewardLines[i])
                        }
                    }
                    .padding(Space.s3)
                    .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.s))
                }

                Button {
                    Haptics.tap(); dismiss()
                } label: {
                    Text("Devam Et").font(.bodyL)
                        .modifier(AppButton.primary(theme))
                }
                .buttonStyle(.pressable)
            }
            .padding(.top, Space.s6).padding(.horizontal, Space.s4).padding(.bottom, Space.s4)
            .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.overlay))
            .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
        }
    }

    private var blurbForResult: String {
        if result.success {
            return "Hedefe ulaştın. Hazırlıklar karşılığını verdi."
        }
        return "Hedefi yakalayamadın. Sıradaki olaya daha hazırlıklı git."
    }

    /// Reward'dan UI-friendly satırlar üret (sadece sıfır olmayanları).
    private var rewardLines: [(String, String, Color)] {
        var lines: [(String, String, Color)] = []
        let r = result.reward
        if r.cash != 0 {
            let positive = r.cash > 0
            lines.append((positive ? "Nakit" : "Ceza",
                          (positive ? "+" : "") + BigNumber.money(r.cash),
                          positive ? Palette.success : Palette.danger))
        }
        if r.reputation != 0 {
            let positive = r.reputation > 0
            lines.append(("İtibar",
                          (positive ? "+" : "") + "\(Int(r.reputation))",
                          positive ? Palette.gold : Palette.danger))
        }
        if r.morale != 0 {
            let positive = r.morale > 0
            lines.append(("Moral",
                          (positive ? "+" : "") + "\(Int(r.morale))",
                          positive ? Palette.success : Palette.danger))
        }
        if r.usersPercent != 0 {
            let positive = r.usersPercent > 0
            lines.append(("Kullanıcı",
                          (positive ? "+" : "") + "%\(Int(r.usersPercent * 100))",
                          positive ? Palette.success : Palette.danger))
        }
        return lines
    }

    private func rewardRow(_ row: (String, String, Color)) -> some View {
        HStack {
            Text(row.0).font(.bodyText).foregroundStyle(theme.textSecondary)
            Spacer()
            Text(row.1).font(.numberM).foregroundStyle(row.2)
        }
    }

    private func dismiss() {
        withAnimation(Motion.quick) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            model.dismissScenarioResult()
        }
    }
}
