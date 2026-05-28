import SwiftUI

/// Ofis ekranındaki "Günlük Hedef" kartı — alt görev listesi + ilerleme barları + streak rozeti.
/// Geri-dönüş kancası (completed-cycle): her gün küçük, tamamlanabilir görevler + streak (🔥 yerine flame.fill).
struct DailyGoalCard: View {
    @ObservedObject var model: GameModel
    var theme: Theme

    private var counts: (done: Int, total: Int) { model.dailyTaskCounts }
    private var allDone: Bool { model.dailyCompleted }

    var body: some View {
        PanelCard(theme: theme, highlighted: allDone) {
            VStack(alignment: .leading, spacing: Space.s3) {
                header
                ForEach(model.dailyTasks) { task in
                    taskRow(task)
                }
            }
        }
    }

    // MARK: Başlık — "Günlük Hedef" + tamamlanan/toplam + streak rozeti.
    private var header: some View {
        HStack(spacing: Space.s2) {
            Image(systemName: "target")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Günlük Hedef")
                    .font(.titleM)
                    .foregroundStyle(theme.text)
                Text(allDone ? "Bugün tamamlandı" : "\(counts.done)/\(counts.total) görev")
                    .font(.labelText)
                    .foregroundStyle(allDone ? Palette.success : theme.subtle)
            }
            Spacer()
            streakBadge
        }
    }

    /// Streak rozeti — flame.fill + ardışık gün sayısı. 0 ise sönük.
    private var streakBadge: some View {
        let active = model.streak > 0
        return HStack(spacing: Space.s1) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(active ? Palette.warning : theme.textQuaternary)
                .symbolEffect(.bounce, value: model.streak)
            Text("\(model.streak)")
                .font(.numberM)
                .foregroundStyle(active ? Palette.warning : theme.textQuaternary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, Space.s2).padding(.vertical, Space.s1)
        .background(active ? Palette.warning.opacity(0.14) : theme.surfaceHigh,
                    in: Capsule())
        .overlay(Capsule().stroke(active ? Palette.warning.opacity(0.4) : .clear, lineWidth: 1))
    }

    // MARK: Alt görev satırı — ikon + başlık + ilerleme barı + done işareti.
    private func taskRow(_ task: DailyTask) -> some View {
        let p = model.dailyProgress(task)
        let done = p.done >= p.target
        let frac = p.target > 0 ? min(1, Double(p.done) / Double(p.target)) : 1
        return HStack(spacing: Space.s3) {
            Image(systemName: done ? "checkmark.circle.fill" : task.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(done ? Palette.success : theme.accent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: Space.s1) {
                HStack {
                    Text(task.title)
                        .font(.bodyText)
                        .foregroundStyle(done ? theme.subtle : theme.text)
                    Spacer()
                    Text("\(p.done)/\(p.target)")
                        .font(.numberXS)
                        .foregroundStyle(done ? Palette.success : theme.subtle)
                        .contentTransition(.numericText())
                }
                progressBar(frac, done: done)
            }
        }
        .padding(Space.s2)
        .cellSurface(theme, corner: Radius.s)
    }

    private func progressBar(_ frac: Double, done: Bool) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.surfaceHigh)
                Capsule()
                    .fill(done ? Palette.success : theme.accent)
                    .frame(width: max(4, geo.size.width * frac))
            }
        }
        .frame(height: 6)
    }
}

/// Genişleyip sönen kutlama parıltı halkası (günlük hedef kapanışı) — CycleReview dilinde.
private struct DailyCloseRing: View {
    let color: Color
    @State private var animate = false
    var body: some View {
        Circle()
            .stroke(color, lineWidth: 3)
            .frame(width: 88, height: 88)
            .scaleEffect(animate ? 2.1 : 0.4)
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2).repeatCount(2, autoreverses: false)) {
                    animate = true
                }
            }
    }
}

/// Günlük hedef kapanış kutlaması (completed-cycle).
/// Stil: CycleReviewView dilini izler — parıltı halkası, surfaceHigh satırlar, success haptik.
struct DailyCloseView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let close: DailyClose
    @State private var appeared = false

    private var color: Color { Palette.warning }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: Space.s4) {
                hero
                Text("Günlük Hedef Tamam!")
                    .font(.titleL)
                    .foregroundStyle(theme.accent)
                Text("Bugünü kapattın. İstikrar kazanıyor — yarın da gel, serini büyüt.")
                    .font(.appText(14, .medium))
                    .foregroundStyle(theme.text)
                    .multilineTextAlignment(.center)

                rewards

                Button { Haptics.tap(); model.dismissDailyClose() } label: {
                    Text("Devam").font(.bodyL)
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

    // MARK: Hero — flame + streak sayısı + parıltı halkası.
    private var hero: some View {
        ZStack {
            if appeared { DailyCloseRing(color: color) }
            ZStack {
                Circle()
                    .fill(color.opacity(0.16))
                    .frame(width: 88, height: 88)
                    .overlay(Circle().stroke(color.opacity(0.5), lineWidth: 3))
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(color)
                        .symbolEffect(.bounce, value: appeared)
                    Text("\(close.streak) gün")
                        .font(.appText(10, .bold))
                        .foregroundStyle(theme.subtle)
                }
            }
            .scaleEffect(appeared ? 1 : 0.5)
        }
        .frame(height: 96)
    }

    // MARK: Ödül satırları — streak + moral/itibar dokunuşu (nakit YOK).
    private var rewards: some View {
        VStack(spacing: Space.s2) {
            rewardRow("Seri", "\(close.streak) gün", icon: "flame.fill", tint: color)
            rewardRow("Moral", "+\(Int(Balance.dailyCompleteMoraleBonus))",
                      icon: Icons.Metric.morale, tint: Palette.success)
            rewardRow("İtibar", "+\(Int(Balance.dailyCompleteReputationBonus))",
                      icon: Icons.Metric.reputation, tint: Palette.success)
            if close.streakMoraleBonus > 0 {
                rewardRow("Seri moral hedefi", "+\(Int(close.streakMoraleBonus.rounded()))",
                          icon: "chart.line.uptrend.xyaxis", tint: theme.accent)
            }
        }
        .padding(Space.s4)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
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
        }
    }
}
