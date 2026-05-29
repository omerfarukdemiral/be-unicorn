import Foundation

/// Runtime kurucu arketipi (C3) — oyunun GERÇEK durumundan TÜRETİLİR, oyuncu seçmez.
/// Onboarding'deki `FounderLeaning` (oyuncunun beyan ettiği eğilim, mekanik etki yok)
/// ile KARIŞTIRMA: bu, oynanışın nasıl şekillendiğinin aynası. Suçlamasız koçluk tonu:
/// hiçbiri "doğru" arketip değildir — her biri farklı bir geçerli yoldur.
///
/// String rawValue → migration-proof: GameState'te `detectedArchetype` olarak saklanır,
/// eski/bilinmeyen değer `unknown`'a düşer (decode patlamaz).
enum FounderArchetype: String, Codable, CaseIterable {
    /// Henüz net bir desen yok (erken oyun / yetersiz sinyal).
    case unknown   = "unknown"
    /// Hisseni korudun, kendi gelirinle büyüdün — reklamsız, bağımsız.
    case bootstrap = "bootstrap"
    /// Hisse verip yakıt aldın, hızlı ölçeklendin — VC roketi.
    case vcRocket  = "vc-rocket"
    /// Dar ama yüksek değerli taban — güçlü fiyatlandırma, premium niş.
    case niche     = "niche"
    /// Geniş kullanıcı tabanı, ağ etkisi — platform oyunu.
    case platform  = "platform"

    var title: String {
        switch self {
        case .unknown:   return "Henüz Şekilleniyor"
        case .bootstrap: return "Bootstrap Kurucu"
        case .vcRocket:  return "VC Roketi"
        case .niche:     return "Niş Uzmanı"
        case .platform:  return "Platform Kurucusu"
        }
    }

    var icon: String {
        switch self {
        case .unknown:   return "questionmark.circle"
        case .bootstrap: return "leaf.fill"
        case .vcRocket:  return "flame.fill"
        case .niche:     return "diamond.fill"
        case .platform:  return "circle.hexagongrid.fill"
        }
    }

    /// Suçlamasız, "tek doğru yol yok" tonlu kısa açıklama.
    var blurb: String {
        switch self {
        case .unknown:
            return "Daha yolun başındasın. Birkaç karar daha, deseni netleştirecek — acele yok."
        case .bootstrap:
            return "Hisseni korudun, kendi gelirinle büyüdün. Yavaş ama senin olan bir yol — bağımsızlık bir strateji, eksiklik değil."
        case .vcRocket:
            return "Yakıt için hisse verdin, gaza bastın. Dilution'ı büyümeye çevirdin — hız senin bahsindi."
        case .niche:
            return "Dar bir kitleye yüksek değer sattın. Az kullanıcı, güçlü fiyat — derinlik de bir ölçektir."
        case .platform:
            return "Geniş bir tabana ulaştın, ağ etkisi senin için çalışıyor. Ölçek senin kanalın oldu."
        }
    }
}
