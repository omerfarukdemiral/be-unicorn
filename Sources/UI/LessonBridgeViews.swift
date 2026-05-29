import SwiftUI

// MARK: - Karar sonucu modeli (#26)

/// Bir kararın kalıcı sonuç kartı için veri. Eskiden `resultLine` 3.5sn toast'ta
/// uçuyordu; artık kapatılabilir bir kartta durur ve ilgili Defter dersine köprü taşır.
struct DecisionResult: Identifiable, Equatable {
    let id = UUID()
    let text: String          // seçimin sonucu (en zengin eğitici içerik)
    let speaker: String       // kararı veren bağlam (kart konuşmacısı)
    let categoryRaw: String   // DecisionCategory.rawValue (tint için)
    let mechanic: String?     // ilgili Defter dersi mekaniği (#19 köprüsü) — yoksa köprü gösterilmez
}

// MARK: - Sonuç kartı (#26) — kalıcı, ders köprülü

/// Karardan sonra gösterilen kalıcı sonuç kartı. "Devam" ile kapanır; sonucun
/// altında ilgili Defter dersi varsa "Bununla ilgili ders" köprüsü açılır (#19).
struct ResultCardView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let result: DecisionResult
    @State private var appeared = false

    private var tint: Color {
        switch result.categoryRaw {
        case "crisis":      return Palette.danger
        case "opportunity": return Palette.success
        case "press":       return Palette.warning
        case "investor":    return theme.accent
        default:            return Color(hex: DecisionCategory(rawValue: result.categoryRaw)?.tint ?? "5B8DEF")
        }
    }

    private var relatedLesson: LessonEntry? {
        guard let m = result.mechanic else { return nil }
        return LessonsContent.lesson(for: m)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { dismiss() }
            VStack {
                Spacer()
                card
                    .padding(.horizontal, Space.s4)
                    .scaleEffect(appeared ? 1 : 0.9)
                    .opacity(appeared ? 1 : 0)
                Spacer()
            }
        }
        .onAppear { withAnimation(Motion.snappy) { appeared = true } }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            HStack(spacing: Space.s2) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tint)
                Text("KARARIN SONUCU")
                    .font(.eyebrow).kerning(1.0)
                    .foregroundStyle(tint)
            }

            Text(result.text)
                .font(.bodyText)
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)

            // #19 köprü: sonucun altında ilgili Defter dersi.
            if let lesson = relatedLesson {
                Button { Haptics.selection(); model.inspectedMechanic = result.mechanic } label: {
                    HStack(spacing: Space.s2) {
                        Image(systemName: lesson.category.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("BUNUNLA İLGİLİ DERS")
                                .font(.appText(9, .heavy)).kerning(0.6)
                                .foregroundStyle(theme.subtle)
                            Text(lesson.title)
                                .font(.appText(13, .bold))
                                .foregroundStyle(theme.text)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(theme.subtle)
                    }
                    .padding(Space.s3)
                    .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
                    .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(theme.hairline, lineWidth: 1))
                }
                .buttonStyle(.pressable)
            }

            Button { dismiss() } label: {
                Text("Devam")
                    .font(.bodyL).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, Space.s3)
                    .background(tint, in: RoundedRectangle(cornerRadius: Radius.m))
            }
            .buttonStyle(.pressable)
        }
        .padding(Space.s5)
        .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.overlay))
        .overlay(RoundedRectangle(cornerRadius: Radius.overlay).stroke(tint.opacity(0.3), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
    }

    private func dismiss() {
        Haptics.tap()
        withAnimation(Motion.quick) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { model.pendingResult = nil }
    }
}

// MARK: - Ders popup'ı (#19) — mekanik → ilgili Defter dersi

/// Herhangi bir "ℹ" / metrik rozeti / sonuç köprüsünden açılan tek-ders kartı.
/// `model.inspectedMechanic` set edildiğinde ContentView bunu gösterir.
struct LessonPopupView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let mechanic: String
    @State private var appeared = false

    private var lesson: LessonEntry? { LessonsContent.lesson(for: mechanic) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { dismiss() }
            VStack {
                Spacer()
                if let lesson { card(lesson) } else { fallback }
                Spacer()
            }
            .padding(.horizontal, Space.s4)
        }
        .onAppear { withAnimation(Motion.snappy) { appeared = true } }
    }

    private func card(_ lesson: LessonEntry) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            HStack(spacing: Space.s2) {
                ZStack {
                    Circle().fill(theme.accent.opacity(0.16)).frame(width: 40, height: 40)
                    Image(systemName: lesson.category.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("DEFTER · \(lesson.category.title.uppercased())")
                        .font(.eyebrow).kerning(0.8)
                        .foregroundStyle(theme.subtle)
                    Text(lesson.title)
                        .font(.titleM)
                        .foregroundStyle(theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(lesson.body)
                .font(.bodyText)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button { dismiss() } label: {
                Text("Anladım")
                    .font(.bodyL).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, Space.s3)
                    .background(theme.accent, in: RoundedRectangle(cornerRadius: Radius.m))
            }
            .buttonStyle(.pressable)
        }
        .padding(Space.s5)
        .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.overlay))
        .overlay(RoundedRectangle(cornerRadius: Radius.overlay).stroke(theme.accent.opacity(0.3), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
    }

    private var fallback: some View {
        // Eşleşen ders yoksa (savunmacı) — sade kapan.
        Color.clear.frame(height: 0).onAppear { dismiss() }
    }

    private func dismiss() {
        Haptics.tap()
        withAnimation(Motion.quick) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { model.inspectedMechanic = nil }
    }
}
