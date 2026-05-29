import SwiftUI
import CoreText

/// İki font: Space Grotesk (sayılar + vurgu) ve Inter (metin/etiket).
/// Variable TTF'ler bundle'dan programatik kaydedilir.
enum FontRegistrar {
    private static var done = false
    static func register() {
        guard !done else { return }
        done = true
        for name in ["SpaceGrotesk", "Inter"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}

extension Font {
    /// SAYILAR için — Space Grotesk. `relativeTo:` ile Dynamic Type ölçeklenir;
    /// taban `size` korunur → default boyutta render birebir aynı (regresyon yok).
    static func appNumber(_ size: CGFloat, _ weight: Font.Weight = .regular,
                          relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Space Grotesk", size: size, relativeTo: style).weight(weight)
    }
    /// METİN / etiket / başlık için — Inter. `relativeTo:` Dynamic Type bağı.
    static func appText(_ size: CGFloat, _ weight: Font.Weight = .regular,
                        relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Inter", size: size, relativeTo: style).weight(weight)
    }

    // MARK: - Named tipografi ölçeği
    // Space Grotesk = sayı/vurgu, Inter = metin/etiket. Sabit hiyerarşi.

    // Sayılar (Space Grotesk) — her ölçek uygun text-style'a bağlı (Dynamic Type).
    static var displayXL: Font { .appNumber(34, .black, relativeTo: .largeTitle) }   // Win "UNICORN"
    static var displayL:  Font { .appNumber(26, .heavy, relativeTo: .title) }        // HUD nakit (kahraman)
    static var displayM:  Font { .appNumber(22, .heavy, relativeTo: .title2) }       // reklam bütçesi, büyük metrik
    static var numberL:   Font { .appNumber(17, .heavy, relativeTo: .title3) }       // metric kart değeri
    static var numberM:   Font { .appNumber(14, .bold,  relativeTo: .body) }         // ikincil sayı (yatırım satırı)
    static var numberS:   Font { .appNumber(12, .bold,  relativeTo: .footnote) }     // pill değeri, buton bedeli
    static var numberXS:  Font { .appNumber(10, .bold,  relativeTo: .caption2) }     // bar yüzdesi, "Lv 2/5"

    // Metin (Inter) — her ölçek uygun text-style'a bağlı (Dynamic Type).
    static var titleL:    Font { .appText(24, .black,    relativeTo: .title) }       // overlay başlık
    static var titleM:    Font { .appText(18, .heavy,    relativeTo: .title3) }      // panel başlığı
    static var bodyL:     Font { .appText(15, .semibold, relativeTo: .callout) }     // karar prompt, buton ana metni
    static var bodyText:  Font { .appText(13, .medium,   relativeTo: .subheadline) } // açıklama, founder balonu
    static var labelText: Font { .appText(11, .medium,   relativeTo: .caption) }     // etiket ("kullanıcı", "MRR")
    static var caption:   Font { .appText(9,  .bold,     relativeTo: .caption2) }    // üst etiket ("DEĞERLEME")
    static var eyebrow:   Font { .appText(11, .black,    relativeTo: .caption) }     // üst başlık caps ("GARAJ")
}
