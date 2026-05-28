import SwiftUI

/// Kurucu Defteri — oyun mekanikleriyle eşleşen kısa startup ilkeleri arşivi.
/// Sade overlay sheet: başlık + kategori chip'leri (yatay scroll) + kart listesi.
/// Kart tap → açılır gövde. Stil PanelCard / CycleReviewView diline akrabadır.
struct LessonsPanel: View {
    var theme: Theme
    var onClose: () -> Void

    @State private var selectedCategory: LessonCategory? = nil
    @State private var expandedID: String? = nil
    @State private var appeared = false

    /// Filtre + tüm girdiler havuzu.
    private var entries: [LessonEntry] {
        LessonsContent.filtered(by: selectedCategory)
    }

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
                            expanded: expandedID == entry.id
                        ) {
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

/// Tek ders kartı — ikon + başlık + ilk satır önizleme. Tap → tam gövde açılır.
private struct LessonCard: View {
    var theme: Theme
    let entry: LessonEntry
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
                    Image(systemName: entry.category.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(theme.accent)
                        .frame(width: 30, height: 30)
                        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.s))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.category.title.uppercased())
                            .font(.caption).kerning(0.8)
                            .foregroundStyle(theme.subtle)
                        Text(entry.title)
                            .font(.appText(15, .bold))
                            .foregroundStyle(theme.text)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.subtle)
                        .padding(.top, 4)
                }

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
            }
            .padding(Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(expanded ? theme.hairlineStrong : theme.hairline,
                            lineWidth: expanded ? 1.5 : 1)
            )
        }
        .buttonStyle(.pressable)
    }
}
