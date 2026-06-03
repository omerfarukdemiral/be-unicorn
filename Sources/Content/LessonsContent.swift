import Foundation

/// Defter girdisi: bir startup ilkesinin oyun mekaniğiyle birleştiği kısa içerik.
/// Tek doğru cevap dayatmaz — oyuncunun stratejisini bilinçli kurmasına aracılık eder.
struct LessonEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let body: String
    let category: LessonCategory
    /// İlgili oyun mekaniği etiketi (ör. "runway", "ltv-cac", "churn", "equity").
    /// Aynı zamanda HUD'dan ders açılırken eşleştirme için kullanılır.
    let mechanic: String
}

/// Defter kategorileri — chip filtreleri ve renk akrabalığı için.
enum LessonCategory: String, CaseIterable, Hashable {
    case runway
    case growth
    case team
    case product
    case equity
    case strategy
    case psychology

    /// Filtre chip'inde ve kart üst etiketinde geçen Türkçe ad.
    var title: String {
        switch self {
        case .runway:     return "Runway"
        case .growth:     return "Büyüme"
        case .team:       return "Ekip"
        case .product:    return "Ürün"
        case .equity:     return "Hisse"
        case .strategy:   return "Strateji"
        case .psychology: return "Psikoloji"
        }
    }

    /// Kart başlığında / chip'te kullanılan SF Symbol.
    var icon: String {
        switch self {
        case .runway:     return "fuelpump.fill"
        case .growth:     return "chart.line.uptrend.xyaxis"
        case .team:       return "person.2.fill"
        case .product:    return "cube.fill"
        case .equity:     return "chart.pie.fill"
        case .strategy:   return "map.fill"
        case .psychology: return "brain.head.profile"
        }
    }
}

