import Foundation

// MARK: - Kurucu Karnesi veri katmanı (B1 + B3 + B5c)
//
// Saf veri + türetme — UI yok, mantık yok. FounderScorecardView (B2) bu üç parçayı basar:
//  1) "En Pahalı 3 Ders"  → topTouchedMechanics'ten (B1 sayacı) türetilir.
//  2) Strateji Kimliği     → GameState'ten okunur (yeni mekanik yok, Kural-0).
//  3) Refleks Kartı        → 9 sabit öz-sorgu; en çok dokunulan mekanikler vurgulanır.

// MARK: - B5c: Refleks Kartı (#8.2)

/// Refleks Kartı: 9 çekirdek beceriden türetilmiş öz-sorgu listesi.
/// FounderScorecardView'de basılır; topTouchedMechanics içindeki mechanic'ler vurgulanır.
/// "Telefonunda kalsın" çerçevesi — CV/paylaşım iddiası YOK.
enum FounderReflexCard {
    static let intro =
        "Oyunu kapattıktan sonra da yanında kalsın. Gerçek bir karar anında bu 9 soru, refleksin olsun."
    static let highlightBadge = "BU OYUNDA EN ÇOK BURADA SINANDIN"
    static let questions: [(mechanic: String, q: String)] = [
        ("product-market-fit", "İnsanlar bunu gerçekten istiyor mu — yoksa ben istediğim için mi yapıyorum? Ürünü elimden çekip alan biri var mı?"),
        ("runway",             "Kaç ayım kaldı? Bugün tek dolar girmese, kasam beni nereye kadar taşır?"),
        ("ltv-cac",            "Bir müşteri bana kazandırdığından daha mı pahalıya geliyor? LTV'm CAC'imin en az 3 katı mı?"),
        ("equity",             "Ne kadar para aldığım değil — bu turdan sonra bende ne kalıyor?"),
        ("hiring",             "Bu kişiyi neden alıyorum: boşluğu doldurmak için mi, gerçekten ekibi yükselttiği için mi? Şüphedeysem almıyorum."),
        ("churn",              "Yeni kullanıcı kovalarken arkadan kaç tanesi sessizce gidiyor? Kovam delik mi?"),
        ("marketing",          "Bu kanal benim mi, kiralık mı? Yarın kapanırsa büyümem durur mu?"),
        ("product",            "Hangi tek problemi öyle iyi çözüyorum ki bensiz yapamıyorlar? Yoksa özellik mi biriktiriyorum?"),
        ("strategy",           "Bu fırsat iyi — ama benim fırsatım mı? Neye 'hayır' diyebiliyorum?")
    ]
}

// MARK: - B3: Strateji Kimliği

/// Oyuncunun bu oyundaki türetilmiş strateji kimliği. Yeni mekanik YOK —
/// yalnızca GameState'teki mevcut alanlardan okunur (Kural-0). Eğilimdir, etiket değil:
/// "sonraki denemende bambaşka bir kurucu olabilirsin".
struct FounderIdentity {
    let title: String
    let blurb: String

    /// Strateji Kimliği başlığının altında gösterilen sabit çerçeve.
    static let framing =
        "Bu senin bu oyundaki eğilimin — sonraki denemende bambaşka bir kurucu olabilirsin."

    /// Paylaş butonunun üstündeki gizlilik notu.
    static let privacyNote =
        "Bu karne yalnızca sende kalır. İstersen içgörünü paylaş — sayıların değil, öğrendiğin paylaşılır."

    /// Yukarıdan aşağı ilk tutan dal kazanır. Tümü GameState'ten okunur.
    static func derive(from s: GameState) -> FounderIdentity {
        // 1) Bağımsız Kurucu
        if s.founderEquity >= 0.55 && s.bankruptcies == 0 {
            return FounderIdentity(
                title: "Bağımsız Kurucu",
                blurb: "Hisseni korudun, kendi paranla büyüdün. Yavaş ama senin olan bir yol — bağımsızlık bir strateji, bir eksiklik değil.")
        }
        // 2) Hızlı Ölçekleyen
        if s.stageReached >= 3 && s.founderEquity < 0.45 {
            return FounderIdentity(
                title: "Hızlı Ölçekleyen",
                blurb: "Yakıt için hisse verdin, gaza bastın. Dilution'ı büyümeye çevirmeyi seçtin — risk senin imzandı.")
        }
        // 3) Organik Büyütücü
        if s.reputation >= 60 && s.adBudgetPerMonth <= 0 {
            return FounderIdentity(
                title: "Organik Büyütücü",
                blurb: "Reklam yerine itibarla büyüdün. En ucuz CAC ağızdan ağıza geçendir — sabrın senin kanalın oldu.")
        }
        // 4) İnsan-Önce Kurucu
        if s.morale >= 65 {
            return FounderIdentity(
                title: "İnsan-Önce Kurucu",
                blurb: "Ekibin moralini öncelik yaptın. Moral bileşik getiridir; sen faizini topladın.")
        }
        // 5) Varsayılan: Dengeli Kurucu
        return FounderIdentity(
            title: "Dengeli Kurucu",
            blurb: "Tek bir uca savrulmadın — nakit, ekip ve büyüme arasında ip cambazlığı yaptın. Denge de bir karardır.")
    }
}

// MARK: - "En Pahalı 3 Ders" türetme (B1 → B3 paylaşım)

/// Kurucu Karnesi'nin "En Pahalı 3 Ders" bölümü: oyuncunun bu oyunda en çok
/// dokunduğu mekaniklerden (B1 sayacı) ilgili Defter derslerini türetir.
/// topTouchedMechanics zaten frekansa göre sıralı top-3 anahtar dizisi verir;
/// her mechanic için LessonsContent köprüsüyle gerçek dersi çözer (eşleşmeyeni eler).
enum FounderScorecardData {
    /// Top-3 dokunulan mekaniğe karşılık gelen Defter dersleri (frekans sırasında).
    /// Yeterli karar verilmemişse (boş sayaç) boş dizi döner → çağıran "Henüz yeterli
    /// karar" fallback'i gösterir.
    static func topLessons(for mechanics: [String]) -> [LessonEntry] {
        mechanics.compactMap { LessonsContent.lesson(for: $0) }
    }

    /// ShareLink düz metni — skor/iflas PAYLAŞILMAZ, yalnızca içgörü.
    /// Boş ders durumunda jenerik içgörü cümlesine düşer.
    static func shareText(lessons: [LessonEntry], identity: FounderIdentity) -> String {
        if lessons.isEmpty {
            return "Be Unicorn'da bir startup kurdum ve denemeye devam ediyorum. Strateji kimliğim: \(identity.title). — Garajdan Zirveye"
        }
        let titles = lessons.prefix(3).enumerated()
            .map { "\($0.offset + 1)) \($0.element.title)" }
            .joined(separator: " ")
        return "Be Unicorn'da bu oyunda öğrendiğim en pahalı 3 ders: \(titles). Strateji kimliğim: \(identity.title). — Garajdan Zirveye"
    }

    /// Yeterli karar verilmediğinde gösterilecek suçlamasız fallback.
    static let notEnoughDecisions =
        "Henüz yeterli karar vermedin — birkaç tur daha oyna, en çok hangi mekaniklerde sınandığın burada birikecek."
}
