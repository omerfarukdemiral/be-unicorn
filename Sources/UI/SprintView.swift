import SwiftUI

/// Ofis ekranındaki "Haftalık Sprint" kartı — net hedef + ilerleme barı + kalan süre şeridi.
/// Completed-cycle: çeyrek içinde kısa, kapanan, tek amaçlı döngü. Süre dolunca kapanış.
struct SprintCard: View {
    @ObservedObject var model: GameModel
    var theme: Theme

    private var goal: SprintGoal { model.sprintGoal }
    private var progress: (fraction: Double, done: Double, target: Double) { model.sprintProgress }
    private var onTrack: Bool { model.sprintOnTrack }

    var body: some View {
        PanelCard(theme: theme, highlighted: onTrack) {
            VStack(alignment: .leading, spacing: Space.s3) {
                header
                goalRow
                timeStrip
            }
        }
    }

    // MARK: Başlık — "Haftalık Sprint" + sprint no + bu çeyrek kazanılan rozet.
    private var header: some View {
        HStack(spacing: Space.s2) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Haftalık Sprint")
                    .font(.titleM)
                    .foregroundStyle(theme.text)
                Text("Sprint \(model.sprintNumber) · Çeyrek \(model.quarterNumber)")
                    .font(.labelText)
                    .foregroundStyle(theme.subtle)
            }
            Spacer()
            winsBadge
        }
    }

    /// Bu çeyrekte başarıyla kapanan sprint sayısı rozeti. 0 ise sönük.
    private var winsBadge: some View {
        let active = model.sprintsWonThisQuarter > 0
        return HStack(spacing: Space.s1) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(active ? Palette.success : theme.textQuaternary)
                .symbolEffect(.bounce, value: model.sprintsWonThisQuarter)
            Text("\(model.sprintsWonThisQuarter)")
                .font(.numberM)
                .foregroundStyle(active ? Palette.success : theme.textQuaternary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, Space.s2).padding(.vertical, Space.s1)
        .background(active ? Palette.success.opacity(0.14) : theme.surfaceHigh, in: Capsule())
        .overlay(Capsule().stroke(active ? Palette.success.opacity(0.4) : .clear, lineWidth: 1))
    }

    // MARK: Hedef satırı — ikon + hedef metni + ilerleme barı + done/target.
    private var goalRow: some View {
        let frac = progress.fraction
        let done = onTrack
        return HStack(spacing: Space.s3) {
            Image(systemName: done ? "checkmark.circle.fill" : goal.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(done ? Palette.success : theme.accent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: Space.s1) {
                HStack {
                    Text(goal.title)
                        .font(.bodyText)
                        .foregroundStyle(done ? theme.subtle : theme.text)
                    Spacer()
                    Text(SprintSystem.progressText(goal: goal, done: progress.done, target: progress.target))
                        .font(.numberXS)
                        .foregroundStyle(done ? Palette.success : theme.subtle)
                        .contentTransition(.numericText())
                }
                progressBar(frac, fill: done ? Palette.success : theme.accent)
                Text(goal.caption)
                    .font(.caption)
                    .foregroundStyle(theme.subtle)
            }
        }
        .padding(Space.s2)
        .cellSurface(theme, corner: Radius.s)
    }

    // MARK: Kalan süre şeridi — süre geçtikçe dolan ince bar + kalan saniye.
    private var timeStrip: some View {
        HStack(spacing: Space.s2) {
            Image(systemName: "clock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.subtle)
            progressBar(model.sprintTimeProgress, fill: Palette.warning)
            Text(timeText)
                .font(.numberXS)
                .foregroundStyle(theme.subtle)
                .frame(width: 52, alignment: .trailing)
                .contentTransition(.numericText())
        }
    }

    private var timeText: String {
        let s = model.sprintSecondsRemaining
        if s >= 60 { return "\(Int(s / 60)) dk" }
        return "\(Int(max(0, s))) sn"
    }

    private func progressBar(_ frac: Double, fill: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.surfaceHigh)
                Capsule()
                    .fill(fill)
                    .frame(width: max(4, geo.size.width * min(1, max(0, frac))))
            }
        }
        .frame(height: 6)
    }
}