/// Kurucu Defteri içeriği — oyun mekanikleriyle eşleşen kısa startup ilkeleri.
/// Ton: arkadaşça uzman — "ben yaparım" hissini bozmadan, suçlamasız bilgi aktarımı.
enum LessonsContent {
    static let all: [LessonEntry] = [

        // MARK: - Runway

        LessonEntry(
            id: "default-alive",
            title: "Default-Alive ya da Default-Dead",
            body: "Paul Graham'ın sorusu basit: bugünden itibaren tek dolar yatırım almasan, mevcut büyümenle karlılığa yetişebilir misin? Cevap \"evet\" ise default-alive'sın; pazarlık masasında ayakların yere basar. \"Hayır\" ise default-dead'sin ve runway sayacın asıl ürünündür. Bu ayrım strateji değil, gerçeklik kontrolüdür.",
            category: .runway,
            mechanic: "runway"
        ),

        LessonEntry(
            id: "runway-half-truth",
            title: "Runway'ini Yarıya Böl",
            body: "Kasada 12 ay göründüğünde gerçek pencere genellikle 6'dır. Yatırımcı süreci aylar sürer, kötü çeyrek burn'i şişirir, anlaşmalar son ay kapanmaz. Tur toplamaya runway tükendikten 6 ay önce başlamak \"erken\" değil; tam zamanında. Sayacın yarısı senin; diğer yarısı dünyaya ait.",
            category: .runway,
            mechanic: "runway"
        ),

        LessonEntry(
            id: "burn-is-velocity",
            title: "Burn Hız Değildir, Yöndür",
            body: "Yüksek burn kendi başına ne iyidir ne kötü. Eğer her dolar net yeni gelir, sözleşme veya ölçülebilir öğrenme üretiyorsa yakıt; üretmiyorsa sızıntıdır. Her ay sor: \"Geçen ay yaktığım her 1.000 dolar bana hangi sayıyı kazandırdı?\" Cevap yoksa, burn'ün hızdır ama gideceğin yer uçurumdur.",
            category: .runway,
            mechanic: "burn"
        ),

        // MARK: - Büyüme

        LessonEntry(
            id: "ltv-cac-3x",
            title: "LTV:CAC Neden 3'ten Büyük Olmalı",
            body: "Bir kullanıcı kazanmak için 1 dolar harcayıp 3 dolar geri kazanıyorsan iş modelin güvenli sayılır. Altındaki her sayı, büyüdükçe daha çok kaybedeceğin anlamına gelir. Erken aşamada bu oran sabit değildir, kanal kanal değişir; bu yüzden ölçeklemeden önce her kanalı tek tek doğrula. Karlı kanalda gaza bas, karlı olmayanı duyarsızca kapat.",
            category: .growth,
            mechanic: "ltv-cac"
        ),

        LessonEntry(
            id: "churn-silent-killer",
            title: "Churn — Sessiz Katil",
            body: "Yeni kullanıcı kazanmak görünür, kullanıcı kaybetmek görünmezdir. Aylık %5 churn yıllık yarınızı yer; ama dashboard'da hiçbir kırmızı uyarı çıkmaz. Önce churn'ü düşür, sonra acquisition'a yatırım yap; delik kovaya su dökmek bütçeyi kemirir. Hayatta kalan ürünler, geri gelen kullanıcılar üzerine kurulur.",
            category: .growth,
            mechanic: "churn"
        ),

        LessonEntry(
            id: "premature-scaling",
            title: "Erken Ölçekleme Tuzağı",
            body: "Startup Genome çalışması başarısız şirketlerin %70'inin tek ortak nedeninden bahseder: erken ölçekleme. Ürün-pazar uyumu olmadan işe alım yapmak, reklam bütçesini patlatmak, çoklu pazara açılmak. Önce 100 kullanıcının seni tutkuyla sevmesini sağla; ondan sonra 100.000'i ara. Tersi ucuza geliyormuş gibi görünür ama en pahalı yoldur.",
            category: .growth,
            mechanic: "scaling"
        ),

        LessonEntry(
            id: "organic-vs-paid",
            title: "Organik mi, Reklam mı",
            body: "Reklamla gelen kullanıcı musluk gibidir; kapattığın an akış durur. Organik (içerik, ağızdan ağıza, viral döngü) ise yavaş çalışan bir kuyudur — geç doldurur, kapatınca akmaya devam eder. Erken aşamada reklam test aracıdır, ölçek motoru değil. Önce viralite katsayısını ürünün içine kur, sonra reklam o motoru güçlendirsin.",
            category: .growth,
            mechanic: "marketing"
        ),

        // MARK: - Ürün

        LessonEntry(
            id: "pmf-feel",
            title: "Ürün-Pazar Uyumu Hissedilir",
            body: "Marc Andreessen'ın ünlü tanımı: \"Pazar ürünü senin elinden çekip alıyorsa, PMF buldun demektir.\" Tablo göstermez, oyuncak gibi büyür. Sean Ellis testi pratik bir ölçü verir: \"Bu ürün yarın kaybolsa ne hissedersin?\" sorusuna kullanıcıların %40'ı \"çok üzülürüm\" diyorsa, motor çalışıyordur. Altındaysa, daha hipotez aşamasındasın.",
            category: .product,
            mechanic: "product-market-fit"
        ),

        LessonEntry(
            id: "do-things-that-dont-scale",
            title: "Ölçeklenmeyen Şeyler Yap",
            body: "Paul Graham'ın klasiği: erken günlerde her kullanıcıyı tek tek tanı, elle onboard et, kapısına git, mesaj at. Bu \"verimsiz\" görünür çünkü öyle. Ama tam o ölçeklenmeyen sürtüşmede, ürünün doğru yöne dönmesini sağlayan içgörüleri toplarsın. Sonra otomatikleştirirsin — önce el emeğiyle gerçekten ne istendiğini öğren.",
            category: .product,
            mechanic: "product"
        ),

        LessonEntry(
            id: "feature-vs-product",
            title: "Özellik mi, Ürün mü",
            body: "Bir özellik problemi parça parça çözer; bir ürün kullanıcının iş yapma biçimini değiştirir. \"Hangi rakip özelliği eklersem büyürüm?\" sorusu seni özellik koleksiyoncusu yapar — ne ölür ne büyür. Asıl soru: \"Hangi problemi öyle iyi çözüyorum ki bensiz çalışamasınlar?\" Özellik listesi yarışmasını bırak, derin tek bir sözü kazan.",
            category: .product,
            mechanic: "product"
        ),

        LessonEntry(
            id: "pricing-captures-value",
            title: "Fiyat, Yarattığın Değeri Yakalamaktır",
            body: "Fiyatlandırma maliyetin üstüne kâr koymak değil; kullanıcıya kattığın değerin bir kısmını geri almaktır. Çoğu kurucu çok düşük fiyatlar — \"ucuz olursak çok satarız\" sezgisi yanıltıcıdır: düşük fiyat hem geliri hem de algılanan değeri birlikte düşürür. Patrick Campbell'ın verisi nettir: startup'ların ezici çoğunluğu fiyatlandırmaya ürününe harcadığının çok altında zaman ayırır. Önce \"kim için, hangi değer\" sorusunu netleştir; fiyat o cevabın etiketidir.",
            category: .product,
            mechanic: "pricing"
        ),

        // MARK: - Ekip

        LessonEntry(
            id: "hire-slow-fire-fast",
            title: "Yavaş İşe Al, Hızlı Çıkar",
            body: "Yanlış işe alımın bedeli sadece o maaş değil; ekibin moralidir, kültürün aşınmasıdır, yöneticinin enerjisini emmesidir. Reid Hoffman'ın notu: bir kişinin uymadığını anladığın anla onu çıkardığın an arasındaki süre, ortalama bir kurucuda altı aydır — ve neredeyse her kurucu bu kararı geciktirdiğinden pişman olur, asla erken aldığından değil. Şüphedeysen, işe alma. Şüphedeysen, çıkar.",
            category: .team,
            mechanic: "hiring"
        ),

        LessonEntry(
            id: "morale-compounds",
            title: "Moral Bileşik Getiridir",
            body: "Yüksek moral verimliliği iki katına çıkarmaz; üçe katlar, dörde katlar. Çünkü düşük moralli ekip sadece daha yavaş üretmez, dikkatsiz hatalar yapar, en iyileri gider, yeni katılanları zehirler. Maaş zammı bir defalık etkidir; takdir, otonomi, anlam ise bileşik faiz. En pahalı tasarruf, moralden yapılandır.",
            category: .team,
            mechanic: "morale"
        ),

        LessonEntry(
            id: "ten-x-myth",
            title: "10x Çalışan Miti",
            body: "Bazı mühendisler gerçekten 10 katı verimli üretir — ama ekipten kopuk çalışan bir 10x, çoğunlukla net negatiftir. Diğerlerinin anlamadığı kod yazar, onboarding'i imkansız hale getirir, kendi gidince çürür. Gerçek 10x, kendi çıktısı kadar etrafındakilerin de çıktısını yükseltendir. \"Ne kadar üretiyor\" sorusunun yanına \"ne kadar çoğaltıyor\" sorusunu koy.",
            category: .team,
            mechanic: "hiring"
        ),

        // MARK: - Hisse

        LessonEntry(
            id: "equity-not-valuation",
            title: "Hisse Değerleme Değildir",
            body: "Yüksek değerleme egoyu okşar; ama elinde kalan hisse oranı seninle ödülünü buluşturan tek bağdır. %20 hisse 1B değerlemede, %60 hisse 200M değerlemede daha az para getirir — basit matematik. Tur tur kaç hisse verdiğini takip et; \"$X yatırım aldık\" başlığı değil, \"bizden geriye ne kaldı\" sorusu kurucunun gerçek tablosudur.",
            category: .equity,
            mechanic: "equity"
        ),

        LessonEntry(
            id: "safe-deferred-dilution",
            title: "SAFE — Ertelenmiş Dilution",
            body: "SAFE turları hızlı kapanır, hisse oranını hemen göstermez. Bu rahatlatıcıdır ama yanıltıcıdır: birikmiş SAFE'lerin tamamı bir sonraki kapital turunda aynı anda dönüşür, ve fatura beklediğinden ağır gelir. Her SAFE imzaladığında \"şu anki cap üzerinden ne kadar hisse demek\" hesabını yap. Görünmeyen dilution en pahalı dilution'dur.",
            category: .equity,
            mechanic: "equity"
        ),

        // MARK: - Strateji

        LessonEntry(
            id: "no-single-path",
            title: "Tek Doğru Yol Yoktur",
            body: "Bootstrap'le bağımsız büyüyenler de unicorn olur; agresif VC turlarıyla roket gibi yükselenler de. Niş uzmanlar derinleşerek kazanır, platform geniş oyuncular ağ etkisiyle. Hangi strateji \"doğru\" diye sorma; senin kaynaklarına, pazarına ve sabrına hangisinin uyduğunu sor. Yanlış strateji, sana ait olmayanı taklit etmektir.",
            category: .strategy,
            mechanic: "strategy"
        ),

        LessonEntry(
            id: "focus-says-no",
            title: "Odak — Hayır Demektir",
            body: "Steve Jobs'un Apple'a döndüğünde yaptığı ilk iş ürün hattını 40'tan 4'e indirmekti. Strateji ne yapacağın değil, neyi yapmayacağın listesidir. Her \"evet\" diğer evetlerin kalitesini düşürür. Karar masasında en güçlü cümle: \"Bu fırsat iyi — ama bizim fırsatımız değil.\" Net bir hayır, on bulanık evetten kıymetlidir.",
            category: .strategy,
            mechanic: "strategy"
        ),

        // MARK: - Psikoloji

        LessonEntry(
            id: "failure-is-data",
            title: "Başarısızlık Veridir, Kimlik Değil",
            body: "İflas eden kurucular nadiren tekrar denemediğinde başarısız olur; \"ben başarısızım\" hikayesine kapıldığında. Hipotez kuruyorsun, deniyorsun, sonuç geliyor — iyi ya da kötü, ikisi de bilgi. Bir sonraki denemende neyi farklı yapacağını yazılı listele, kapat sayfayı, devam et. Y Combinator'ın istatistiği: başarılı kurucuların büyük çoğunluğu önceki bir denemesini batırmıştır.",
            category: .psychology,
            mechanic: "post-mortem"
        ),

        LessonEntry(
            id: "ride-the-trough",
            title: "Hayal Kırıklığı Vadisi",
            body: "Her startup yolculuğunda erken hype'ın söndüğü, henüz traction'ın gelmediği uzun bir orta dönem vardır — kurucu motivasyonunun en zayıf, ekibin en şüpheli olduğu yer. Çoğu şirket başarısız oldukları için değil, tam burada vazgeçtikleri için ölür. Bu vadinin geçici olduğunu bilmek, onu geçebilmenin ön koşuludur. Disiplin moralin yerine geçer, ta ki moral geri gelene kadar.",
            category: .psychology,
            mechanic: "morale"
        ),
    ]

