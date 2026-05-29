import SwiftUI

/// Sade hero ışıltı — tek ince halka tek defa açılıp söner (premium kutlama hissi,
/// neon halo değil). Daha küçük scale + daha düşük opacity.
private struct CelebrationRing: View {
    let color: Color
    @State private var animate = false
    var body: some View {
        Circle()
            .stroke(color.opacity(0.55), lineWidth: 1.5)
            .frame(width: 92, height: 92)
            .scaleEffect(animate ? 1.6 : 0.7)
            .opacity(animate ? 0 : 0.85)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1)) {
                    animate = true
                }
            }
    }
}

/// Sade konfeti — sadece kutlama anı; partikül sayısı düşük (premium restraint).
private struct ConfettiBurst: View {
    var colors: [Color] = [Palette.unicorn, Palette.gold, Palette.success, Color(hex: "5B8DEF")]
    private let count = 10
    @State private var fall = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    let seed = Double((i * 73) % 100) / 100
                    let x = seed * geo.size.width
                    let delay = Double((i * 37) % 60) / 100
                    let size = 5 + (Double((i * 53) % 5))
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(colors[i % colors.count])
                        .frame(width: size, height: size * 1.6)
                        .rotationEffect(.degrees(fall ? Double((i * 90) % 360) + 180 : 0))
                        .position(x: x, y: fall ? geo.size.height + 40 : -40)
                        .opacity(fall ? 0 : 1)
                        .animation(.easeIn(duration: 2.0 + seed).delay(delay), value: fall)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { fall = true }
    }
}

/// Funding turu kutlaması (kilometre taşı / prestij anı).
struct FundingRoundView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let stageIndex: Int
    @State private var appeared = false

    private var stage: StageDef { Balance.stages[stageIndex] }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            if appeared {
                ConfettiBurst(colors: [Palette.gold, theme.accent, Palette.success])
                    .ignoresSafeArea()
            }
            VStack(spacing: Space.s4) {
                // Hero görseli: stilize çek + parıltı halkası, milestone yatırım vurgusu.
                ZStack {
                    if appeared { CelebrationRing(color: Palette.gold) }
                    FundingCheckHero(accent: theme.accent, size: 110)
                        .scaleEffect(appeared ? 1 : 0.4)
                }
                .frame(height: 110)

                // "Tur kapandı" üst etiket — gold prestij vurgusu.
                Text("YATIRIM TURU KAPANDI")
                    .font(.eyebrow).tracking(1.4)
                    .foregroundStyle(Palette.gold)
                    .padding(.horizontal, Space.s3).padding(.vertical, Space.s1)
                    .background(Palette.gold.opacity(0.13), in: Capsule())
                Text(stage.name)
                    .font(.titleL)
                    .foregroundStyle(theme.accent)
                Text("Şirketin büyüyor. Yeni ofis: \(stage.officeName).")
                    .font(.appText(14, .medium))
                    .foregroundStyle(theme.text).multilineTextAlignment(.center)
                VStack(spacing: Space.s2) {
                    line("Yatırım", "+\(BigNumber.money(stage.raiseAmount))", icon: "banknote.fill")
                    line("Verilen hisse", "%\(Int(stage.equityGiven * 100))", icon: "chart.pie.fill")
                    line("Unvan", stage.title, icon: "person.badge.shield.checkmark.fill")
                }
                .padding(Space.s4)
                .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))

                Button { Haptics.tap(); model.dismissFunding() } label: {
                    Text("Büyümeye Devam").font(.bodyL)
                        .modifier(AppButton.primary(theme))
                }
                .buttonStyle(.pressable)
            }
            .padding(Space.s5)
            .frame(maxWidth: 340)
            .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.overlay))
            .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
            .padding(.horizontal, Space.s5)
            .scaleEffect(appeared ? 1 : 0.8).opacity(appeared ? 1 : 0)
        }
        .onAppear {
            Haptics.success()
            withAnimation(Motion.bouncy) { appeared = true }
        }
    }

    private func line(_ l: String, _ v: String, icon: String) -> some View {
        HStack(spacing: Space.s2) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 16)
            Text(l).font(.bodyText).foregroundStyle(theme.subtle)
            Spacer()
            Text(v).font(.numberM).foregroundStyle(theme.text)
        }
    }
}

