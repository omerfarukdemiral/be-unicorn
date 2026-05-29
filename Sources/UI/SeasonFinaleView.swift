import SwiftUI

/// Görkemli sezon finali kutlaması (completed-cycle zincirinin en üstü).
/// Birkaç çeyrek = 1 sezon. Sezon dolunca: kahraman ünvan/rozet + sezon özeti satırları +
/// KALICI ödül (küçük üretim çarpanı) + "Yeni Sezon". Stil: Funding/Win + CycleReview dilini izler
/// (gold/unicorn paleti, parıltı halkası, surfaceHigh satırlar, success haptik).
struct SeasonFinaleView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let finale: SeasonFinale
    @State private var appeared = false
    @State private var showScorecard = false   // B2: Kurucu Karnesi sunumu

    private var titleColor: Color { Color(hex: finale.title.colorHex) }

    var body: some View {
        ZStack {
            // Görkemli zemin — Win ekranı dilinde koyu unicorn tonu.
            Color(hex: "12101F").opacity(0.92).ignoresSafeArea()
            // Gövde KAYDIRILABİLİR, butonlar altta SABİT → ekrandan taşmaz, hep erişilebilir.
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.s4) {
                        hero
                        Text("Sezon \(finale.season) Tamamlandı!")
                            .font(.titleL)
                            .foregroundStyle(Palette.gold)
                        Text("Görkemli bir sezon kapandı. Kalıcı bir ünvan ve avantaj kazandın — sonraki sezonlara taşınır.")
                            .font(.appText(14, .medium))
                            .foregroundStyle(theme.text)
                            .multilineTextAlignment(.center)

                        titleCard
                        summaryCard
                        rewardCard
                    }
                    .padding(Space.s5)
                }
                // Sabit alt aksiyonlar.
                VStack(spacing: Space.s2) {
                    Button { Haptics.selection(); showScorecard = true } label: {
                        HStack(spacing: Space.s2) {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Kurucu Karnesini Gör").font(.bodyL)
                        }
                        .modifier(AppButton.secondary(theme))
                    }
                    .buttonStyle(.pressable)

                    Button { Haptics.tap(); model.startNextSeason() } label: {
                        Text("Yeni Sezon").font(.bodyL)
                            .modifier(ButtonChrome(bg: Palette.gold, fg: Color(hex: "1A1320"),
                                                   glow: Palette.gold, height: AppButton.height))
                    }
                    .buttonStyle(.pressable)
                }
                .padding(.horizontal, Space.s5)
                .padding(.top, Space.s3).padding(.bottom, Space.s4)
            }
            .frame(maxWidth: 380)
            .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.overlay))
            .overlay(RoundedRectangle(cornerRadius: Radius.overlay)
                .stroke(theme.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
            .padding(.horizontal, Space.s4)
            .padding(.vertical, Space.s4)
            .scaleEffect(appeared ? 1 : 0.8).opacity(appeared ? 1 : 0)
        }
        .onAppear {
            Haptics.success()
            withAnimation(Motion.bouncy) { appeared = true }
        }
        .fullScreenCover(isPresented: $showScorecard) {
            FounderScorecardView(model: model, theme: theme, onClose: { showScorecard = false })
        }
    }

    // MARK: Hero — stilize madalya (Path) + tek sade ışıltı halkası.
    private var hero: some View {
        ZStack {
            if appeared {
                SeasonGlowRing(color: Palette.gold, size: 116)
            }
            MedalHero(accent: titleColor, size: 116)
                .scaleEffect(appeared ? 1 : 0.5)
        }
        .frame(height: 116)
    }

    // MARK: Ünvan kartı — kazanılan kalıcı ünvan + koleksiyon sayacı.
    private var titleCard: some View {
        VStack(spacing: Space.s1) {
            Text("YENİ ÜNVAN").font(.caption).kerning(0.8)
                .foregroundStyle(theme.subtle)
            Text(finale.title.name)
                .font(.appText(20, .black))
                .foregroundStyle(titleColor)
                .multilineTextAlignment(.center)
            Text("Koleksiyon: \(finale.season) ünvan")
                .font(.numberXS)
                .foregroundStyle(theme.subtle)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.s4)
        .background(titleColor.opacity(0.10), in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(titleColor.opacity(0.3), lineWidth: 1))
    }

    // MARK: Sezon özeti — terfi / en yüksek lig / sprint / günlük / ortalama skor.
    private var summaryCard: some View {
        let s = finale.summary
        return VStack(alignment: .leading, spacing: Space.s2) {
            Text("SEZON ÖZETİ").font(.caption).kerning(0.8)
                .foregroundStyle(theme.subtle)
            row("Kapanan çeyrek", "\(s.quarters)", icon: "calendar")
            row("Kazanılan terfi", "\(s.promotions)", icon: "arrow.up.circle.fill")
            row("En yüksek lig", LeagueSystem.league(s.highestTier).name,
                icon: LeagueSystem.league(s.highestTier).icon)
            row("Kazanılan sprint", "\(s.sprintsWon)", icon: "bolt.fill")
            row("Günlük hedef", "\(s.dailyGoals)", icon: "flame.fill")
            row("Ortalama skor", "\(Int(s.avgScore.rounded()))", icon: "chart.bar.fill")
        }
        .padding(Space.s4)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
    }

    // MARK: Kalıcı ödül kartı — küçük üretim çarpanı (kalıcı, sonraki sezonlara taşınır).
    private var rewardCard: some View {
        VStack(spacing: Space.s2) {
            Text("KALICI ÖDÜL").font(.caption).kerning(0.8)
                .foregroundStyle(theme.subtle)
            rewardRow("Kalıcı üretim", "+\(pct(finale.bonusGained))",
                      icon: "infinity", tint: Palette.gold)
            rewardRow("Toplam kalıcı çarpan", "+\(pct(finale.totalBonusAfter))",
                      icon: "bolt.badge.clock.fill", tint: Palette.success)
            rewardRow("Moral / İtibar",
                      "+\(Int(Balance.seasonFinaleMoraleBonus)) / +\(Int(Balance.seasonFinaleReputationBonus))",
                      icon: Icons.Metric.morale, tint: Palette.success)
        }
        .padding(Space.s4)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
    }

    private func row(_ label: String, _ value: String, icon: String) -> some View {
        HStack(spacing: Space.s2) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 16)
            Text(label).font(.bodyText).foregroundStyle(theme.subtle)
            Spacer()
            Text(value).font(.numberM).foregroundStyle(theme.text)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private func rewardRow(_ label: String, _ value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: Space.s2) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 16)
            Text(label).font(.bodyText).foregroundStyle(theme.subtle)
            Spacer()
            Text(value).font(.numberM).foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private func pct(_ v: Double) -> String { "%\(Int((v * 100).rounded()))" }
}

