import SwiftUI

/// Kurucu Karnesi (B2) — oyunun nihai içgörü teslimatı.
///
/// Üç bölüm:
///   1) "En Pahalı 3 Ders" — bu oyunda en çok dokunulan mekaniklerin (model.topTouchedMechanics)
///      Defter dersleri. Dokununca inspectedMechanic köprüsüyle LessonPopupView açılır (#19).
///   2) Strateji Kimliği — FounderScorecardData.identity(for:) ile GameState'ten türetilen
///      suçlamasız bir eğilim çerçevesi ("tek doğru cevap yok").
///   3) Refleks Kartı — FounderReflexCard'ın 9 öz-sorgu sorusu; bu oyunda en çok sınandıkların vurgulu.
///
/// Paylaşım: ShareLink ile VARSAYILAN ÖZEL. Yalnızca içgörü paylaşılır —
/// skor, değerleme, iflas sayısı ASLA paylaşılmaz (PLAN B3 ilkesi: "statü değil içgörü").
///
/// Boş veri (henüz yeterli karar yok) → nazik fallback; çökme yok.
struct FounderScorecardView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    /// Karneyi kapatıp altındaki ekrana (Win / Sezon Finali) dönmek için.
    let onClose: () -> Void
    @State private var appeared = false

    // MARK: Türetilmiş veri

    /// En çok dokunulan mekanikler (top 3) → Defter dersleri. Eşleşmeyenler atılır.
    private var topLessons: [(mechanic: String, lesson: LessonEntry)] {
        model.topTouchedMechanics.compactMap { mech in
            LessonsContent.lesson(for: mech).map { (mech, $0) }
        }
    }

    private var identity: FounderIdentity {
        FounderIdentity.derive(from: model.state)
    }

    /// Vurgulanacak mekanikler kümesi — bu oyunda en çok sınandıkların.
    private var highlighted: Set<String> { Set(model.topTouchedMechanics) }

    /// Paylaşılabilir düz metin: yalnızca dersler + kimlik. Skor/iflas YOK.
    private var shareText: String {
        let titles = topLessons.map { $0.lesson.title }
        if titles.isEmpty {
            return "Unicorn — Garajdan Zirveye'de bir kurucu olarak oynadım. Strateji kimliğim: \(identity.title)."
        }
        var lines = "Unicorn'da bu oyunda öğrendiğim en pahalı dersler:"
        for (i, t) in titles.enumerated() {
            lines += "\n\(i + 1)) \(t)"
        }
        lines += "\nStrateji kimliğim: \(identity.title). — Garajdan Zirveye"
        return lines
    }

    private var hasData: Bool { !topLessons.isEmpty }

    // MARK: Gövde

    var body: some View {
        ZStack {
            // Win/Finale dilinde derin gece zemin + unicorn parıltısı.
            Color(hex: "12101F").opacity(0.96).ignoresSafeArea()
            RadialGradient(colors: [Palette.unicorn.opacity(0.16), .clear],
                           center: .top, startRadius: 20, endRadius: 460)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Space.s4) {
                    header
                    if hasData {
                        topLessonsCard
                    } else {
                        emptyCard
                    }
                    identityCard
                    reflexCard
                    privacyNote
                    shareButton
                    closeButton
                }
                .padding(Space.s5)
                .frame(maxWidth: 380)
                .padding(.horizontal, Space.s4)
                .padding(.vertical, Space.s5)
                .scaleEffect(appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            Haptics.success()
            withAnimation(Motion.bouncy) { appeared = true }
        }
    }

    // MARK: Başlık

    private var header: some View {
        VStack(spacing: Space.s2) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Palette.unicorn)
            Text("KURUCU KARNESİ")
                .font(.eyebrow).tracking(1.6)
                .foregroundStyle(Palette.gold)
                .padding(.horizontal, Space.s3).padding(.vertical, Space.s1)
                .background(Palette.gold.opacity(0.13), in: Capsule())
            Text(model.companyName)
                .font(.titleL)
                .foregroundStyle(theme.text)
                .multilineTextAlignment(.center)
            Text("Bu oyunda nasıl bir kurucu oldun? Not değil, ayna — kendi yolunu görmen için.")
                .font(.bodyText)
                .foregroundStyle(theme.subtle)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: En Pahalı 3 Ders

    private var topLessonsCard: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            sectionLabel("EN PAHALI \(topLessons.count) DERS", icon: "flame.fill", tint: Palette.gold)
            Text("Bu oyunda kararlarınla en çok burada yüzleştin. Dokun, dersi tekrar oku.")
                .font(.labelText)
                .foregroundStyle(theme.subtle)
            ForEach(Array(topLessons.enumerated()), id: \.element.mechanic) { idx, item in
                lessonRow(rank: idx + 1, mechanic: item.mechanic, lesson: item.lesson)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s4)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(Palette.gold.opacity(0.22), lineWidth: 1))
    }

    private func lessonRow(rank: Int, mechanic: String, lesson: LessonEntry) -> some View {
        Button {
            Haptics.selection()
            model.inspectedMechanic = mechanic   // #19 köprü → LessonPopupView
        } label: {
            HStack(spacing: Space.s3) {
                Text("\(rank)")
                    .font(.numberM)
                    .foregroundStyle(Palette.gold)
                    .frame(width: 22, height: 22)
                    .background(Palette.gold.opacity(0.14), in: Circle())
                Image(systemName: lesson.category.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(lesson.title)
                        .font(.appText(13, .bold))
                        .foregroundStyle(theme.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(lesson.category.title.uppercased())
                        .font(.appText(9, .heavy)).kerning(0.6)
                        .foregroundStyle(theme.subtle)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.subtle)
            }
            .padding(Space.s3)
            .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.s))
            .overlay(RoundedRectangle(cornerRadius: Radius.s).stroke(theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.pressable)
    }

    // MARK: Boş veri fallback

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            sectionLabel("EN PAHALI DERSLER", icon: "flame.fill", tint: Palette.gold)
            Text("Henüz yeterli karar vermedin. Birkaç karar daha ver — en çok hangi konularda sınandığın burada birikecek.")
                .font(.bodyText)
                .foregroundStyle(theme.subtle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s4)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(theme.hairline, lineWidth: 1))
    }

    // MARK: Strateji Kimliği

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            sectionLabel("STRATEJİ KİMLİĞİN", icon: "person.crop.circle.badge.checkmark", tint: theme.accent)
            Text(identity.title)
                .font(.appText(20, .black))
                .foregroundStyle(theme.accent)
            Text(identity.blurb)
                .font(.bodyText)
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("Bu senin bu oyundaki eğilimin — sonraki denemende bambaşka bir kurucu olabilirsin.")
                .font(.labelText)
                .foregroundStyle(theme.subtle)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.s1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s4)
        .background(theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(theme.accent.opacity(0.28), lineWidth: 1))
    }

    // MARK: Refleks Kartı (9 soru)

    private var reflexCard: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            sectionLabel("REFLEKS KARTI", icon: "brain.head.profile", tint: Palette.success)
            Text(FounderReflexCard.intro)
                .font(.bodyText)
                .foregroundStyle(theme.subtle)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(FounderReflexCard.questions.enumerated()), id: \.offset) { idx, item in
                reflexRow(index: idx + 1, mechanic: item.mechanic, question: item.q,
                          isHighlighted: highlighted.contains(item.mechanic))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s4)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(theme.hairline, lineWidth: 1))
    }

    private func reflexRow(index: Int, mechanic: String, question: String, isHighlighted: Bool) -> some View {
        let accent = isHighlighted ? Palette.success : theme.subtle
        return VStack(alignment: .leading, spacing: Space.s1) {
            HStack(alignment: .top, spacing: Space.s2) {
                Text("\(index)")
                    .font(.numberS)
                    .foregroundStyle(accent)
                    .frame(width: 18, height: 18)
                    .background(accent.opacity(0.14), in: Circle())
                Text(question)
                    .font(.appText(12.5, isHighlighted ? .semibold : .medium))
                    .foregroundStyle(isHighlighted ? theme.text : theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if isHighlighted {
                Text(FounderReflexCard.highlightBadge)
                    .font(.appText(8.5, .heavy)).kerning(0.6)
                    .foregroundStyle(Palette.success)
                    .padding(.horizontal, Space.s2).padding(.vertical, 2)
                    .background(Palette.success.opacity(0.14), in: Capsule())
                    .padding(.leading, 26)
            }
        }
        .padding(.vertical, Space.s1)
    }

    // MARK: Gizlilik + Paylaşım + Kapat

    private var privacyNote: some View {
        HStack(spacing: Space.s2) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.subtle)
            Text("Bu karne yalnızca sende kalır. İstersen içgörünü paylaş — sayıların değil, öğrendiğin paylaşılır.")
                .font(.labelText)
                .foregroundStyle(theme.subtle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s3)
        .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.s))
    }

    private var shareButton: some View {
        ShareLink(item: shareText) {
            HStack(spacing: Space.s2) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                Text("İçgörümü Paylaş").font(.bodyL)
            }
            .frame(maxWidth: .infinity).padding(.vertical, Space.s3)
            .foregroundStyle(theme.accent)
            .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(theme.accent.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
    }

    private var closeButton: some View {
        Button { Haptics.tap(); onClose() } label: {
            Text("Kapat").font(.bodyL)
                .modifier(ButtonChrome(bg: Palette.unicorn, fg: .white,
                                       glow: Palette.unicorn, height: AppButton.height))
        }
        .buttonStyle(.pressable)
    }

    // MARK: Ortak bölüm etiketi

    private func sectionLabel(_ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: Space.s2) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
            Text(text)
                .font(.caption).kerning(0.8)
                .foregroundStyle(tint)
        }
    }
}
