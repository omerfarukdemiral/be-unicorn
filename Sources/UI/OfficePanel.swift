import SwiftUI

/// Ana ofis ekranı — sleek Aurora.
///
/// Düzen:
/// - (üstte) Eğer canRaise ise: yatay sade "Tur Topla" success-tint pill (sade, glow yok).
/// - Kroki (FloorPlanView) hero — dikey ~60% yer kaplar (içerideki canvas yüksekliğini büyüttük).
/// - Alt action strip: Sprint mini-card · Günlük mini-card · Mağaza primary CTA.
///   Halka/glow chip YOK — sade pill kartlar şeridi.
/// Ofis ekranı sub-tab'i: Kroki (default) veya Projeler.
private enum OfficeSubTab: String, CaseIterable { case kroki, projeler
    var title: String { self == .kroki ? "Kroki" : "Projeler" }
    var icon: String { self == .kroki ? "square.grid.3x3.fill" : "shippingbox.fill" }
}

struct OfficePanel: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    /// Direktif şeridinin "Büyüme'ye git" gibi sekme-geçişi aksiyonları için (ContentView bağlar).
    var onNavigate: ((GameTab) -> Void)? = nil
    @State private var showShop = false
    @State private var expanded: GoalsStrip.Detail? = nil
    @State private var subTab: OfficeSubTab = .kroki

    var body: some View {
        // Diğer panellerle (Ekip/Büyüme/Modüller) AYNI stabil yapı: içerik ScrollView içinde,
        // VStack(s3) + Spacer(minLength:20) + padding(.horizontal s4, .top s3). Eski sabit
        // (scroll'suz, maxHeight:.infinity'li) düzen içerik uzayınca taşıp tab bar'ı kesiyordu.
        // Segment (Kroki|Projeler) sabit üstte; Projeler kendi ScrollView'una sahip ProjectsPanel
        // olduğu için iç-içe scroll'dan kaçınmak adına yalnızca Kroki ScrollView'a sarılır.
        VStack(spacing: 0) {
            segment
                .padding(.horizontal, Space.s4)
                .padding(.top, Space.s3)
                .padding(.bottom, Space.s3)

            if subTab == .kroki {
                ScrollView {
                    VStack(spacing: Space.s3) {
                        // En üstte tek-ses yön: tur toplamaya hazırsa büyük yeşil CTA, değilse
                        // "Sıradaki Adım" direktif şeridi (Faz 3 — "şimdi ne yapayım?").
                        if model.canRaise, let next = model.nextStage {
                            raiseStrip(next)
                        } else {
                            directiveStrip
                        }
                        FloorPlanView(model: model, theme: theme)
                        actionStrip
                        ActivityFeedView(model: model, theme: theme)   // Track C: ekran-içi olay akışı
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, Space.s4)
                }
            } else {
                ProjectsPanel(model: model, theme: theme)
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

    // MARK: - Sleek segment switcher (Kroki | Projeler)

    /// Üst sleek seçici — iki kapsül buton, seçili olan accent dolgulu.
    /// Ofis ekranını alt-segmentlere böler (kroki ve proje portföyü tek tab içinde).
    private var segment: some View {
        HStack(spacing: 6) {
            ForEach(OfficeSubTab.allCases, id: \.self) { t in
                let selected = subTab == t
                Button {
                    Haptics.selection(); withAnimation(Motion.snappy) { subTab = t }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: t.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(t.title)
                            .font(.appText(12, selected ? .bold : .medium))
                    }
                    .foregroundStyle(selected ? .white : theme.subtle)
                    .padding(.horizontal, Space.s3).padding(.vertical, 6)
                    .background(selected ? theme.accent : theme.surfaceHigh, in: Capsule())
                }
                .buttonStyle(.pressable)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Sıradaki Adım direktif şeridi (canRaise DEĞİLken)

    private func directiveTint(_ tone: CausalNote.Tone) -> Color {
        switch tone {
        case .good: return Palette.success
        case .warn: return Palette.warning
        case .bad:  return Palette.danger
        }
    }

    private var directiveStrip: some View {
        let d = model.nextDirective
        let c = directiveTint(d.tone)
        return Button {
            Haptics.tap()
            performDirective(d.action)
        } label: {
            HStack(spacing: Space.s2) {
                ZStack {
                    Circle().fill(c.opacity(0.16)).frame(width: 32, height: 32)
                    Image(systemName: d.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(c)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("SIRADAKİ ADIM")
                        .font(.eyebrow).kerning(0.8)
                        .foregroundStyle(theme.subtle)
                    Text(d.text)
                        .font(.appText(13, .semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if d.action != .none {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.subtle)
                }
            }
            .padding(.horizontal, Space.s3).padding(.vertical, Space.s2 + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(c.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Sıradaki adım: \(d.text)")
    }

    private func performDirective(_ action: GameModel.DirectiveAction) {
        switch action {
        case .raise:  model.raiseRound()
        case .daily:  expanded = .daily
        case .sprint: expanded = .sprint
        case .shop:   showShop = true
        case .growth: onNavigate?(.growth)
        case .none:   break
        }
    }

    // MARK: - Raise strip (canRaise ise, HUD altında sade)

    private func raiseStrip(_ next: StageDef) -> some View {
        Button { Haptics.medium(); model.raiseRound() } label: {
            HStack(spacing: Space.s2) {
                Image(systemName: Icons.Screen.raise)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(next.name) Topla")
                    .font(.bodyL)
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Text("+\(BigNumber.money(next.raiseAmount))")
                    .font(.numberM)
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(.horizontal, Space.s3).padding(.vertical, Space.s2 + 2)
            .background(Palette.success, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(next.name) turunu topla")
    }

    // MARK: - Alt action strip (Sprint+Daily yan yana, altında full Mağaza CTA)

    private var actionStrip: some View {
        VStack(spacing: Space.s2) {
            HStack(spacing: Space.s2) {
                sprintMini
                dailyMini
            }
            shopButton
        }
    }

    private var sprintMini: some View {
        let p = model.sprintProgress.fraction
        let onTrack = model.sprintOnTrack
        return miniCard(
            icon: "bolt.fill",
            title: "Sprint",
            badge: model.sprintsWonThisQuarter > 0
                ? "\(model.sprintsWonThisQuarter)" : "—",
            fraction: p,
            fill: onTrack ? Palette.success : theme.accent,
            highlighted: onTrack
        ) { Haptics.tap(); expanded = .sprint }
    }

    private var dailyMini: some View {
        let c = model.dailyTaskCounts
        let frac = c.total > 0 ? Double(c.done) / Double(c.total) : 0
        let allDone = model.dailyCompleted
        return miniCard(
            icon: "target",
            title: "Günlük",
            badge: model.streak > 0 ? "🔥\(model.streak)" : "\(c.done)/\(c.total)",
            fraction: allDone ? 1 : frac,
            fill: allDone ? Palette.success : theme.accent,
            highlighted: allDone
        ) { Haptics.tap(); expanded = .daily }
    }

    /// Sade mini kart: ikon + ad + sağda küçük badge + altında ince accent fill bar.
    private func miniCard(icon: String, title: String, badge: String,
                          fraction: Double, fill: Color, highlighted: Bool,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: Space.s1 + 2) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(fill)
                    Text(title)
                        .font(.appText(12, .heavy))
                        .foregroundStyle(theme.text)
                    Spacer(minLength: 0)
                    Text(badge)
                        .font(.numberS)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.hairline)
                        Capsule()
                            .fill(fill)
                            .frame(width: max(3, geo.size.width * min(1, max(0, fraction))))
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, Space.s3).padding(.vertical, Space.s2 + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(highlighted ? theme.hairlineStrong : theme.hairline,
                            lineWidth: highlighted ? 1.4 : 1)
            )
        }
        .buttonStyle(.pressable)
    }

    /// Mağaza CTA — primary AppButton stilinde tam kart, sağda m² sade chip.
    private var shopButton: some View {
        Button { Haptics.tap(); showShop = true } label: {
            HStack(spacing: Space.s2) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("Mağaza")
                    .font(.bodyL)
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Text("\(Int(model.freeAreaM2))m²")
                    .font(.numberS)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, Space.s1 + 2).padding(.vertical, 2)
                    .background(.white.opacity(0.16), in: Capsule())
            }
            .padding(.horizontal, Space.s3).padding(.vertical, Space.s2 + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.accent, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Mağaza")
    }
}