/// Sade hero ışıltı (sezon finali — kontrollü kutlama, neon halo YOK).
private struct SeasonGlowRing: View {
    let color: Color
    var size: CGFloat = 96
    @State private var animate = false
    var body: some View {
        Circle()
            .stroke(color.opacity(0.55), lineWidth: 1.5)
            .frame(width: size, height: size)
            .scaleEffect(animate ? 1.6 : 0.7)
            .opacity(animate ? 0 : 0.85)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2)) {
                    animate = true
                }
            }
    }
}

/// Yol Haritası için kompakt sezon/ünvan koleksiyon kartı — kazanılan ünvanlar + kalıcı çarpan.
struct SeasonCollectionCard: View {
    @ObservedObject var model: GameModel
    var theme: Theme

    private var earned: Int { model.seasonsCompleted }

    var body: some View {
        PanelCard(theme: theme) {
            VStack(alignment: .leading, spacing: Space.s3) {
                HStack(spacing: Space.s2) {
                    Image(systemName: "rosette")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Palette.gold)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Sezon Koleksiyonu")
                            .font(.titleM)
                            .foregroundStyle(theme.text)
                        Text("Sezon \(model.seasonNumber) · \(earned) ünvan kazanıldı")
                            .font(.labelText)
                            .foregroundStyle(theme.subtle)
                    }
                    Spacer()
                    seasonProgressRing
                }

                if earned > 0 {
                    titleGrid
                    bonusLine
                } else {
                    Text("İlk sezonunu (\(Balance.quartersPerSeason) çeyrek) tamamla → kalıcı ünvan + üretim çarpanı kazan.")
                        .font(.bodyText)
                        .foregroundStyle(theme.subtle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // Bu sezonun çeyrek ilerleme halkası.
    private var seasonProgressRing: some View {
        ZStack {
            Circle().stroke(Palette.gold.opacity(0.22), lineWidth: 3)
                .frame(width: 30, height: 30)
            Circle()
                .trim(from: 0, to: model.seasonProgress)
                .stroke(Palette.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 30, height: 30)
                .rotationEffect(.degrees(-90))
            Text("\(Int(model.seasonProgress * Double(Balance.quartersPerSeason)))")
                .font(.appNumber(11, .bold))
                .foregroundStyle(Palette.gold)
        }
    }

    // Kazanılan ünvan rozetleri (1..earned), yatay sarmalı.
    private var titleGrid: some View {
        let cols = [GridItem(.adaptive(minimum: 64), spacing: Space.s2)]
        return LazyVGrid(columns: cols, alignment: .leading, spacing: Space.s2) {
            ForEach(1...max(1, earned), id: \.self) { season in
                let t = SeasonSystem.title(forSeason: season)
                let c = Color(hex: t.colorHex)
                VStack(spacing: Space.s1) {
                    Image(systemName: t.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(c)
                        .frame(width: 40, height: 40)
                        .background(c.opacity(0.14), in: Circle())
                        .overlay(Circle().stroke(c.opacity(0.4), lineWidth: 1))
                    Text(t.name)
                        .font(.appText(9, .bold))
                        .foregroundStyle(theme.subtle)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(width: 64)
            }
        }
    }

    private var bonusLine: some View {
        let bonus = model.seasonMultiplier - 1
        return HStack(spacing: Space.s2) {
            Image(systemName: "infinity")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.gold)
            Text("Kalıcı üretim çarpanı")
                .font(.bodyText).foregroundStyle(theme.subtle)
            Spacer()
            Text("+%\(Int((bonus * 100).rounded()))")
                .font(.numberM).foregroundStyle(Palette.gold)
        }
        .padding(Space.s2)
        .cellSurface(theme, corner: Radius.s)
    }
}
