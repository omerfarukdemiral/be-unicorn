import SwiftUI

/// Ana ofis ekranı — "sahne + floating aksiyonlar" hissi.
///
/// Düzen:
/// - Kroki (FloorPlanView) merkez sahne; HUD'un altında, iki yan floating nav arası.
/// - Sprint + Günlük Hedef: krokinin alt köşelerinde yüzen chunky mini-rozet halkalar
///   (tap → mevcut detay sheet'leri). Eski "GoalsStrip" satırı kaldırıldı → dağınıklık gitti.
/// - Mağaza: krokinin altında büyük floating round action button.
/// - "Tur Topla": uygunsa krokinin altında parıltılı action button (mağaza yanında).
struct OfficePanel: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    @State private var showShop = false
    @State private var expanded: GoalsStrip.Detail? = nil

    var body: some View {
        ZStack(alignment: .center) {
            // Kroki sahnesi — scroll'suz, hero. Yan kümeler için içerik dış marjini ContentView veriyor.
            VStack(spacing: Space.s3) {
                FloorPlanView(model: model, theme: theme)
                    .padding(.top, Space.s1)

                // Sprint + Günlük yüzen mini halkalar — krokinin hemen altında, ortaya yakın.
                HStack(spacing: Space.s4) {
                    sprintRing
                    Spacer()
                    dailyRing
                }
                .padding(.horizontal, Space.s2)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.s2)

            // Alt floating aksiyonlar: Mağaza (her zaman) + Tur Topla (canRaise olursa).
            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: Space.s2) {
                    if model.canRaise, let next = model.nextStage {
                        raiseAction(next)
                    }
                    Spacer()
                    shopAction
                }
                .padding(.horizontal, Space.s2)
                .padding(.bottom, Space.s3)
            }
        }
        .sheet(isPresented: $showShop) {
            ItemShopView(model: model, theme: theme)
        }
        .sheet(item: $expanded) { which in
            GoalDetailSheet(model: model, theme: theme, detail: which)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Sprint / Daily yüzen mini halka rozetler

    private var sprintRing: some View {
        let p = model.sprintProgress.fraction
        let onTrack = model.sprintOnTrack
        return floatingRing(
            icon: "bolt.fill",
            tint: onTrack ? Palette.success : theme.accent,
            fraction: p,
            badgeIcon: "checkmark.seal.fill",
            badgeValue: model.sprintsWonThisQuarter,
            badgeColor: Palette.success,
            label: "Sprint"
        ) { Haptics.tap(); expanded = .sprint }
    }

    private var dailyRing: some View {
        let c = model.dailyTaskCounts
        let frac = c.total > 0 ? Double(c.done) / Double(c.total) : 0
        let allDone = model.dailyCompleted
        return floatingRing(
            icon: "target",
            tint: allDone ? Palette.success : theme.accent,
            fraction: allDone ? 1 : frac,
            badgeIcon: "flame.fill",
            badgeValue: model.streak,
            badgeColor: Palette.warning,
            label: "Günlük"
        ) { Haptics.tap(); expanded = .daily }
    }

    /// Chunky daire — dolgu halkalı progress + ortada ikon + sağ-üst köşe rozet (streak/win).
    private func floatingRing(icon: String, tint: Color, fraction: Double,
                              badgeIcon: String, badgeValue: Int, badgeColor: Color,
                              label: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                ZStack {
                    // Zemin daire (chunky).
                    Circle()
                        .fill(theme.surfaceElevated)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1.3))
                        .shadow(color: .black.opacity(0.4), radius: 5, y: 3)

                    // İlerleme halkası.
                    Circle()
                        .stroke(tint.opacity(0.2), lineWidth: 3)
                        .frame(width: 40, height: 40)
                    Circle()
                        .trim(from: 0, to: max(0.001, min(1, fraction)))
                        .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: tint.opacity(0.5), radius: 4)

                    // Orta ikon.
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(tint)

                    // Sağ-üst köşe streak/win rozeti.
                    if badgeValue > 0 {
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle().fill(badgeColor)
                                        .frame(width: 18, height: 18)
                                        .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1.2))
                                        .shadow(color: badgeColor.opacity(0.5), radius: 3, y: 1)
                                    HStack(spacing: 1) {
                                        Image(systemName: badgeIcon)
                                            .font(.system(size: 7, weight: .black))
                                            .foregroundStyle(.white)
                                        Text("\(badgeValue)")
                                            .font(.appNumber(8, .heavy))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .offset(x: 3, y: -3)
                            }
                            Spacer()
                        }
                        .frame(width: 44, height: 44)
                    }
                }
                Text(label.uppercased())
                    .font(.appText(9, .black))
                    .kerning(0.5)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.trailing, 4)
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Capsule().fill(theme.surfaceElevated.opacity(0.7)))
            .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1.1))
            .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Floating aksiyon butonları

    /// Mağaza — chunky büyük yuvarlak action button + altında MAĞAZA chip.
    private var shopAction: some View {
        Button { Haptics.tap(); showShop = true } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [theme.accent, theme.accent.opacity(0.78)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 2))
                        .shadow(color: theme.accent.opacity(0.65), radius: 12, y: 5)
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                    Image(systemName: "cart.fill")
                        .font(.system(size: 23, weight: .black))
                        .foregroundStyle(.white)
                }
                .overlay(alignment: .topTrailing) {
                    // Boş alan göstergesi rozeti.
                    Text("\(Int(model.freeAreaM2))m²")
                        .font(.appNumber(9, .heavy))
                        .foregroundStyle(.black.opacity(0.85))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(Palette.gold))
                        .overlay(Capsule().stroke(.white.opacity(0.6), lineWidth: 1))
                        .shadow(color: Palette.gold.opacity(0.4), radius: 3, y: 1)
                        .offset(x: 6, y: -4)
                }
                Text("MAĞAZA")
                    .font(.appText(8, .black))
                    .kerning(0.6)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(theme.accent))
                    .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
            }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Mağaza")
    }

    /// Tur topla — parıltılı yeşil chunky action button (yalnız uygunsa).
    private func raiseAction(_ next: StageDef) -> some View {
        Button { Haptics.medium(); model.raiseRound() } label: {
            HStack(spacing: Space.s2) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Palette.success, Palette.successDim],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(.white.opacity(0.55), lineWidth: 1.8))
                        .shadow(color: Palette.success.opacity(0.6), radius: 8, y: 3)
                    Image(systemName: Icons.Screen.raise)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(next.name) Topla")
                        .font(.appText(12, .black))
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text("+\(BigNumber.money(next.raiseAmount))")
                        .font(.appNumber(11, .heavy))
                        .foregroundStyle(Palette.gold)
                }
                .padding(.trailing, Space.s2)
            }
            .padding(.leading, 4).padding(.vertical, 4)
            .background(Capsule().fill(theme.surfaceElevated.opacity(0.95)))
            .overlay(Capsule().stroke(Palette.success.opacity(0.55), lineWidth: 1.6))
            .shadow(color: Palette.success.opacity(0.45), radius: 10, y: 3)
            .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(next.name) turunu topla")
    }
}