/// Sade hero ışıltı (sprint zaferi — kontrollü kutlama, neon halo YOK).
private struct SprintCelebrationRing: View {
    let color: Color
    @State private var animate = false
    var body: some View {
        Circle()
            .stroke(color.opacity(0.55), lineWidth: 1.5)
            .frame(width: 92, height: 92)
            .scaleEffect(animate ? 1.5 : 0.7)
            .opacity(animate ? 0 : 0.85)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1)) {
                    animate = true
                }
            }
    }
}

/// Haftalık sprint kapanışı (completed-cycle). Süre dolunca her zaman SONUÇ:
/// başarılı → belirgin zirve + kutlama + ödül; başarısız → yine kapanış (sonucu görürsün).
/// Stil: CycleReviewView / DailyCloseView dilini izler (parıltı halkası, surfaceHigh satırlar).
struct SprintCloseView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let close: SprintClose
    @State private var appeared = false

    private var color: Color { close.success ? Palette.gold : theme.subtle }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: Space.s4) {
                hero
                Text(close.success ? "Sprint \(close.sprint) Başarılı!" : "Sprint \(close.sprint) Kapandı")
                    .font(.titleL)
                    .foregroundStyle(close.success ? Palette.gold : theme.accent)
                Text(headline)
                    .font(.appText(14, .medium))
                    .foregroundStyle(theme.text)
                    .multilineTextAlignment(.center)

                resultCard
                if close.success { rewards }

                Button { Haptics.tap(); model.startNextSprint() } label: {
                    Text("Yeni Sprint").font(.bodyL)
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
            // Başarıda kutlama haptiği; başarısızlıkta yumuşak dokunuş.
            if close.success { Haptics.success() } else { Haptics.rigid() }
            withAnimation(Motion.bouncy) { appeared = true }
        }
    }

    private var headline: String {
        close.success
            ? "Hedefi tutturdun. İvme seninle — taze bir sprintle devam et."
            : "Bu sprint hedefe ulaşamadı. Önemli değil — yeni sprint, yeni şans."
    }

    // MARK: Hero — sprint ikonu + ilerleme halkası + (başarıda) parıltı.
    private var hero: some View {
        let frac = close.targetValue > 0 ? min(1, close.doneValue / close.targetValue) : 1
        return ZStack {
            if appeared && close.success { SprintCelebrationRing(color: Palette.gold) }
            ZStack {
                Circle()
                    .stroke(theme.surfaceHigh, lineWidth: 7)
                    .frame(width: 92, height: 92)
                Circle()
                    .trim(from: 0, to: appeared ? frac : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 92, height: 92)
                    .rotationEffect(.degrees(-90))
                Image(systemName: close.success ? "trophy.fill" : close.goal.icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(color)
                    .symbolEffect(.bounce, value: appeared)
            }
            .scaleEffect(appeared ? 1 : 0.5)
        }
        .frame(height: 96)
    }

    // MARK: Sonuç satırı — hedef + ulaşılan (her zaman gösterilir).
    private var resultCard: some View {
        VStack(spacing: Space.s2) {
            resultRow("Hedef", close.goal.title, icon: close.goal.icon, tint: theme.accent)
            resultRow("Ulaşılan",
                      SprintSystem.progressText(goal: close.goal, done: close.doneValue, target: close.targetValue),
                      icon: close.success ? "checkmark.circle.fill" : "minus.circle.fill",
                      tint: close.success ? Palette.success : Palette.danger)
        }
        .padding(Space.s4)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
    }

    // MARK: Ödül satırları — sadece başarıda; küçük moral/itibar (nakit YOK).
    private var rewards: some View {
        VStack(spacing: Space.s2) {
            resultRow("Moral", "+\(Int(Balance.sprintWinMoraleBonus))",
                      icon: Icons.Metric.morale, tint: Palette.success)
            resultRow("İtibar", "+\(Int(Balance.sprintWinReputationBonus))",
                      icon: Icons.Metric.reputation, tint: Palette.success)
            resultRow("Lig katkısı", "Çeyrek skoruna",
                      icon: "checkmark.seal.fill", tint: Palette.gold)
        }
        .padding(Space.s4)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
    }

    private func resultRow(_ label: String, _ value: String, icon: String, tint: Color) -> some View {
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
}
