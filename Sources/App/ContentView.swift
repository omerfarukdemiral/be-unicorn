import SwiftUI

enum GameTab: CaseIterable {
    case office, team, projects, growth, modules, roadmap, stats
    var title: String {
        switch self {
        case .office:   return "Ofis"
        case .team:     return "Ekip"
        case .projects: return "Projeler"
        case .growth:   return "Büyüme"
        case .modules:  return "Modüller"
        case .roadmap:  return "Yol"
        case .stats:    return "İstatistik"
        }
    }
    /// SF Symbol adını döndürür.
    var symbolName: String {
        switch self {
        case .office:   return Icons.Tab.office
        case .team:     return Icons.Tab.team
        case .projects: return Icons.Tab.projects
        case .growth:   return Icons.Tab.growth
        case .modules:  return Icons.Tab.modules
        case .roadmap:  return Icons.Tab.roadmap
        case .stats:    return Icons.Tab.stats
        }
    }
}

struct ContentView: View {
    @StateObject private var model: GameModel
    @State private var tab: GameTab = {
        // İlk tab — opsiyonel launch argümanıyla override edilebilir (test/QA).
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--start-tab"), i + 1 < args.count {
            switch args[i + 1] {
            case "team":     return .team
            case "projects": return .projects
            case "growth":   return .growth
            case "modules":  return .modules
            case "roadmap":  return .roadmap
            case "stats":    return .stats
            default:         return .office
            }
        }
        return .office
    }()
    @State private var topToast: TopToast? = nil
    @State private var toastToken = 0
    @State private var soundEnabled = AudioManager.shared.isEnabled
    @State private var introAppeared = false
    @State private var lessonsOpen = false
    @Environment(\.scenePhase) private var scenePhase

    /// Ekranın üstünde yüzen kısa mesaj.
    struct TopToast {
        let text: String
        let urgent: Bool
        let token: Int
    }

    /// Sağ kenarda yüzen rail (tek küme) için panellerin rezerve edeceği yatay padding.
    /// Rail genişliği ~52pt + dış s2+ → 70pt güvenli.
    private static let railReserve: CGFloat = 70

    /// Tüm sekmeler tek rail içinde — sıra: ana döngü + meta.
    private static let railTabs: [GameTab] =
        [.office, .team, .projects, .growth, .modules, .roadmap, .stats]

    init() {
        _model = StateObject(wrappedValue: GameModel())
    }

    private var theme: Theme { Theme(model: model) }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()

            // Ana içerik: HUD + sekme paneli.
            VStack(spacing: 0) {
                HUDView(model: model, theme: theme, soundEnabled: $soundEnabled)
                    .padding(.horizontal, Space.s3)
                    .padding(.top, Space.s2)
                    .padding(.bottom, Space.s2)
                    .offset(y: introAppeared ? 0 : -40)
                    .opacity(introAppeared ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.05),
                               value: introAppeared)

                ZStack(alignment: .top) {
                    Group {
                        switch tab {
                        case .office:   OfficePanel(model: model, theme: theme)
                        case .team:     TeamPanel(model: model, theme: theme)
                        case .projects: ProjectsPanel(model: model, theme: theme)
                        case .growth:   GrowthPanel(model: model, theme: theme)
                        case .modules:  ModulesPanel(model: model, theme: theme)
                        case .roadmap:  RoadmapPanel(model: model, theme: theme)
                        case .stats:    StatsPanel(model: model, theme: theme)
                        }
                    }
                    // Sağdaki rail için içerik nefes alsın (yalnız sağdan).
                    .environment(\.sideMenuTrailing, Self.railReserve)
                    .padding(.leading, Space.s3)
                    .padding(.trailing, Self.railReserve)
                    .id(tab)
                    .transition(.opacity.combined(with: .offset(y: 6)))
                    .scaleEffect(introAppeared ? 1 : 0.96)
                    .opacity(introAppeared ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.1),
                               value: introAppeared)

                    if let tt = topToast {
                        toastView(tt)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, Space.s1)
                            .padding(.trailing, Self.railReserve + Space.s2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // SAĞ tek sleek rail — tüm sekmeler + Defter + ses.
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                SideRail(theme: theme,
                         tab: $tab,
                         tabs: Self.railTabs,
                         onLessons: { lessonsOpen = true },
                         soundEnabled: $soundEnabled)
            }
            .padding(.trailing, Space.s2 + 2)
            .padding(.vertical, Space.s2)
            .offset(x: introAppeared ? 0 : 100)
            .opacity(introAppeared ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.18),
                       value: introAppeared)

            // HUD nakit yakınında yüzen ±tutar çipi.
            CashDeltaOverlay(model: model)
                .padding(.leading, 110)
                .padding(.top, 48)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)

            overlays
        }
        .sheet(isPresented: $lessonsOpen) {
            LessonsPanel(theme: theme, onClose: { lessonsOpen = false })
                .presentationBackground(.clear)
        }
        .onAppear {
            guard !introAppeared else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { introAppeared = true }
            // Test/QA: --open-lessons defter sheet'ini açılışta aç (otomatik screenshot için).
            if ProcessInfo.processInfo.arguments.contains("--open-lessons") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { lessonsOpen = true }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                model.refreshOnForeground()
                AudioManager.shared.resume()
            case .background, .inactive:
                model.saveOnBackground()
                AudioManager.shared.pause()
            @unknown default: break
            }
        }
        .onChange(of: model.founderTip) { _, new in
            let urgent = model.runwayMonths < 3
            showToast(urgent ? NarrativeContent.runwayTip(months: model.runwayMonths) : new, urgent: urgent)
        }
        .onChange(of: model.pendingToast) { _, new in
            guard let new else { return }
            showToast(new, urgent: false)
            model.pendingToast = nil
        }
    }

    private func showToast(_ text: String, urgent: Bool) {
        toastToken += 1
        let t = toastToken
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
        .frame(maxWidth: 240, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(tint.opacity(0.35)))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
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
        } else if !model.companySetupComplete {
            CompanySetupOverlay(model: model, theme: theme)
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
}

// MARK: - Environment: rail yatay rezerv (paneller okuyabilir)
private struct SideMenuTrailingKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}
extension EnvironmentValues {
    /// Sağ rail için panellerin bilmesi gereken yatay padding rezervi (eski isim korundu).
    var sideMenuTrailing: CGFloat {
        get { self[SideMenuTrailingKey.self] }
        set { self[SideMenuTrailingKey.self] = newValue }
    }
}
