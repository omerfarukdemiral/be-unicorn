import SwiftUI

/// Ofis ekranındaki kompakt "Hedefler" şeridi.
/// Sprint + Günlük Hedef'i tek satıra topal — yan yana iki mini özet kart
/// (başlık + ilerleme barı + streak/win rozeti). Dokununca tam detay açılır.
/// Amaç: dikey yer kaplamasın, kroki hero kalsın; ama ilerleme + seri canlı görünsün.
struct GoalsStrip: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    /// Açılan detay sayfası: .sprint / .daily / nil.
    @State private var expanded: Detail? = nil

    enum Detail: Identifiable { case sprint, daily; var id: Int { self == .sprint ? 0 : 1 } }

    var body: some View {
        HStack(spacing: Space.s2) {
            sprintMini
            dailyMini
        }
        .sheet(item: $expanded) { which in
            GoalDetailSheet(model: model, theme: theme, detail: which)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Sprint mini — bolt + sprint ilerlemesi + bu çeyrek kazanılan rozet.
    private var sprintMini: some View {
        let p = model.sprintProgress
        let onTrack = model.sprintOnTrack
        return miniCard(
            icon: "bolt.fill",
            title: "Sprint",
            sub: model.sprintGoal.title,
            fraction: p.fraction,
            fill: onTrack ? Palette.success : theme.accent,
            badgeIcon: "checkmark.seal.fill",
            badgeValue: model.sprintsWonThisQuarter,
            badgeColor: Palette.success,
            badgeBump: model.sprintsWonThisQuarter,
            highlighted: onTrack
        ) { Haptics.tap(); expanded = .sprint }
    }

    // MARK: Günlük mini — target + görev ilerlemesi + streak rozeti (flame).
    private var dailyMini: some View {
        let c = model.dailyTaskCounts
        let frac = c.total > 0 ? Double(c.done) / Double(c.total) : 0
        let allDone = model.dailyCompleted
        return miniCard(
            icon: "target",
            title: "Günlük",
            sub: allDone ? "Tamamlandı" : "\(c.done)/\(c.total) görev",
            fraction: allDone ? 1 : frac,
            fill: allDone ? Palette.success : theme.accent,
            badgeIcon: "flame.fill",
            badgeValue: model.streak,
            badgeColor: Palette.warning,
            badgeBump: model.streak,
            highlighted: allDone
        ) { Haptics.tap(); expanded = .daily }
    }

    /// Tek mini özet kart — sade, tek dokunuşla detaya açılır.
    private func miniCard(icon: String, title: String, sub: String,
                          fraction: Double, fill: Color,
                          badgeIcon: String, badgeValue: Int, badgeColor: Color,
                          badgeBump: Int, highlighted: Bool,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Space.s2) {
                HStack(spacing: Space.s1) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(fill)
                    Text(title)
                        .font(.appText(12, .heavy))
                        .foregroundStyle(theme.text)
                    Spacer(minLength: 2)
                    miniBadge(badgeIcon, badgeValue, badgeColor, bump: badgeBump)
                }
                Text(sub)
                    .font(.appText(10.5, .medium))
                    .foregroundStyle(theme.subtle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.surfaceHigh)
                        Capsule().fill(fill)
                            .frame(width: max(4, geo.size.width * min(1, max(0, fraction))))
                    }
                }
                .frame(height: 5)
            }
            .padding(Space.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(highlighted ? badgeColor.opacity(0.45) : theme.hairline,
                            lineWidth: highlighted ? 1.4 : 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        }
        .buttonStyle(.pressable)
    }

    /// Köşe rozeti — streak / kazanılan sprint. 0 ise sönük.
    private func miniBadge(_ icon: String, _ value: Int, _ color: Color, bump: Int) -> some View {
        let active = value > 0
        return HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(active ? color : theme.textQuaternary)
                .symbolEffect(.bounce, value: bump)
            Text("\(value)")
                .font(.numberXS)
                .foregroundStyle(active ? color : theme.textQuaternary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 5).padding(.vertical, 2)
        .background(active ? color.opacity(0.14) : theme.surfaceHigh, in: Capsule())
    }
}

/// Hedefler şeridinden açılan tam detay — mevcut SprintCard / DailyGoalCard'ı sayfa içinde gösterir.
/// Mantık aynı; sadece yer kazanmak için detayı katlanabilir bir sayfaya taşıdık.
struct GoalDetailSheet: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let detail: GoalsStrip.Detail
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Space.s3) {
                    switch detail {
                    case .sprint:
                        SprintCard(model: model, theme: theme)
                    case .daily:
                        DailyGoalCard(model: model, theme: theme)
                    }
                }
                .padding(Space.s4)
            }
        }
    }
}
