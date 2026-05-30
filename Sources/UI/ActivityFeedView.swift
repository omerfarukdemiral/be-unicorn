import SwiftUI

/// Track C — ekran-içi Aktivite Akışı. Modal yerine olaylar burada kalıcı birikir.
/// Premium-sakin: sade satır kartlar, kind-tint, relatif zaman, opsiyonel detay köprüsü.
struct ActivityFeedView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    @State private var detailEntry: FeedEntry? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            header
            if model.feedEntries.isEmpty {
                Text("Şirket nefes alıyor. Olaylar burada akacak.")
                    .font(.labelText).foregroundStyle(theme.subtle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Space.s2)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: Space.s2) {
                        ForEach(model.feedEntries) { row($0) }
                    }
                }
                .frame(maxHeight: 168)   // ~3-4 satır görünür, içinde kayar
            }
        }
        .onAppear { model.markFeedRead() }
        .animation(Motion.smooth, value: model.feedEntries.count)
        .sheet(item: $detailEntry) { e in
            FeedDetailSheet(model: model, theme: theme, entry: e)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(spacing: Space.s2) {
            Image(systemName: "dot.radiowaves.up.forward")
                .font(.system(size: 12, weight: .bold)).foregroundStyle(theme.accent)
            Text("Akış").font(.appText(13, .heavy)).foregroundStyle(theme.text)
            Spacer(minLength: 0)
            if !model.feedEntries.isEmpty {
                Text("\(model.feedEntries.count)").font(.numberXS).foregroundStyle(theme.subtle)
            }
        }
    }

    private func row(_ e: FeedEntry) -> some View {
        let tint = e.positive ? Palette.success : Palette.warning
        let hasDetail = e.detailKindRaw != nil || e.mechanic != nil
        return Button {
            guard hasDetail else { return }
            Haptics.selection()
            if let m = e.mechanic { model.inspectedMechanic = m }   // #19 ders köprüsü KORUNUR
            else { detailEntry = e }                                // çeyrek/sezon zengin detay
        } label: {
            HStack(spacing: Space.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7).fill(tint.opacity(0.16))
                        .frame(width: 30, height: 30)
                    Image(systemName: e.kind.icon)
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: Space.s1) {
                        Text(e.title).font(.appText(12.5, .bold)).foregroundStyle(theme.text).lineLimit(1)
                        Spacer(minLength: Space.s1)
                        Text(relativeTime(e.atMonth)).font(.appText(10, .medium))
                            .foregroundStyle(theme.textQuaternary)
                    }
                    Text(e.summary).font(.appText(11.5, .medium)).foregroundStyle(theme.subtle)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                if hasDetail {
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.textQuaternary)
                }
            }
            .padding(Space.s2 + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .allowsHitTesting(hasDetail)
    }

    private func relativeTime(_ atMonth: Double) -> String {
        let d = max(0, model.companyMonths - atMonth)
        if d < 0.25 { return "şu an" }
        if d < 1 { return "az önce" }
        return "\(Int(d)) ay önce"
    }
}

/// Feed satırından açılan salt-okunur zengin detay (çeyrek scorecard / sezon özeti).
/// Cache'ten okur — aksiyon butonu YOK (çift-ilerleme riski olmadan).
private struct FeedDetailSheet: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let entry: FeedEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s4) {
                    HStack {
                        Image(systemName: entry.kind.icon)
                            .font(.system(size: 18, weight: .bold)).foregroundStyle(theme.accent)
                        Text(entry.title).font(.titleM).foregroundStyle(theme.text)
                        Spacer()
                    }
                    if entry.detailKindRaw == FeedDetailKind.quarter.rawValue, let r = model.lastCycleReview {
                        quarterDetail(r)
                    } else if entry.detailKindRaw == FeedDetailKind.season.rawValue, let f = model.lastSeasonFinale {
                        seasonDetail(f)
                    } else {
                        Text(entry.summary).font(.bodyText).foregroundStyle(theme.textSecondary)
                    }
                }
                .padding(Space.s5)
            }
        }
    }

    @ViewBuilder private func quarterDetail(_ r: CycleReview) -> some View {
        let b = r.breakdown
        statRow("Skor", "\(Int(b.score))", Palette.gold)
        statRow("Sıra", "\(r.playerRank) / \(r.standings.count)", theme.accent)
        statRow("Lig", r.movement == .promote ? "Terfi ↑" : (r.movement == .demote ? "Düşüş ↓" : "Korundu"),
                r.movement == .demote ? Palette.warning : Palette.success)
        Text("Kohort Sıralaması").font(.appText(12, .heavy)).foregroundStyle(theme.subtle).padding(.top, Space.s2)
        ForEach(Array(r.standings.prefix(9).enumerated()), id: \.offset) { i, s in
            HStack {
                Text("\(i + 1)").font(.numberS).foregroundStyle(theme.subtle).frame(width: 20)
                Text(s.name).font(.appText(12.5, s.isPlayer ? .heavy : .medium))
                    .foregroundStyle(s.isPlayer ? theme.accent : theme.text)
                Spacer()
                Text("\(Int(s.score))").font(.numberS).foregroundStyle(theme.textSecondary)
            }
            .padding(.vertical, 3)
        }
    }

    @ViewBuilder private func seasonDetail(_ f: SeasonFinale) -> some View {
        statRow("Ünvan", f.title.name, Palette.gold)
        statRow("Kalıcı üretim", "+%\(Int(f.totalBonusAfter * 100))", Palette.success)
        statRow("Terfi", "\(f.summary.promotions)", theme.accent)
        statRow("Kazanılan sprint", "\(f.summary.sprintsWon)", theme.accent)
        statRow("Günlük hedef", "\(f.summary.dailyGoals)", theme.accent)
    }

    private func statRow(_ label: String, _ value: String, _ tint: Color) -> some View {
        HStack {
            Text(label).font(.bodyText).foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value).font(.numberM).foregroundStyle(tint)
        }
        .padding(.vertical, 4)
    }
}
