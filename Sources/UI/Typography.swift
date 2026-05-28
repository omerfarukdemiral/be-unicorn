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
    /// SAYILAR için — Space Grotesk.
    static func appNumber(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Space Grotesk", size: size).weight(weight)
    }
    /// METİN / etiket / başlık için — Inter.
    static func appText(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size).weight(weight)
    }

    // MARK: - Named tipografi ölçeği
    // Space Grotesk = sayı/vurgu, Inter = metin/etiket. Sabit hiyerarşi.

    // Sayılar (Space Grotesk)
    static var displayXL: Font { .appNumber(34, .black) }   // Win "UNICORN"
    static var displayL:  Font { .appNumber(26, .heavy) }   // HUD nakit (kahraman)
    static var displayM:  Font { .appNumber(22, .heavy) }   // reklam bütçesi, büyük metrik
    static var numberL:   Font { .appNumber(17, .heavy) }   // metric kart değeri
    static var numberM:   Font { .appNumber(14, .bold) }    // ikincil sayı (yatırım satırı)
    static var numberS:   Font { .appNumber(12, .bold) }    // pill değeri, buton bedeli
    static var numberXS:  Font { .appNumber(10, .bold) }    // bar yüzdesi, "Lv 2/5"

    // Metin (Inter)
    static var titleL:    Font { .appText(24, .black) }     // overlay başlık
    static var titleM:    Font { .appText(18, .heavy) }     // panel başlığı
    static var bodyL:     Font { .appText(15, .semibold) }  // karar prompt, buton ana metni
    static var bodyText:  Font { .appText(13, .medium) }    // açıklama, founder balonu
    static var labelText: Font { .appText(11, .medium) }    // etiket ("kullanıcı", "MRR")
    static var caption:   Font { .appText(9, .bold) }       // üst etiket ("DEĞERLEME")
    static var eyebrow:   Font { .appText(11, .black) }     // üst başlık caps ("GARAJ")
}
