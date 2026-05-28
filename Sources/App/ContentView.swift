import SwiftUI

enum GameTab: CaseIterable {
    case office, team, growth, modules, roadmap, stats
    var title: String {
        switch self {
        case .office: return "Ofis"
        case .team: return "Ekip"
        case .growth: return "Büyüme"
        case .modules: return "Modüller"
        case .roadmap: return "Yol"
        case .stats: return "İstatistik"
        }
    }
    /// SF Symbol adını döndürür (emoji yerine).
    var symbolName: String {
        switch self {
        case .office:  return Icons.Tab.office
        case .team:    return Icons.Tab.team
        case .growth:  return Icons.Tab.growth
        case .modules: return Icons.Tab.modules
        case .roadmap: return Icons.Tab.roadmap
        case .stats:   return Icons.Tab.stats
        }
    }
}

struct ContentView: View {
    @StateObject private var model: GameModel
    @State private var tab: GameTab = .office
    @State private var topToast: TopToast? = nil
    @State private var toastToken = 0
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var tabNS

    /// Ekranın üstünde yüzen kısa mesaj (kurucu ipucu + olay bildirimleri).
    struct TopToast {
        let text: String
        let urgent: Bool
        let token: Int
    }

    init() {
        _model = StateObject(wrappedValue: GameModel())
    }

    private var theme: Theme { Theme(model: model) }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HUDView(model: model, theme: theme)
                    .padding(.horizontal, Space.s4).padding(.top, Space.s2).padding(.bottom, Space.s1)

                ZStack(alignment: .top) {
                    Group {
                        switch tab {
                        case .office:  OfficePanel(model: model, theme: theme)
                        case .team:    TeamPanel(model: model, theme: theme)
                        case .growth:  GrowthPanel(model: model, theme: theme)
                        case .modules: ModulesPanel(model: model, theme: theme)
                        case .roadmap: RoadmapPanel(model: model, theme: theme)
                        case .stats:   StatsPanel(model: model, theme: theme)
                        }
                    }
                    // Tab geçişi: yumuşak fade — sert kesme yerine.
                    .id(tab)
                    .transition(.opacity.combined(with: .offset(y: 6)))

                    // Sağ üstte yüzen bildirim çipi — tıklanabilir, sekmeler arası kalıcı.
                    if let tt = topToast {
                        toastView(tt)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, Space.s2)
                            .padding(.trailing, Space.s4)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                tabBar
            }

            overlays
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.refreshOnForeground()
            case .background, .inactive: model.saveOnBackground()
            @unknown default: break
            }
        }
        // Kurucu ipucu her değiştiğinde üstte toast olarak yüzer.
        .onChange(of: model.founderTip) { _, new in
            let urgent = model.runwayMonths < 3
            showToast(urgent ? NarrativeContent.runwayTip(months: model.runwayMonths) : new, urgent: urgent)
        }
        // Olay bildirimleri (istifa, karar sonucu vb.) de aynı üst toast'ta.
        .onChange(of: model.pendingToast) { _, new in
            guard let new else { return }
            showToast(new, urgent: false)
            model.pendingToast = nil
        }
    }

    /// Üst toast'ı göster + otomatik kapanış (token ile son mesaj yönetimi).
    private func showToast(_ text: String, urgent: Bool) {
        toastToken += 1
        let t = toastToken
        // Giriş: yukarıdan yaylı "doğma" (hafif overshoot). Çıkış: yukarı süzülüp solma.
        withAnimation(Motion.bouncy) { topToast = TopToast(text: text, urgent: urgent, token: t) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            if topToast?.token == t { withAnimation(Motion.quick) { topToast = nil } }
        }
    }

    private func toastView(_ tt: TopToast) -> some View {
        let tint = tt.urgent ? Palette.warning : theme.accent
        return HStack(alignment: .top, spacing: Space.s2) {
            Image(systemName: tt.urgent ? "exclamationmark.triangle.fill" : Icons.Screen.founder)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Text(tt.text)
                .font(.appText(12.5, .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, Space.s3).padding(.vertical, Space.s2 + 2)
        .frame(maxWidth: 250, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(tint.opacity(0.35)))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
        // Bildirim gibi: tıklanınca kapanır.
        .contentShape(RoundedRectangle(cornerRadius: Radius.m))
        .onTapGesture {
            Haptics.selection()
            withAnimation(Motion.quick) { topToast = nil }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .top)
                .combined(with: .scale(scale: 0.85, anchor: .topTrailing))
                .combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }

    @ViewBuilder private var overlays: some View {
        if !model.hasSeenOnboarding {
            OnboardingOverlay(model: model, theme: theme)
        } else if model.pendingBankruptcy {
            BankruptcyView(model: model, theme: theme)
        } else if model.pendingWin {
            WinView(model: model, theme: theme)
        } else if let s = model.pendingFundingStage {
            FundingRoundView(model: model, theme: theme, stageIndex: s)
        } else if let finale = model.pendingSeasonFinale {
            SeasonFinaleView(model: model, theme: theme, finale: finale)
        } else if let review = model.pendingCycleReview {
            CycleReviewView(model: model, theme: theme, review: review)
        } else if let sprint = model.pendingSprintClose {
            SprintCloseView(model: model, theme: theme, close: sprint)
        } else if let close = model.pendingDailyClose {
            DailyCloseView(model: model, theme: theme, close: close)
        } else if let card = model.pendingEvent {
            DecisionCardView(model: model, theme: theme, card: card)
        } else if let report = model.pendingOfflineReport {
            OfflineReportView(theme: theme, report: report) { model.pendingOfflineReport = nil }
        } else if let dept = model.inspectedDept {
            EmployeeCardView(model: model, theme: theme, deptIndex: dept)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(GameTab.allCases, id: \.self) { t in
                let selected = tab == t
                Button {
                    Haptics.selection()
                    withAnimation(Motion.smooth) { tab = t }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.symbolName)
                            .font(.system(size: 18, weight: selected ? .bold : .regular))
                            .symbolRenderingMode(.hierarchical)
                            .symbolEffect(.bounce, value: selected)
                        Text(t.title)
                            .font(.appText(10, selected ? .bold : .regular))
                    }
                    .foregroundStyle(selected ? theme.accent : Palette.textTertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, Space.s2)
                    .background {
                        // Seçili sekme: kayan accent highlight pill.
                        if selected {
                            RoundedRectangle(cornerRadius: Radius.m)
                                .fill(theme.accent.opacity(0.15))
                                .matchedGeometryEffect(id: "tabHighlight", in: tabNS)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Space.s2).padding(.vertical, Space.s1)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(theme.hairline).frame(height: 1), alignment: .top)
    }
}
