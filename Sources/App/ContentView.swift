import SwiftUI

/// 5 birincil sekme — alt tab bar. Projeler Ofis'in alt-segmentinde,
/// Yol Haritası İstatistik'in alt-segmentinde, Defter HUD'dan açılır.
enum GameTab: CaseIterable {
    case office, team, growth, modules, stats
    var title: String {
        switch self {
        case .office:  return "Ofis"
        case .team:    return "Ekip"
        case .growth:  return "Büyüme"
        case .modules: return "Modüller"
        case .stats:   return "İstatistik"
        }
    }
    var symbolName: String {
        switch self {
        case .office:  return Icons.Tab.office
        case .team:    return Icons.Tab.team
        case .growth:  return Icons.Tab.growth
        case .modules: return Icons.Tab.modules
        case .stats:   return Icons.Tab.stats
        }
    }
}

struct ContentView: View {
    @StateObject private var model: GameModel
    @StateObject private var store = StoreManager()   // B6 — IAP entitlement (Apple'da)
    @State private var tab: GameTab = {
        // İlk tab — opsiyonel launch argümanıyla override edilebilir (test/QA).
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--start-tab"), i + 1 < args.count {
            switch args[i + 1] {
            case "team":    return .team
            case "growth":  return .growth
            case "modules": return .modules
            case "stats":   return .stats
            default:        return .office
            }
        }
        return .office
    }()
    @State private var topToast: TopToast? = nil
    @State private var toastToken = 0
    @State private var soundEnabled = AudioManager.shared.isEnabled
    @State private var introAppeared = false
    @State private var lessonsOpen = false
    @State private var settingsOpen = false
    @Environment(\.scenePhase) private var scenePhase

    /// Ekranın üstünde yüzen kısa mesaj.
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

            // Ana içerik: HUD + sekme paneli.
            VStack(spacing: 0) {
                HUDView(model: model, theme: theme, soundEnabled: $soundEnabled, settingsOpen: $settingsOpen)
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
                        case .growth:   GrowthPanel(model: model, theme: theme)
                        case .modules:  ModulesPanel(model: model, theme: theme)
                        case .stats:    StatsPanel(model: model, theme: theme)
                        }
                    }
                    .padding(.horizontal, Space.s3)
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
                            .padding(.trailing, Space.s4)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Defter — top-right floating chip (tek ikon, sleek hairline).
            VStack {
                HStack {
                    Spacer()
                    Button { Haptics.selection(); lessonsOpen = true } label: {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(theme.accent)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(theme.hairline))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Defter")
                }
                Spacer()
            }
            .padding(.trailing, Space.s3)
            .padding(.top, 52)   // safe-area + HUD'un üstünde sade köşe yerleşimi
            .opacity(introAppeared ? 1 : 0)
            .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.18),
                       value: introAppeared)

            // HUD nakit yakınında yüzen ±tutar çipi.
            CashDeltaOverlay(model: model)
                .padding(.leading, 110)
                .padding(.top, 48)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)

            timeStateOverlay
        }
        // Alt sticky chunky tab bar — vertical mobil oyun standart düzeni.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomTabBar
                .offset(y: introAppeared ? 0 : 60)
                .opacity(introAppeared ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.18),
                           value: introAppeared)
        }
        // Modal popup'lar tab bar'ın DA ÜSTÜNde, TAM EKRAN — yoksa uzun kartlar tab bar
        // arkasında kalıp aksiyon butonu erişilemiyordu. overlay tüm frame'i (inset dahil) kaplar.
        .overlay { overlays }
        .sheet(isPresented: $lessonsOpen) {
            LessonsPanel(theme: theme, onClose: { lessonsOpen = false })
                .presentationBackground(.clear)
        }
        .sheet(isPresented: $settingsOpen) {
            SettingsView(model: model, theme: theme, soundEnabled: $soundEnabled,
                         onClose: { settingsOpen = false })
                .presentationDetents([.large])
        }
        // D3 — Dynamic Type tavanı: aşırı erişilebilirlik boyutlarında oyun HUD/kart
        // düzeni kırılmasın diye accessibility1 ile sınırla (default boyutta etkisiz).
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if !introAppeared {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { introAppeared = true }
                // Test/QA: --open-lessons defter sheet'ini açılışta aç (otomatik screenshot için).
                if args.contains("--open-lessons") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { lessonsOpen = true }
                }
                // QA: --start-paused → zaman-durumu overlay'ini doğrulamak için duraklatılmış aç.
                if args.contains("--start-paused") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { model.isPaused = true }
                }
                // QA: --demo-lesson → mechanic→ders köprüsü popup'ını açılışta göster.
                if let i = args.firstIndex(of: "--demo-lesson"), i + 1 < args.count {
                    let mech = args[i + 1]
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { model.inspectedMechanic = mech }
                }
                // QA: --demo-win → Win ekranını (+ Kurucu Karnesi) açılışta göster.
                if args.contains("--demo-win") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { model.pendingWin = true }
                }
                // QA: --demo-paywall → Series A yumuşak duvarını (PaywallView) açılışta göster.
                if args.contains("--demo-paywall") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { model.pendingSeriesAGate = true }
                }
                // Not: --force-decision GameModel.init içinde de işlenir (model katmanına da).
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
        .onChange(of: model.companySetupComplete) { _, complete in
            // D2 (#5): bildirim iznini şirket-kuruluşu BİTTİKTEN sonra (doğal an) iste —
            // yalnız daha önce karar verilmemişse sistem diyaloğu gösterilir; reddedilse
            // bile oyun bildirimsiz tam çalışır.
            if complete { NotificationManager.requestAuthorizationIfNeeded() }
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

    /// Alt chunky tab bar — 5 birincil sekme (Ofis/Ekip/Büyüme/Modüller/İstatistik).
    /// Seçili: accent dolu pill + hafif derinlik gölgesi. Pasif: hairline, secondary metin.
    private var bottomTabBar: some View {
        HStack(spacing: Space.s1) {
            ForEach(GameTab.allCases, id: \.self) { t in
                tabPill(t)
            }
        }
        .padding(.horizontal, Space.s2)
        .padding(.top, Space.s2)
        .padding(.bottom, Space.s1)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(theme.hairline).frame(height: 1), alignment: .top)
    }

    private func tabPill(_ t: GameTab) -> some View {
        let selected = tab == t
        return Button {
            guard tab != t else { return }
            Haptics.selection(); Feedback.select()
            withAnimation(Motion.smooth) { tab = t }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: t.symbolName)
                    .font(.system(size: selected ? 19 : 17,
                                  weight: selected ? .bold : .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .symbolEffect(.bounce, value: selected)
                Text(t.title)
                    .font(.appText(10, selected ? .bold : .medium))
            }
            .foregroundStyle(selected ? .white : Palette.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.s2)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                        .fill(theme.accent.opacity(0.92))
                        .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                            .stroke(.white.opacity(0.18)))
                        .shadow(color: theme.accent.opacity(0.25), radius: 5, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                        .stroke(theme.hairline)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t.title)
    }

    /// Simülasyon zaman-durumu görsel geri-bildirimi: oyuncu duraklatma/hız değişimini
    /// EKRANDA net görsün diye. Duraklatma → amber kenar çerçeve + yumuşak scrim + alt
    /// "Duraklatıldı" bandı (dokununca devam). Hızlı (2×/3×) → accent kenar çerçeve.
    /// 1× & oynar durumda hiçbir şey gösterilmez. (Modallar bunun ÜSTÜNDE kalır.)
    @ViewBuilder private var timeStateOverlay: some View {
        let paused = model.isPaused
        let fast = model.speed > 1 && !paused
        ZStack {
            // Duraklatınca hafif scrim — "donmuş" hissi (tıklamayı engellemez).
            if paused {
                Palette.warning.opacity(0.05)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            // Ekran kenarı durum çerçevesi (kayıt-modu kırmızı çerçeve mantığı).
            if paused || fast {
                Rectangle()
                    .strokeBorder(paused ? Palette.warning : theme.accent,
                                  lineWidth: 2.5)
                    .opacity(paused ? 0.85 : 0.5)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            // Duraklatma bandı — alt-merkez, tab bar üstünde, dokununca devam.
            if paused {
                VStack {
                    Spacer()
                    Button { Haptics.selection(); model.togglePause() } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("DURAKLATILDI")
                                .font(.eyebrow).kerning(1.2)
                            Text("· devam için dokun")
                                .font(.appText(11, .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, Space.s4).padding(.vertical, Space.s2 + 2)
                        .background(Palette.warning.opacity(0.92), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
                        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
                    }
                    .buttonStyle(.pressable)
                    .padding(.bottom, Space.s4)
                }
            }
        }
        .animation(Motion.snappy, value: paused)
        .animation(Motion.snappy, value: fast)
    }

    @ViewBuilder private var overlays: some View {
        // #19: ders popup'ı EN ÜSTTE — herhangi bir ℹ/metrik/sonuç köprüsünden,
        // başka bir modal açıkken bile gösterilebilir; kapanınca altındaki geri döner.
        if let mech = model.inspectedMechanic {
            LessonPopupView(model: model, theme: theme, mechanic: mech)
        } else if !model.hasSeenOnboarding {
            OnboardingOverlay(model: model, theme: theme)
        } else if !model.companySetupComplete {
            CompanySetupOverlay(model: model, theme: theme)
        } else if model.pendingBankruptcy {
            BankruptcyView(model: model, theme: theme)
        } else if model.pendingWin {
            WinView(model: model, theme: theme)
        } else if model.pendingSeriesAGate {
            // B6 — Series A yumuşak duvarı: Tam Sürüm varsa görünmez onayla, yoksa paywall.
            if store.isFullVersion {
                Color.clear.onAppear { model.confirmSeriesARaise() }
            } else {
                PaywallView(store: store, theme: theme,
                            onUnlocked: { model.confirmSeriesARaise() },
                            onDismiss: { model.dismissSeriesAGate() })
            }
        } else if let s = model.pendingFundingStage {
            FundingRoundView(model: model, theme: theme, stageIndex: s)
        } else if let finale = model.pendingSeasonFinale {
            SeasonFinaleView(model: model, theme: theme, finale: finale)
        } else if let scenarioResult = model.pendingScenarioResult {
            ScenarioResultView(model: model, theme: theme, result: scenarioResult)
        } else if let review = model.pendingCycleReview {
            CycleReviewView(model: model, theme: theme, review: review)
        } else if let sprint = model.pendingSprintClose {
            SprintCloseView(model: model, theme: theme, close: sprint)
        } else if let close = model.pendingDailyClose {
            DailyCloseView(model: model, theme: theme, close: close)
        } else if let card = model.pendingEvent {
            DecisionCardView(model: model, theme: theme, card: card)
        } else if let result = model.pendingResult {
            // #26: karardan sonra kalıcı sonuç kartı (ders köprülü) — toast'ın yerine.
            ResultCardView(model: model, theme: theme, result: result)
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
