import SwiftUI

/// Genişleyip sönen kutlama parıltı halkası.
private struct CelebrationRing: View {
    let color: Color
    @State private var animate = false
    var body: some View {
        Circle()
            .stroke(color, lineWidth: 3)
            .frame(width: 90, height: 90)
            .scaleEffect(animate ? 2.2 : 0.4)
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.3).repeatCount(2, autoreverses: false)) {
                    animate = true
                }
            }
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
            VStack(spacing: Space.s4) {
                // Hero ikon — büyük SF Symbol + parıltı halkası, sevinçli milestone.
                ZStack {
                    if appeared { CelebrationRing(color: Palette.gold) }
                    Image(systemName: Icons.Screen.funding)
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(theme.accent)
                        .scaleEffect(appeared ? 1 : 0.4)
                }
                .frame(height: 90)
                Text("\(stage.name) Turu Kapandı!")
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

/// Unicorn kazanma ekranı.
struct WinView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    @State private var appeared = false
    var body: some View {
        ZStack {
            Color(hex: "12101F").opacity(0.92).ignoresSafeArea()
            VStack(spacing: Space.s4) {
                // Zafer ikonu — taç, $1B başarı sembolü + parıltı.
                ZStack {
                    if appeared { CelebrationRing(color: Palette.unicorn) }
                    Image(systemName: Icons.Screen.win)
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(Palette.unicorn)
                        .scaleEffect(appeared ? 1 : 0.5)
                }
                .frame(height: 100)
                Text("UNICORN!")
                    .font(.displayXL)
                    .foregroundStyle(Palette.unicorn)
                Text("Şirketin $1 milyar değerlemeye ulaştı.\nGarajdan zirveye çıktın, kurucu.")
                    .font(.bodyL)
                    .foregroundStyle(theme.text).multilineTextAlignment(.center)
                Text("Hisse oranın: %\(Int(model.founderEquity * 100))")
                    .font(.numberM)
                    .foregroundStyle(theme.subtle)
                Button { Haptics.tap(); model.dismissWin() } label: {
                    Text("İmparatorluğu Yönetmeye Devam").font(.bodyL)
                        .modifier(ButtonChrome(bg: Palette.unicorn, fg: .white,
                                               glow: Palette.unicorn, height: AppButton.height))
                }
                .buttonStyle(.pressable)
            }
            .padding(Space.s6).frame(maxWidth: 350)
            .padding(.horizontal, Space.s5)
        }
        .onAppear {
            Haptics.success()
            withAnimation(Motion.bouncy) { appeared = true }
        }
    }
}

/// İflas ekranı.
struct BankruptcyView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    var body: some View {
        ZStack {
            Color(hex: "12101F").opacity(0.92).ignoresSafeArea()
            VStack(spacing: Space.s4) {
                // İflas — sekizgen X, dramatik kırmızı
                Image(systemName: Icons.Screen.bankruptcy)
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(Palette.danger)
                Text("İFLAS")
                    .font(.displayXL)
                    .foregroundStyle(Palette.danger)
                Text("Nakit tükendi, ekip dağıldı.\nAma her başarısızlık bir ders.")
                    .font(.appText(14, .medium))
                    .foregroundStyle(theme.text).multilineTextAlignment(.center)
                Text("Kurucu Tecrübesi: \(Int(model.state.founderXP)) · sonraki şirket daha güçlü başlar")
                    .font(.numberS)
                    .foregroundStyle(Palette.gold).multilineTextAlignment(.center)
                Button { Haptics.tap(); model.restartAfterBankruptcy() } label: {
                    Text("Yeniden Kur").font(.bodyL)
                        .modifier(AppButton.danger())
                }
                .buttonStyle(.pressable)
            }
            .padding(Space.s6).frame(maxWidth: 340).padding(.horizontal, Space.s5)
        }
        .onAppear { Haptics.error() }
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
