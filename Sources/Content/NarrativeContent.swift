import Foundation

/// Kurucu ipuçları & anlatı satırları (Türkçe). İçerik ajanı genişletir.
enum NarrativeContent {
    static let tips: [String] = [
        "Runway her şeydir. Nakit biterse oyun biter.",
        "Mutlu ekip = üretken ekip. Morali izle.",
        "Pazarlama olmadan harika ürün de sessizce kaybolur.",
        "Çok hızlı büyürsen ürün çöker; mühendisliği ihmal etme.",
        "Yatırım = yakıt ama her tur hisseni eritir.",
        "Churn sessiz katildir. Operasyon ve müşteri başarısı şart.",
        "Bir unicorn bir gecede doğmaz; her ay önemli.",
        "Hisse tablosu kontrolden çıkmadan önce cap table'ını oku.",
        "Ürün-pazar uyumu bulmadan ölçekleme, delik kovaya su dökmek gibidir.",
        "İlk 10 müşteri sana 100 müşteriden fazlasını öğretir.",
        "Down round utanç değil, hayatta kalmaktır.",
        "Referans müşteri > bin reklam. Memnun birini sahaya çıkar.",
        "CAC < LTV olana kadar büyüme harcaması tehlikelidir.",
        "Kurucu moral şirket moralidir; önce kendine dikkat et.",
        "Açık kaynak itibar kazandırır; kapalı kaynak savunma avantajı sağlar. İkisi de doğru.",
        "Tek özelliğin müşterinin hayatını değiştirdiğinden emin olmadan roadmap'i genişletme.",
        "Remote ekip = iletişim kasıtlı olmalı; yazılı kültür kur.",
        "Yatırımcı \"akıllı para\" mı, sadece para mı? Farkı sormayı unut.",
        "Fiyatı artırmaktan korkmak, değerini küçümsemektir.",
        "Ekibe verilen her söz bir sözleşmedir. Vaat etmeden önce düşün.",
    ]

    static let onHire: [String] = [
        "Yeni bir ekip arkadaşı! Enerji yükseldi.",
        "Ekip büyüyor — kapasite arttı.",
        "Doğru kişi doğru zamanda. Devam.",
        "Yeni yetenek yerini buldu. Hız kazanıyorsunuz.",
        "Bir koltuk daha doldu — artık daha hızlısınız.",
        "İyi işe alım her şeyin başlangıcıdır.",
        "Takımda taze bir bakış açısı var. İşler değişebilir.",
    ]

    static let onMilestone: [String] = [
        "Bir milestone daha! Her adım sizi büyük tabuloya yaklaştırıyor.",
        "Rakamlar konuştu — bir üst seviyeye geçtiniz.",
        "Ekip bu anı hak etti. Bir sonraki hedefe bakma vakti.",
        "İlerleme bir strateji değil, bir alışkanlıktır.",
        "Kutlayın, ama gözler hep ileriye bakmalı.",
    ]

    static let onCrisisResolved: [String] = [
        "Kriz atlattınız — savaştan güçlenerek çıktınız.",
        "Her kriz bir öğretmendir. Ders alındı.",
        "Baskı altında karar almak asıl liderlik testiydi. Geçtiniz.",
        "Zor günler bitiyor; geriye kalan deneyim kalıyor.",
    ]

    static func runwayTip(months: Double) -> String {
        if months.isInfinite { return "Karlısın — para artık seninle çalışıyor." }
        if months < 1 { return "Runway bir aydan az! Acil aksiyon gerek." }
        if months < 3 { return "Runway daralıyor. Gelir veya yatırım şart." }
        if months < 6 { return "Runway: ~\(Int(months)) ay. Yatırım konuşmalarına başlama zamanı." }
        return "Runway: ~\(Int(months)) ay. İdare eder."
    }
}
