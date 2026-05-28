import UIKit

/// Merkezi dokunsal geri bildirim — "oyun" hissi için.
///
/// Düşük seviye darbeler (tap/medium/...) hâlâ tek başına kullanılabilir. Üstüne, anlamsal
/// olaylar için ses + haptiği TEK çağrıda eşleyen `Feedback` yardımcıları eklendi; böylece
/// GameModel/UI olay noktalarında tutarlı geri bildirim verir.
enum Haptics {
    /// İşe al / modül satın al gibi hafif aksiyon.
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    /// Birincil CTA (raise) — orta etki.
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    /// Sert/güçlü darbe (kutlama vuruşu).
    static func heavy() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    /// Karar geldi — sert kısa darbe.
    static func rigid() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    /// Tab değişimi.
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    /// Funding / Win kutlama.
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    /// Negatif nakit eşiği / kritik uyarı.
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    /// İflas.
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }

    /// İki darbeyi kısa gecikmeyle ardışık çal (kutlama "çift vuruş" dokusu).
    static func doubleTap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }
}

/// Ses + haptiği eşleyen anlamsal olay geri bildirimi.
/// Olay noktalarında `Feedback.hire()` gibi tek çağrı yeterli — hem titreşir hem ses çalar.
@MainActor
enum Feedback {
    /// İşe alım / eşya alımı / hafif onay.
    static func tap() {
        Haptics.tap()
        AudioManager.shared.tap()
    }
    /// Tab/seçim değişimi.
    static func select() {
        Haptics.selection()
        AudioManager.shared.select()
    }
    /// Karar kartı geldi.
    static func decision() {
        Haptics.rigid()
        AudioManager.shared.decision()
    }
    /// Günlük hedef / sprint başarısı — neşeli kutlama.
    static func success() {
        Haptics.success()
        AudioManager.shared.success()
    }
    /// Çeyrek kapanışı — tok başarı dokunuşu.
    static func close() {
        Haptics.medium()
        AudioManager.shared.close()
    }
    /// Funding turu / sezon finali / win — görkemli kutlama.
    static func celebrate() {
        Haptics.success()
        Haptics.doubleTap(.heavy)
        AudioManager.shared.celebrate()
    }
    /// Kritik uyarı (düşük runway / istifa).
    static func warning() {
        Haptics.warning()
        AudioManager.shared.warning()
    }
    /// İflas / başarısız sprint sonucu.
    static func failure() {
        Haptics.error()
        AudioManager.shared.failure()
    }
}
