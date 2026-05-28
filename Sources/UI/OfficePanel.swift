import SwiftUI

/// Ana ofis ekranı: 2D top-down kroki (FloorPlanView) + mağaza + kurucu ipucu + hız/funding.
struct OfficePanel: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    @State private var showShop = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: Space.s3) {
                    // KROKİ = hero. Oyunun yıldız varlığı en üstte, scroll'suz görünür.
                    // (Hız kontrolü krokinin başlığına taşındı; kurucu mesajları üst toast'ta.)
                    FloorPlanView(model: model, theme: theme)

                    // Hedefler şeridi — Sprint + Günlük Hedef tek ince satıra toplandı.
                    // Detay için dokun (katlanabilir sayfa). Dikey yer kaplamaz.
                    GoalsStrip(model: model, theme: theme)

                    shopButton

                    if model.canRaise, let next = model.nextStage {
                        raiseButton(next)
                    }
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, Space.s4)
                .padding(.top, Space.s2)
            }
        }
        .sheet(isPresented: $showShop) {
            ItemShopView(model: model, theme: theme)
        }
    }

    /// Mağazayı açan birincil aksiyon.
    private var shopButton: some View {
        Button { Haptics.tap(); showShop = true } label: {
            HStack(spacing: Space.s2) {
                Image(systemName: "cart.fill").font(.system(size: 18, weight: .semibold))
                Text("Mağaza").font(.appText(15, .heavy))
                Spacer()
                Text("\(model.ownedItems.values.reduce(0, +)) eşya · \(Int(model.freeAreaM2)) m² boş")
                    .font(.numberXS).opacity(0.85)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).opacity(0.7)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Space.s4).padding(.vertical, Space.s3)
            .background(theme.accent, in: RoundedRectangle(cornerRadius: Radius.m))
            .shadow(color: theme.accent.opacity(0.45), radius: 10, y: 3)
        }
        .buttonStyle(.pressable)
    }

    private func raiseButton(_ next: StageDef) -> some View {
        Button { Haptics.medium(); model.raiseRound() } label: {
            HStack(spacing: Space.s2) {
                Image(systemName: Icons.Screen.raise)
                    .font(.system(size: 20, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(next.name) Turunu Topla")
                        .font(.appText(15, .heavy))
                    Text("+\(BigNumber.money(next.raiseAmount)) · −%\(Int(next.equityGiven * 100)) hisse")
                        .font(.numberXS)
                        .opacity(0.85)
                }
                Spacer()
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 22))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Space.s4).padding(.vertical, Space.s3)
            .background(Palette.success, in: RoundedRectangle(cornerRadius: Radius.m))
            .shadow(color: Palette.success.opacity(0.5), radius: 12, y: 4)
        }
        .buttonStyle(.pressable)
    }
}