/// Unicorn kazanma ekranı — görkemli final: konfeti + parıltı + başarı özeti.
struct WinView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    @State private var appeared = false
    @State private var showScorecard = false   // B2: Kurucu Karnesi sunumu

    private var league: LeagueDef { model.currentLeague }
    private var seasonTitle: SeasonTitleDef { model.currentSeasonTitle }

    var body: some View {
        ZStack {
            // Derin gece zemin + unicorn parıltısı (üstten ışık).
            Color(hex: "12101F").opacity(0.94).ignoresSafeArea()
            RadialGradient(colors: [Palette.unicorn.opacity(0.22), .clear],
                           center: .top, startRadius: 20, endRadius: 480)
                .ignoresSafeArea()
            if appeared { ConfettiBurst().ignoresSafeArea() }

            // Kutlama içeriği KAYDIRILABİLİR, butonlar altta SABİT (küçük ekran/Dynamic
            // Type'ta taşmaz, "Devam" hep erişilebilir).
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.s4) {
                        ZStack {
                            if appeared { CelebrationRing(color: Palette.unicorn) }
                            UnicornHero(accent: Palette.unicorn, size: 140)
                                .scaleEffect(appeared ? 1 : 0.5)
                        }
                        .frame(height: 140)

                        Text("UNICORN!")
                            .font(.displayXL)
                            .foregroundStyle(Palette.unicorn)

                        Text("$1 MİLYAR DEĞERLEME")
                            .font(.eyebrow)
                            .tracking(1.5)
                            .foregroundStyle(Palette.gold)
                            .padding(.horizontal, Space.s3).padding(.vertical, Space.s1)
                            .background(Palette.gold.opacity(0.14), in: Capsule())
                            .overlay(Capsule().stroke(Palette.gold.opacity(0.4), lineWidth: 1))

                        Text("Garajdan zirveye çıktın, kurucu.\nBu bir efsanenin başlangıcı.")
                            .font(.bodyL)
                            .foregroundStyle(theme.text).multilineTextAlignment(.center)

                        VStack(spacing: Space.s2) {
                            summaryLine("Hisse oranın", "%\(Int(model.founderEquity * 100))",
                                        icon: "chart.pie.fill", tint: Palette.gold)
                            summaryLine(league.name, "Lig", icon: league.icon,
                                        tint: Color(hex: league.colorHex))
                            summaryLine(seasonTitle.name, "Sezon \(model.seasonNumber) · \(model.quarterNumber). Çeyrek",
                                        icon: seasonTitle.icon, tint: Color(hex: seasonTitle.colorHex))
                        }
                        .padding(Space.s4)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: Radius.m))
                        .overlay(RoundedRectangle(cornerRadius: Radius.m)
                            .stroke(Palette.unicorn.opacity(0.25), lineWidth: 1))
                    }
                    .padding(.horizontal, Space.s6).padding(.top, Space.s6).padding(.bottom, Space.s3)
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

                    Button { Haptics.tap(); model.dismissWin() } label: {
                        Text("İmparatorluğu Yönetmeye Devam").font(.bodyL)
                            .modifier(ButtonChrome(bg: Palette.unicorn, fg: .white,
                                                   glow: Palette.unicorn, height: AppButton.height))
                    }
                    .buttonStyle(.pressable)
                }
                .padding(.horizontal, Space.s5).padding(.bottom, Space.s5).padding(.top, Space.s2)
            }
            .frame(maxWidth: 360)
            .scaleEffect(appeared ? 1 : 0.85).opacity(appeared ? 1 : 0)
        }
        .onAppear {
            Haptics.success()
            withAnimation(Motion.bouncy) { appeared = true }
        }
        .fullScreenCover(isPresented: $showScorecard) {
            FounderScorecardView(model: model, theme: theme, onClose: { showScorecard = false })
        }
    }

    private func summaryLine(_ title: String, _ sub: String, icon: String, tint: Color) -> some View {
        HStack(spacing: Space.s2) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.numberM).foregroundStyle(theme.text)
                Text(sub).font(.labelText).foregroundStyle(theme.subtle)
            }
            Spacer()
        }
    }
}

/// İflas ekranı — coaching scorecard'a (PostMortemView) delege eder.
/// "Burada Ne Oldu? · Sonraki Deneme İçin Strateji": dramatik şok yerine bilge post-mortem.
/// Restart akışı KORUNDU: PostMortemView içindeki "Yeni Deneme" butonu
/// model.restartAfterBankruptcy()'i çağırır.
struct BankruptcyView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    var body: some View {
        PostMortemView(model: model, theme: theme)
            .onAppear { Haptics.error() }   // iflas hissi — koçluk başlamadan önce tek darbe.
    }
}

/// "Yokken neler oldu" raporu.
struct OfflineReportView: View {
    var theme: Theme
    let report: OfflineReport
    let dismiss: () -> Void
    @State private var appeared = false

    private var timeText: String {
        let h = Int(report.seconds) / 3600, m = (Int(report.seconds) % 3600) / 60
        return h > 0 ? "\(h)sa \(m)dk" : "\(m)dk"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: Space.s3) {
                // Hoş geldin ikonu
                HStack(spacing: Space.s2) {
                    Image(systemName: Icons.Screen.welcome)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(theme.accent)
                    Text("Tekrar hoş geldin").font(.titleM)
                        .foregroundStyle(theme.text)
                }
                Text("\(timeText) yoktun. Ekip çalışmaya devam etti:")
                    .font(.bodyText)
                    .foregroundStyle(theme.subtle).multilineTextAlignment(.center)
                HStack(spacing: Space.s5) {
                    delta("Nakit", BigNumber.money(report.cashDelta), report.cashDelta >= 0)
                    delta("Kullanıcı", "+\(BigNumber.format(max(0, report.usersDelta)))", report.usersDelta >= 0)
                }
                Button { Haptics.tap(); dismiss() } label: {
                    Text("Devam").font(.bodyL)
                        .modifier(AppButton.primary(theme, glow: false))
                }
                .buttonStyle(.pressable)
            }
            .padding(Space.s5).frame(maxWidth: 320)
            .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.overlay))
            .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
            .padding(.horizontal, Space.s6)
            .scaleEffect(appeared ? 1 : 0.85).opacity(appeared ? 1 : 0)
        }
        .onAppear { withAnimation(Motion.snappy) { appeared = true } }
    }

    private func delta(_ label: String, _ value: String, _ positive: Bool) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.numberL)
                .foregroundStyle(positive ? Palette.success : Palette.danger)
            Text(label).font(.labelText).foregroundStyle(theme.subtle)
        }
    }
}
