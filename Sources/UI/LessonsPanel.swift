import SwiftUI

/// Kurucu Defteri — oyun mekanikleriyle eşleşen kısa startup ilkeleri arşivi.
/// Sade overlay sheet: başlık + kategori chip'leri (yatay scroll) + kart listesi.
/// Kart tap → açılır gövde. Stil PanelCard / CycleReviewView diline akrabadır.
struct LessonsPanel: View {
    var theme: Theme
    /// Açılmış (deneyimlenmiş) ders id'leri — kilitli/açık ayrımı için.
    var unlocked: Set<String>
    /// Bu oturumda yeni açılan dersler — "YENİ" rozeti için (kapanışta temizlenir).
    var newIds: Set<String>
    var onClose: () -> Void

    @State private var selectedCategory: LessonCategory? = nil
    @State private var expandedID: String? = nil
    @State private var appeared = false

    /// Filtre + tüm girdiler havuzu. Açılanlar üstte (koleksiyon hissi), kilitliler altta.
    private var entries: [LessonEntry] {
        LessonsContent.filtered(by: selectedCategory).sorted { a, b in
            let ua = unlocked.contains(a.id), ub = unlocked.contains(b.id)
            if ua != ub { return ua && !ub }   // açık olanlar önce
            return false                        // aksi halde tanım sırası korunur
        }
    }

    private var unlockedCount: Int { LessonsContent.all.filter { unlocked.contains($0.id) }.count }
    private var totalCount: Int { LessonsContent.all.count }

    var body: some View {
        ZStack {
            // Karartılmış zemin — dışına tap ile kapanır.
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                header
                categoryChips
                Divider()
                    .overlay(theme.hairline)
                    .padding(.horizontal, Space.s4)
                lessonsList
            }
            .frame(maxWidth: 420)
            .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.overlay))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.overlay)
                    .stroke(theme.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
            .padding(.horizontal, Space.s4)
            .padding(.vertical, Space.s5)
            .scaleEffect(appeared ? 1 : 0.92)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            Haptics.rigid()
            withAnimation(Motion.snappy) { appeared = true }
        }
    }

    private func dismiss() {
        Haptics.tap()
        withAnimation(Motion.quick) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { onClose() }
    }

    // MARK: - Başlık

    private var header: some View {
        HStack(alignment: .top, spacing: Space.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text("KURUCU DEFTERİ")
                    .font(.caption).kerning(0.8)
                    .foregroundStyle(theme.subtle)
                Text("Edinilen Bilgelik")
                    .font(.titleM)
                    .foregroundStyle(theme.text)
                Text("\(unlockedCount)/\(totalCount) ders deneyimlendi")
                    .font(.appText(12, .semibold))
                    .foregroundStyle(theme.accent)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.text)
                    .frame(width: 32, height: 32)
                    .background(theme.surfaceHigh, in: Circle())
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, Space.s5)
        .padding(.top, Space.s5)
        .padding(.bottom, Space.s3)
    }

    // MARK: - Kategori chip'leri (yatay scroll)

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s2) {
                chip(label: "Hepsi", icon: "books.vertical.fill",
                     selected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(LessonCategory.allCases, id: \.self) { cat in
                    chip(label: cat.title, icon: cat.icon,
                         selected: selectedCategory == cat) {
                        selectedCategory = cat
                    }
                }
            }
            .padding(.horizontal, Space.s5)
            .padding(.bottom, Space.s3)
        }
    }

    private func chip(label: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            withAnimation(Motion.smooth) { action() }
        } label: {
            HStack(spacing: Space.s1) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label).font(.appText(12, .bold))
            }
            .foregroundStyle(selected ? .white : theme.text)
            .padding(.horizontal, Space.s3)
            .padding(.vertical, Space.s2)
            .background(
                selected ? theme.accent : theme.surfaceHigh,
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(selected ? theme.accent.opacity(0.9) : theme.hairline,
                                 lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Ders listesi

    private var lessonsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: Space.s3) {
                if entries.isEmpty {
                    Text("Bu kategoride henüz ders yok.")
                        .font(.bodyText)
                        .foregroundStyle(theme.subtle)
                        .padding(.vertical, Space.s5)
                } else {
                    ForEach(entries) { entry in
                        LessonCard(
                            theme: theme,
                            entry: entry,
                            isUnlocked: unlocked.contains(entry.id),
                            isNew: newIds.contains(entry.id),
                            hint: LessonsContent.unlockHint[entry.id],
                            expanded: expandedID == entry.id
                        ) {
                            guard unlocked.contains(entry.id) else { Haptics.tap(); return }
                            Haptics.tap()
                            withAnimation(Motion.smooth) {
                                expandedID = (expandedID == entry.id) ? nil : entry.id
                            }
                        }
                    }
                }
                Spacer(minLength: Space.s4)
            }
            .padding(.horizontal, Space.s4)
            .padding(.top, Space.s3)
            .padding(.bottom, Space.s5)
        }
    }
}

/// Tek ders kartı. AÇIK ders: ikon + başlık + önizleme, tap → tam gövde.
/// KİLİTLİ ders ("önce hata, sonra ders"): başlık gizli (???) + "Açmak için: <ipucu>".
private struct LessonCard: View {
    var theme: Theme
    let entry: LessonEntry
    let isUnlocked: Bool
    let isNew: Bool
    let hint: String?
    let expanded: Bool
    let onTap: () -> Void

    /// Önizleme: gövdenin ilk cümlesi (ya da ilk ~110 karakter).
    private var preview: String {
        if let firstStop = entry.body.firstIndex(of: ".") {
            return String(entry.body[..<firstStop]) + "."
        }
        return String(entry.body.prefix(110))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Space.s2) {
                HStack(alignment: .top, spacing: Space.s3) {
                    Image(systemName: isUnlocked ? entry.category.icon : "lock.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isUnlocked ? theme.accent : theme.subtle)
                        .frame(width: 30, height: 30)
                        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.s))

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: Space.s2) {
                            Text(entry.category.title.uppercased())
                                .font(.caption).kerning(0.8)
                                .foregroundStyle(theme.subtle)
                            if isNew {
                                Text("YENİ")
                                    .font(.appText(9, .bold)).kerning(0.5)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(theme.accent, in: Capsule())
                            }
                        }
                        Text(isUnlocked ? entry.title : "???")
                            .font(.appText(15, .bold))
                            .foregroundStyle(isUnlocked ? theme.text : theme.subtle)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)

                    if isUnlocked {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(theme.subtle)
                            .padding(.top, 4)
                    }
                }

                if isUnlocked {
                    if expanded {
                        Text(entry.body)
                            .font(.bodyText)
                            .foregroundStyle(theme.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(preview)
                            .font(.bodyText)
                            .foregroundStyle(theme.subtle)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                } else if let hint {
                    // Kilitli: hangi hatayla açılacağını göster (öğretici yönlendirme).
                    HStack(spacing: Space.s1) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Açmak için: \(hint)")
                            .font(.appText(12, .semibold))
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(theme.subtle)
                }
            }
            .padding(Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
            .opacity(isUnlocked ? 1 : 0.7)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(expanded ? theme.hairlineStrong : theme.hairline,
                            lineWidth: expanded ? 1.5 : 1)
            )
        }
        .buttonStyle(.pressable)
    }
}
