import Foundation

/// Kurucu ipuçları & anlatı satırları (Türkçe). İçerik ajanı genişletir.
enum NarrativeContent {
    /// İlk oturum karşılaması (HZ-4) — kuruluş biter bitmez gösterilir.
    static let firstSessionWelcome =
        "İlk işin para kazanmak değil — birinin senin ürününü gerçekten istediğini bulmak. Geri kalan her şey bunun üstüne kurulur."

    /// İlk karar tebriği (HZ-1) — oyuncunun verdiği ilk kararın ardından.
    static let firstDecisionPraise =
        "İlk kararını verdin — tek doğru cevap yoktu, sen kendi bahsini koydun. Kararlarının dersleri artık Defter'de birikiyor."

    /// Kullanıcı eşiği kutlamaları (HZ-2) — ilk kez geçişte bir kez.
    static func userMilestonePraise(_ milestone: Int) -> String? {
        switch milestone {
        case 100:  return "İlk 100 kullanıcı! Bunlar en değerli kullanıcıların — her birini tanı, elle onboard et. Ölçeklenmeyen işler şimdi en kıymetli içgörüyü verir."
        case 1000: return "1.000 kullanıcı! Artık motor dönüyor. Şimdi soru değişiyor: kaç tanesi geri geliyor? Churn sessizce büyümeni yiyebilir."
        default:   return nil
        }
    }
    /// Kutlanacak kullanıcı eşikleri (artan sırada).
    static let userMilestones: [Int] = [100, 1000]

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
        "Tek müşteriye bağımlılık, görünmez bir tasmadır. Geliri çeşitlendir.",
        "Teknik borç faizle birikir; bir sprint'lik temizlik bir çeyreklik kriz önler.",
        "Klonlar özelliği kopyalar ama topluluğunu ve markanı kopyalayamaz.",
        "Kötü haberi sen duyur; basın senin yerine duyurursa kontrolü kaybedersin.",
        "Default alive: kimseye muhtaç olmadan hayatta kalabildiğin gün özgürsün.",
        "Sözleşmesiz kod, sahibi belirsiz koddur. Fikri mülkiyetini gün bir mühürle.",
        "Kurucu tükenirse şirket tükenir. Dinlenmek bir lüks değil, bir görevdir.",
        "Stratejik para hızlıdır ama bağlar getirir; bağların bedelini önceden hesapla.",
        "Bulut faturasını izlemeyen, runway'ini sessizce yakar.",
        "Downturn'da en güçlü silah disiplindir, panik değil.",
        "SOC2 ve uyum sıkıcıdır ama kurumsal kapıların anahtarıdır.",
        "Hızlı büyüme mimariyi test eder; ölçeklenmeyen kod en pahalı borçtur.",
        "İnfluencer'ın itibarı senin itibarındır; ortağını dikkatle seç.",
        "Çeşitli ekip daha iyi karar alır; tek tip oda kör nokta üretir.",
        "Tek doğru yol yoktur — Bootstrap, VC-Roket, Niş Uzman, Platform Geniş; her arketip kazanır, sadece patikası farklı.",
        "Default-alive: kimseye muhtaç olmadan hayatta kalabildiğin gün strateji seçeneklerinin sayısı artar.",
        "Başarısızlık öğrenmektir; iyi post-mortem bir sonraki stratejine yatırımdır — özrü değil.",
        "İki seçenek de duruma göre doğru olabilir; bağlamı oku, kuralı ezberleme.",
        "Hayır demek bir ürün stratejisidir; her 'evet' yol haritana bir çapa atar.",
        "Pivot başarısızlığın itirafı değil, verinin takibidir — ego susmadan veriyi okumak zor.",
        "Geri ödeme zorunlu olmayan tek paraya bedava deme; kurucu zamanı her zaman bedellidir.",
        "Concentration risk uyarısız vurur; tek müşteri, tek kanal, tek tedarikçi — üçü de görünmez tasmadır.",
        "Cap table sağlığı, bir sonraki turun ön koşuludur; bugünkü %1, yarınki %5 fiyat çapasıdır.",
        "Kahramanlık kültürü kısa vade satar, uzun vade burnout zinciri kurar — sistem kahramana ihtiyaç duyuyorsa sistem kırıktır.",
    ]

    static let onHire: [String] = [
        "Yeni bir ekip arkadaşı! Enerji yükseldi.",
        "Ekip büyüyor — kapasite arttı.",
        "Doğru kişi doğru zamanda. Devam.",
        "Yeni yetenek yerini buldu. Hız kazanıyorsunuz.",
        "Bir koltuk daha doldu — artık daha hızlısınız.",
        "İyi işe alım her şeyin başlangıcıdır.",
        "Takımda taze bir bakış açısı var. İşler değişebilir.",
        "Yeni bir kafa, yeni sorular soruyor. Konfor zonu sallandı.",
        "İşe alım kapandı; onboarding başladı. İlk hafta her şeyi belirler.",
        "Birini daha ikna ettin — vizyon satmak da bir yetenek.",
        "Ekip genişledi; artık iletişim de bir tasarım problemi.",
        "Doğru hire, yanlış hire'ı geri çıkarmaktan ucuzdur — bar'ı koru.",
        "İlk 20 kişide kültür donar; sonraki 200 onu çoğaltır ya da çürütür.",
    ]

    static let onMilestone: [String] = [
        "Bir milestone daha! Her adım sizi büyük tabuloya yaklaştırıyor.",
        "Rakamlar konuştu — bir üst seviyeye geçtiniz.",
        "Ekip bu anı hak etti. Bir sonraki hedefe bakma vakti.",
        "İlerleme bir strateji değil, bir alışkanlıktır.",
        "Kutlayın, ama gözler hep ileriye bakmalı.",
        "Dün imkânsız görünen, bugün geride kaldı. Çıta yükseliyor.",
        "Bu eşik bir kanıt: yöntemin işe yarıyor. Ölçekle.",
        "Grafik yukarı kıvrıldı. Şimdi onu kıvrık tutma vakti.",
        "Bu milestone bir kanıt değil bir veri noktası — strateji aynı stratejiyle ikinci kez de kazanırsa öğrenildi sayılır.",
        "Aynı hedefe farklı patikalardan varılır; sıralamana değil rotana sahiplen.",
    ]

    static let onCrisisResolved: [String] = [
        "Kriz atlattınız — savaştan güçlenerek çıktınız.",
        "Her kriz bir öğretmendir. Ders alındı.",
        "Baskı altında karar almak asıl liderlik testiydi. Geçtiniz.",
        "Zor günler bitiyor; geriye kalan deneyim kalıyor.",
        "Fırtına dindi. Ekip birbirine daha çok güveniyor şimdi.",
        "Yangını söndürdünüz; şimdi neden çıktığını anlama zamanı.",
        "Krizden çıkan ekip, krizden önceki ekipten daha güçlüdür.",
        "Bir kurşunu daha savuşturdun. Soğukkanlılık kazandırdı.",
        "İyi post-mortem suçlama aramaz; sistemin kör noktasını arar.",
        "Krizi atlatmak başarı değil minimum şart; ders çıkarmak başarıdır.",
        "Şu çeyrek hata yapma; gelecek çeyrek aynı hatayı yapma — fark öğrenmedir.",
    ]

    // MARK: Kuruluş — isim önerileri (kurucu + şirket + proje)
    static let founderFirstNames = ["Ada", "Deniz", "Eren", "Mira", "Kaan", "Zeynep", "Arda",
                                    "Lina", "Emir", "Selin", "Can", "Naz", "Toprak", "Ela",
                                    "Bora", "Defne", "Alp", "İpek", "Mert", "Derin"]
    static let founderLastNames = ["Yılmaz", "Demir", "Kaya", "Şahin", "Çelik", "Aydın", "Arslan",
                                   "Doğan", "Koç", "Aksoy", "Taş", "Polat", "Yıldız", "Öztürk"]
    static let companyNameSeeds = ["Nova", "Flux", "Hyper", "Volt", "Loop", "Drift", "Quanta",
                                   "Pulse", "Echo", "Apex", "Zen", "Cobalt", "Mint", "Tidal",
                                   "Forge", "Helix", "Lumen", "Orbit", "Vexa", "Nimbus"]
    static let companyNameSuffixes = ["Labs", "AI", "Tech", "Soft", "ify", "Works", "Hub", "Stack", "io"]
    static let projectNameSeeds = ["Atlas", "Pulse", "Spark", "Beacon", "Nimbus", "Quantum",
                                   "Horizon", "Vertex", "Aurora", "Cipher", "Pioneer", "Catalyst"]

    static func randomFounderName() -> (first: String, last: String) {
        (founderFirstNames.randomElement() ?? "Ada", founderLastNames.randomElement() ?? "Yılmaz")
    }
    static func randomCompanyName() -> String {
        let seed = companyNameSeeds.randomElement() ?? "Nova"
        let suffix = companyNameSuffixes.randomElement() ?? "Labs"
        // Bazı son ekler bitişik ("ify"/"io"), bazıları ayrı kelime.
        return ["ify", "io"].contains(suffix) ? "\(seed)\(suffix)" : "\(seed) \(suffix)"
    }
    static func randomProjectName() -> String {
        projectNameSeeds.randomElement() ?? "Atlas"
    }

    static func runwayTip(months: Double) -> String {
        if months.isInfinite { return "Karlısın — para artık seninle çalışıyor." }
        if months < 1 { return "Runway bir aydan az! Acil aksiyon gerek." }
        if months < 3 { return "Runway daralıyor. Gelir veya yatırım şart." }
        if months < 6 { return "Runway: ~\(Int(months)) ay. Yatırım konuşmalarına başlama zamanı." }
        return "Runway: ~\(Int(months)) ay. İdare eder."
    }
}
