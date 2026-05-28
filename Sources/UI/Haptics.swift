import UIKit

/// Merkezi dokunsal geri bildirim — "oyun" hissi için.
enum Haptics {
    /// İşe al / modül satın al gibi hafif aksiyon.
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    /// Birincil CTA (raise) — orta etki.
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
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
}
