import SwiftUI

/// Track C — ekran-içi Aktivite Akışı. Modal yerine olaylar burada kalıcı birikir.
/// Premium-sakin: sade satır kartlar, kind-tint, relatif zaman, opsiyonel detay köprüsü.
///
/// UX: İç scroll YOK — akış, ofis sayfasının dış ScrollView'i içinde aşağıya doğru uzar.
/// Her satır tıklanınca AYNI satırın içeriğini gösteren tek tip detay-sheet açılır
/// (eskiden bir kısmı derse, bir kısmı sheet'e, bir kısmı hiçbir yere gidiyordu → tutarsızdı).
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
                // İç scroll'suz: satırlar doğrudan dikilir, sayfanın kendi scroll'u kaydırır.
                LazyVStack(spacing: Space.s2) {
                    ForEach(model.feedEntries) { row($0) }
                }
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
        // Tüm satırlar artık tek tip: tıkla → o satırın detay-sheet'i. Affordance tutarlı.
        return Button {
            Haptics.selection()
            detailEntry = e
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
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.textQuaternary)
            }
            .padding(Space.s2 + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.pressable)
    }

    private func relativeTime(_ atMonth: Double) -> String {
        let d = max(0, model.companyMonths - atMonth)
        if d < 0.25 { return "şu an" }
        if d < 1 { return "az önce" }
        return "\(Int(d)) ay önce"
    }
}

/// Feed satırından açılan detay. HER ZAMAN tıklanan girdinin kendi başlık+özetini gösterir
/// (tıkladığın ile açılan eşleşir). Çeyrek/sezon zengin dökümü YALNIZCA bu girdi türünün
/// feed'deki en yenisiyse eklenir — cache yalnız son turu tuttuğu için eski satırlarda
/// yanlış (güncel) veri göstermek yerine girdinin kendi özetinde kalırız.
private struct FeedDetailSheet: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let entry: FeedEntry
    @Environment(\.dismiss) private var dismiss

    /// Bu girdi, kendi detay-türünün feed'deki en yeni örneği mi? (cache eşleşmesi)
    private var matchesLiveCache: Bool {
        guard let raw = entry.detailKindRaw else { return false }
        return model.feedEntries.first(where: { $0.detailKindRaw == raw })?.id == entry.id
    }

    private var relatedLesson: LessonEntry? {
        guard let m = entry.mechanic else { return nil }
        return LessonsContent.lesson(for: m)
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s4) {
                    headerBlock

                    // Tıklanan girdinin kendi özeti — her zaman görünür, açılan = tıklanan.
                    Text(entry.summary).font(.bodyText).foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Zengin döküm yalnızca cache bu girdiyle eşleşiyorsa.
                    if entry.detailKindRaw == FeedDetailKind.quarter.rawValue,
                       matchesLiveCache, let r = model.lastCycleReview {
                        Divider().overlay(theme.hairline)
                        quarterDetail(r)
                    } else if entry.detailKindRaw == FeedDetailKind.season.rawValue,
                              matchesLiveCache, let f = model.lastSeasonFinale {
                        Divider().overlay(theme.hairline)
                        seasonDetail(f)
                    }

                    // #8 Yansıma — karar sonrası "bu seçim neyi önceliklendirdi?" (suçlamasız).
                    if let reflection = entry.reflection {
                        reflectionBlock(reflection)
                    }

                    // Ders köprüsü — varsa net bir buton (#19), önce sheet kapanır.
                    if let lesson = relatedLesson, let mech = entry.mechanic {
                        lessonBridge(lesson.title, mech)
                    }
                }
                .padding(Space.s5)
            }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            HStack(spacing: Space.s2) {
                Image(systemName: entry.kind.icon)
                    .font(.system(size: 18, weight: .bold)).foregroundStyle(theme.accent)
                Text(entry.title).font(.titleM).foregroundStyle(theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            HStack(spacing: Space.s2) {
                Text(entry.kind.label.uppercased())
                    .font(.eyebrow).kerning(0.6)
                    .foregroundStyle(theme.subtle)
                    .padding(.horizontal, Space.s2).padding(.vertical, 2)
                    .background(theme.surfaceHigh, in: Capsule())
                Text(relativeTime(entry.atMonth))
                    .font(.appText(11, .medium)).foregroundStyle(theme.textQuaternary)
            }
        }
    }

    /// #8 Yansıma kartı — kararın hangi dengeyi önceliklendirdiğini betimler (yargı yok).
    private func reflectionBlock(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            HStack(spacing: Space.s1 + 2) {
                Image(systemName: "scope")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.gold)
                Text("YANSIMA").font(.eyebrow).kerning(0.8).foregroundStyle(theme.subtle)
            }
            Text(text).font(.appText(13, .medium)).foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(Palette.gold.opacity(0.25), lineWidth: 1))
        .padding(.top, Space.s2)
    }

    private func lessonBridge(_ title: String, _ mechanic: String) -> some View {
        Button {
            Haptics.selection()
            dismiss()
            model.inspectedMechanic = mechanic   // root LessonPopupView gösterir
        } label: {
            HStack(spacing: Space.s2) {
                Image(systemName: "book.fill")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("İlgili Ders").font(.eyebrow).foregroundStyle(theme.subtle)
                    Text(title).font(.appText(13, .semibold)).foregroundStyle(theme.text)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(theme.subtle)
            }
            .padding(Space.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(theme.accent.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .padding(.top, Space.s2)
    }

    private func relativeTime(_ atMonth: Double) -> String {
        let d = max(0, model.companyMonths - atMonth)
        if d < 0.25 { return "şu an" }
        if d < 1 { return "az önce" }
        return "\(Int(d)) ay önce"
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
