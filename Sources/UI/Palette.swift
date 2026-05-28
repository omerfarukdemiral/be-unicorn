import SwiftUI

/// Merkezi renk paleti — evreden bağımsız sabit semantik renkler.
/// Tüm dosyalardaki dağınık sihirli hex'ler (4FD1A1/FFD166/E0574F vb.) buradan okunur.
enum Palette {

    // MARK: Semantik (sabit — tek kaynak)
    /// Pozitif delta, sağlıklı oran, karlı runway, tamamlanan evre.
    static let success    = Color(hex: "3FCF8E")
    /// success'in koyu/dolgu varyantı.
    static let successDim = Color(hex: "2BA876")
    /// Kırılgan, dikkat, orta moral.
    static let warning    = Color(hex: "F5C451")
    /// Negatif nakit, düşük runway, iflas, çıkar butonu.
    static let danger     = Color(hex: "F0584F")
    /// danger basılı/dolgu varyantı.
    static let dangerDim  = Color(hex: "C2443C")
    /// Kutlama, XP, prestij vurgusu (funding/win).
    static let gold       = Color(hex: "FFD479")
    /// Unicorn / zafer pembesi.
    static let unicorn    = Color(hex: "FF6FB5")

    // MARK: Metin opaklık kademeleri (beyaz üstüne)
    static let textPrimary    = Color.white                  // kahraman sayılar, başlıklar
    static let textSecondary  = Color.white.opacity(0.78)    // gövde metni, balon içeriği
    static let textTertiary   = Color.white.opacity(0.52)    // etiketler ("kullanıcı", "MRR")
    static let textQuaternary = Color.white.opacity(0.32)    // devre dışı, kilitli, placeholder
}

// MARK: - Hareket / animasyon token'ları
enum Motion {
    /// Overlay giriş, kart pop.
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.75)
    /// Kutlama (funding/win hero).
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
    /// Tab geçiş, balon metni, renk değişimi.
    static let smooth = Animation.easeInOut(duration: 0.25)
    /// Çıkış / dismiss.
    static let quick  = Animation.easeIn(duration: 0.13)
}

// MARK: - Boşluk skalası (4pt tabanlı)
enum Space {
    static let s1: CGFloat = 4    // ikon-metin arası mikro
    static let s2: CGFloat = 8    // pill içi, eleman arası dar
    static let s3: CGFloat = 12   // kart iç dikey, kartlar arası standart
    static let s4: CGFloat = 16   // kart iç padding, ekran kenar
    static let s5: CGFloat = 22   // overlay iç padding
    static let s6: CGFloat = 28   // overlay hero boşluk
}

// MARK: - Köşe yarıçapı token'ları
enum Radius {
    static let s: CGFloat = 10        // iç pill, küçük buton, bar track
    static let m: CGFloat = 14        // standart buton, balon
    static let overlay: CGFloat = 24  // karar / funding kartı
}
