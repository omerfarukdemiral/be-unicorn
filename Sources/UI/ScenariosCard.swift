import SwiftUI

/// Aktif programlı senaryolar kartı — RoadmapPanel'a embed edilir.
/// Her senaryo için: ikon + ad + geri sayım + canlı ilerleme barı + mevcut/hedef değer.
/// Senaryo yoksa kart gizlenir (boş yer kaplamasın).
struct ScenariosCard: View {
    @ObservedObject var model: GameModel
    var theme: Theme

    var body: some View {
        let active = model.activeScenarios
        if !active.isEmpty {
            PanelCard(theme: theme) {
                VStack(alignment: .leading, spacing: Space.s3) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: Space.s1) {
                            Text("Hedefler").font(.titleM).foregroundStyle(theme.text)
                            Text("Önümüzdeki olaylar — hazırlığını ona göre yap.")
                                .font(.bodyText).foregroundStyle(theme.subtle)
                        }
                        Spacer()
                        Text("\(active.count) aktif").font(.numberXS)
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, Space.s2).padding(.vertical, 3)
                            .background(theme.accent.opacity(0.12), in: Capsule())
                    }
                    VStack(spacing: Space.s2) {
                        ForEach(active.sorted(by: { $0.deadlineMonth < $1.deadlineMonth })) { s in
                            ScenarioRow(model: model, theme: theme, scenario: s)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Tek senaryo satırı

private struct ScenarioRow: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let scenario: ScenarioInstance

    private var kind: ScenarioKind { scenario.scenarioKind }
    private var progress: Double { model.progress(for: scenario) }
    private var current: Double { model.currentMetricValue(for: scenario) }
    private var monthsLeft: Double { model.monthsRemaining(for: scenario) }

    /// Hazır mı (hedef şu an karşılanıyor mu)? Yeşil ipucu.
    private var onTrack: Bool { progress >= 1 }
    /// Yakında deadline + hedef hâlâ uzakta → uyarı tonu.
    private var urgent: Bool { monthsLeft < 0.5 && progress < 1 }
    private var statusColor: Color {
        if onTrack { return Palette.success }
        if urgent { return Palette.danger }
        return theme.accent
    }

    var body: some View {
        VStack(spacing: Space.s2) {
            HStack(spacing: Space.s2) {
                Image(systemName: kind.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .frame(width: 28, height: 28)
                    .background(statusColor.opacity(0.14),
                                in: RoundedRectangle(cornerRadius: Radius.s))
                VStack(alignment: .leading, spacing: 1) {
                    Text(kind.displayName).font(.appText(13, .bold)).foregroundStyle(theme.text)
                        .lineLimit(1)
                    Text(kind.blurb).font(.numberXS).foregroundStyle(theme.subtle)
                        .lineLimit(1).truncationMode(.tail)
                }
                Spacer()
                countdownChip
            }
            // İlerleme barı + sayısal hedef.
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.surfaceHigh)
                        Capsule().fill(statusColor)
                            .frame(width: geo.size.width * CGFloat(progress))
                    }
                }
                .frame(height: 6)
                HStack(spacing: 5) {
                    Text(metricLabel(current, kind: kind))
                        .font(.numberXS).foregroundStyle(statusColor)
                    Text("/ \(metricLabel(scenario.goalTargetValue, kind: kind))")
                        .font(.numberXS).foregroundStyle(theme.subtle)
                    Spacer()
                    Text(onTrack ? "Yolunda" : (urgent ? "Acele!" : "Devam"))
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(statusColor)
                }
            }
        }
        .padding(Space.s2)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.s))
        .overlay(RoundedRectangle(cornerRadius: Radius.s).stroke(theme.hairline))
    }

    /// "2.0 ay" / "12 gün" — uzunsa ay, kısaysa gün (oyun-ayını gerçek-gün simgesine çevir).
    private var countdownChip: some View {
        let m = max(0, monthsLeft)
        let label: String
        if m >= 1 {
            label = String(format: "%.1f ay", m)
        } else {
            // 1 ay = 30 gün varsayımı (anlatısal — gerçek saniyeyle değil)
            let days = Int((m * 30).rounded())
            label = days <= 0 ? "şimdi" : "\(days) gün"
        }
        return HStack(spacing: 3) {
            Image(systemName: "clock.fill").font(.system(size: 9, weight: .bold))
            Text(label).font(.numberXS)
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, Space.s1 + 2).padding(.vertical, 3)
        .background(statusColor.opacity(0.14), in: Capsule())
    }

    /// Metrik türüne göre okunabilir biçim ("$12.5K", "62 puan", "1.2K kullanıcı").
    private func metricLabel(_ value: Double, kind: ScenarioKind) -> String {
        switch kind.metric {
        case .valuation, .mrr:    return BigNumber.money(value)
        case .users:              return "\(BigNumber.format(value)) kullanıcı"
        case .reputation:         return "\(Int(value)) itibar"
        case .morale:             return "\(Int(value)) moral"
        case .liveProjects:       return "\(Int(value)) yayında"
        }
    }
}