    /// Kategoriye göre filtreli liste — chip seçimi için.
    static func filtered(by category: LessonCategory?) -> [LessonEntry] {
        guard let category else { return all }
        return all.filter { $0.category == category }
    }

    /// Mekanik etiketine göre ilgili dersi bul (#19 mechanic→ders köprüsü).
    /// HUD rozeti / karar-anı metrik / sonuç kartından "ilgili ders" açmak için.
    /// Tam eşleşme yoksa nil — çağıran tarafta köprü gösterilmez.
    static func lesson(for mechanic: String) -> LessonEntry? {
        all.first { $0.mechanic == mechanic }
    }

    static func lesson(id: String) -> LessonEntry? {
        all.first { $0.id == id }
    }

    /// Faz 5 — "önce hata, sonra ders": her dersin KİLİDİ hangi oyun-durumuyla açılır
    /// (Kurucu Defteri'nde kilitli kartta gösterilen ipucu). Eşik mantığı GameModel'de
    /// (`evaluateLessonTriggers`); buradaki metin yalnızca oyuncuya yön gösterir.
    /// Her ders bir açılış yoluna sahip olmalı — yoksa içerik kalıcı gizli kalır.
    static let unlockHint: [String: String] = [
        "default-alive":             "Runway 3 ayın altına düşsün (para yakarken)",
        "runway-half-truth":         "Runway 6 ayın altına insin",
        "burn-is-velocity":          "Aylık gider, gelirinin 2 katını aşsın",
        "ltv-cac-3x":                "LTV:CAC 3'ün altına insin (zarardayken)",
        "churn-silent-killer":       "Aylık churn belirgin yükselsin",
        "premature-scaling":         "Az kullanıcıyla (200 altı) ekibi büyüt",
        "organic-vs-paid":           "Reklam bütçesi toplam giderin yarısını geçsin",
        "pmf-feel":                  "100 kullanıcıya ulaş",
        "do-things-that-dont-scale": "İlk aylarda 50 kullanıcının altında kal",
        "feature-vs-product":        "İkinci bir projeyi başlat",
        "pricing-captures-value":    "200+ kullanıcın olsun ama aylık gelir düşük kalsın",
        "hire-slow-fire-fast":       "İlk çalışanını işe al",
        "morale-compounds":          "Moral 35'in altına düşsün",
        "ten-x-myth":                "Ekip 6 kişiye ulaşsın",
        "equity-not-valuation":      "Kurucu hissen %70'in altına insin",
        "safe-deferred-dilution":    "Kurucu hissen %50'nin altına insin",
        "no-single-path":            "Seed evresine ulaş",
        "focus-says-no":             "Aynı anda 3 proje yürüt",
        "failure-is-data":           "İlk iflasını yaşa",
        "ride-the-trough":           "Orta oyunda moral + büyüme birlikte düşsün",
    ]
}

extension DecisionCategory {
    /// Bu karar kategorisinin en alakalı Defter dersi mekaniği (#19 köprüsü).
    /// Karar sonucu kartından "ilgili ders"e geçiş için — kart başına etiketleme
    /// gelene dek (ÖNCELİK 3) kategori-bazlı makul varsayılan.
    var lessonMechanic: String {
        switch self {
        case .investor:    return "equity"
        case .crisis:      return "runway"
        case .press:       return "morale"
        case .team:        return "hiring"
        case .product:     return "product-market-fit"
        case .market:      return "marketing"
        case .opportunity: return "strategy"
        case .competitive: return "marketing"
        }
    }
}
