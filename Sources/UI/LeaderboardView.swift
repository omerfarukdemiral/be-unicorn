import SwiftUI

/// Canlı leaderboard (rakip kohort + gerçek bahis). Oyuncu + 8 simüle rakip startup
/// çeyrek skoruna göre sıralı; oyuncu vurgulu, terfi (yeşil) ve düşüş (kırmızı) bölgeleri
/// renklendirilir. Skorlar çeyrek boyunca oyun temposuyla ilerler → "canlı" hisset.
/// RoadmapPanel'de bölüm olarak gösterilir + lig rozetine tıkla sheet'te açılır.
struct LeaderboardCard: View {
    @ObservedObject var model: GameModel
    var theme: Theme

    private var league: LeagueDef { model.currentLeague }
    private var standings: [StandingEntry] { model.liveStandings }

    var body: some View {
        PanelCard(theme: theme) {
            VStack(alignment: .leading, spacing: Space.s3) {
                header
                LeaderboardList(model: model, theme: theme,
                                standings: standings,
                                promoteCutoff: model.promoteCutoff,
                                demoteCutoff: model.demoteCutoff,
                                total: model.cohortTotal)
                legend
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Başlık — kohort + lig + çeyrek ilerleme.
    private var header: some View {
        HStack(spacing: Space.s2) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.gold)
            VStack(alignment: .leading, spacing: 1) {
                Text("Canlı Sıralama")
                    .font(.titleM)
                    .foregroundStyle(theme.text)
                Text("\(league.name) · Çeyrek \(model.quarterNumber)")
                    .font(.labelText)
                    .foregroundStyle(theme.subtle)
            }
            Spacer()
            // Çeyrek ilerleme halkası (skorlar olgunlaşıyor sinyali).
            ZStack {
                Circle().stroke(theme.accent.opacity(0.22), lineWidth: 3)
                    .frame(width: 30, height: 30)
                Circle().trim(from: 0, to: model.quarterProgress)
                    .stroke(theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(model.quarterProgress * 100))")
                    .font(.appNumber(10, .bold))
                    .foregroundStyle(theme.subtle)
            }
        }
    }

    // MARK: Açıklama — terfi/düşüş bölge renkleri (gerçek bahis kuralı).
    private var legend: some View {
        HStack(spacing: Space.s3) {
            if model.promoteCutoff > 0 {
                legendDot(Palette.success, "İlk \(model.promoteCutoff) terfi")
            }
            if model.demoteCutoff > 0 {
                legendDot(Palette.danger, "Son \(model.demoteCutoff) düşer")
            }
            Spacer()
        }
        .padding(.top, Space.s1)
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: Space.s1) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.caption).foregroundStyle(theme.subtle)
        }
    }
}

/// Sıralanmış standings satır listesi — oyuncu + rakipler. CycleReview ve canlı kart paylaşır.
struct LeaderboardList: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let standings: [StandingEntry]
    let promoteCutoff: Int   // ilk N (terfi) — 0 ise terfi yok
    let demoteCutoff: Int    // son N (düşüş) — 0 ise düşüş yok
    let total: Int

    var body: some View {
        VStack(spacing: Space.s1) {
            ForEach(standings) { entry in
                LeaderboardRow(theme: theme, entry: entry, zone: zone(for: entry.rank))
            }
        }
    }

    /// Bir sıranın bölgesi: terfi (üst N) / düşüş (alt N) / nötr.
    private func zone(for rank: Int) -> LeaderboardZone {
        if promoteCutoff > 0 && rank <= promoteCutoff { return .promote }
        if demoteCutoff > 0 && rank > total - demoteCutoff { return .demote }
        return .neutral
    }
}

enum LeaderboardZone { case promote, demote, neutral }

/// Tek leaderboard satırı: sıra + isim + skor barı. Oyuncu vurgulu, bölge renkli.
struct LeaderboardRow: View {
    var theme: Theme
    let entry: StandingEntry
    let zone: LeaderboardZone

    private var zoneColor: Color {
        switch zone {
        case .promote: return Palette.success
        case .demote:  return Palette.danger
        case .neutral: return theme.subtle
        }
    }

    private var bg: Color {
        entry.isPlayer ? theme.accent.opacity(0.16) : theme.surfaceHigh
    }

    var body: some View {
        HStack(spacing: Space.s2) {
            // Sıra numarası — bölge renginde.
            Text("\(entry.rank)")
                .font(.appNumber(13, .black))
                .foregroundStyle(zoneColor)
                .frame(width: 22, alignment: .center)

            // Bölge işareti (terfi yukarı ok / düşüş aşağı ok / nötr nokta).
            Image(systemName: zoneIcon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(zoneColor)
                .frame(width: 14)

            // İsim + alt-satır (rakipler için sektör · kurucu · proje).
            // Oyuncu satırında subtitle yok — kendi şirketinin bilgisi başka yerlerde görünür.
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name)
                    .font(.appText(13, entry.isPlayer ? .bold : .medium))
                    .foregroundStyle(entry.isPlayer ? theme.accent : theme.text)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if let subtitle = entry.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(
                            entry.sectorColorHex.map { Color(hex: $0).opacity(0.85) }
                                ?? theme.subtle
                        )
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }

            Spacer(minLength: Space.s2)

            // Skor — küçük bar + sayı.
            HStack(spacing: Space.s2) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.surfaceHigh)
                        Capsule()
                            .fill(entry.isPlayer ? theme.accent : zoneColor.opacity(0.7))
                            .frame(width: max(3, geo.size.width * min(1, entry.score / 100)))
                    }
                }
                .frame(width: 54, height: 5)
                Text("\(Int(entry.score.rounded()))")
                    .font(.numberXS)
                    .foregroundStyle(entry.isPlayer ? theme.accent : theme.subtle)
                    .frame(width: 22, alignment: .trailing)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, Space.s2).padding(.vertical, Space.s2)
        .background(bg, in: RoundedRectangle(cornerRadius: Radius.s))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.s)
                .stroke(entry.isPlayer ? theme.accent.opacity(0.45) : .clear, lineWidth: 1)
        )
    }

    private var zoneIcon: String {
        switch zone {
        case .promote: return "arrow.up"
        case .demote:  return "arrow.down"
        case .neutral: return "minus"
        }
    }
}

/// Lig rozetine tıklayınca açılan canlı leaderboard sheet'i.
struct LeaderboardSheet: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Space.s3) {
                    LeaderboardCard(model: model, theme: theme)
                    Button { Haptics.tap(); dismiss() } label: {
                        Text("Kapat").font(.bodyL)
                            .modifier(AppButton.secondary(theme))
                    }
                    .buttonStyle(.pressable)
                }
                .padding(Space.s4)
            }
        }
    }
}
