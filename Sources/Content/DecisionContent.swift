import Foundation

/// Karar kartı havuzu (Türkçe). İçerik ajanı bu listeyi genişletir.
/// Gerçek startup senaryolarından esinli, anonim ama tanınabilir durumlar.
enum DecisionContent {
    static let all: [DecisionCard] = [

        // MARK: - Başlangıç / Melek Yatırım

        DecisionCard("angel-1", category: .investor, speaker: "Melek Yatırımcı", icon: "👼",
            prompt: "Bir melek yatırımcı garajına geldi: \"50 bin dolar veririm, karşılığında %8 hisse.\" Kabul mü?",
            once: true,
            choices: [
                .init("Kabul et", detail: "+$50K, −%8 hisse", effects: [.cash(50_000), .equity(-0.08), .reputation(5)],
                      result: "Çek elinde. İlk yatırımcın oldu."),
                .init("Reddet", detail: "Hisseni koru", effects: [.morale(3), .reputation(-2)],
                      result: "Bağımsız kalmayı seçtin.")
            ]),

        DecisionCard("friends-family", category: .investor, speaker: "Aile & Arkadaşlar", icon: "👨‍👩‍👧",
            prompt: "Annen ve eski sınıf arkadaşın toplam 20 bin dolar yatırmak istiyor. Kişisel ilişkileri işe karıştırmak riskli.",
            once: true,
            choices: [
                .init("Al, teşekkür et", detail: "+$20K, ilişki riski", effects: [.cash(20_000), .morale(5)],
                      result: "Aile desteğiyle umut tazelendi."),
                .init("Hayır de, koruyucu ol", detail: "İlişkiyi koru", effects: [.morale(-3), .reputation(2)],
                      result: "Onları korumayı seçtin; para ayrı tutuldu.")
            ]),

        // MARK: - Yatırımcı Turları

        DecisionCard("seed-termsheet", category: .investor, speaker: "VC Fonu", icon: "📋",
            prompt: "İki VC'den term sheet geldi: A Fonu %18 hisse için $500K istiyor, B Fonu %12 için $300K — ama B'nin ağı daha geniş.",
            once: true, trigger: .minStage(1),
            choices: [
                .init("A Fonu — daha fazla para", detail: "+$500K, −%18 hisse", effects: [.cash(500_000), .equity(-0.18), .reputation(6)],
                      result: "Büyük çek geldi. Artık gerçek koşuyorsun."),
                .init("B Fonu — akıllı para", detail: "+$300K, −%12 hisse + ağ", effects: [.cash(300_000), .equity(-0.12), .reputation(12), .moraleTargetBonus(2)],
                      result: "Daha az nakit ama her kapı açık.")
            ]),

        DecisionCard("vc-board-seat", category: .investor, speaker: "Lider Yatırımcı", icon: "🪑",
            prompt: "Yatırımcı yatırım karşılığında yönetim kurulunda oy hakkı istiyor. Kontrol devri mi, yoksa küçük tur mu?",
            once: true, trigger: .minStage(2),
            choices: [
                .init("Oy hakkı ver", detail: "−kontrol, +büyük yatırım", effects: [.cash(1_000_000), .equity(-0.15), .reputation(8)],
                      result: "Seri A kapandı. Yönetim kurulun artık kalabalık."),
                .init("SAFE ile kapat", detail: "Kontrol sende, daha az nakit", effects: [.cash(400_000), .equity(-0.06), .morale(5)],
                      result: "Havalı kurucu: kontrol senin, para daha az.")
            ]),

        DecisionCard("down-round", category: .investor, speaker: "Yatırımcı Toplantısı", icon: "📉",
            prompt: "Piyasa kötü. Mevcut yatırımcılar down round öneriyor — önceki değerlemenin altında. Kabul mü?",
            trigger: .lowRunwayMonths(3),
            choices: [
                .init("Down round'u kabul et", detail: "Nakit gelir, onur zedelenir", effects: [.cash(300_000), .equity(-0.12), .morale(-8), .reputation(-5)],
                      result: "Acı ama runway kurtarıldı."),
                .init("Köprü kredi dene", detail: "Risk: anlaşma çözülür", effects: [.cash(80_000), .reputation(-2)],
                      result: "Köprüden geçtin — şimdilik.")
            ]),

        // MARK: - Basın & İtibar

        DecisionCard("press-launch", category: .press, speaker: "Teknoloji Blogu", icon: "📰",
            prompt: "Tanınmış bir teknoloji blogu seni yazmak istiyor. Ama erken; ürün tam hazır değil.",
            trigger: .minUsers(50),
            choices: [
                .init("Röportajı ver", detail: "+itibar, +kullanıcı / risk", effects: [.reputation(12), .usersPercent(0.4)],
                      result: "Haber viral oldu, kullanıcılar akın etti."),
                .init("Daha sonra", detail: "Güvenli oyna", effects: [.reputation(-1)],
                      result: "\"Hazır olunca\" dedin.")
            ]),

        DecisionCard("negative-review", category: .press, speaker: "Etki Sahibi Kullanıcı", icon: "😡",
            prompt: "Ürünü eleştiren uzun bir blog yazısı yayınlandı. Binlerce kişi okudu. Cevap verecek misin?",
            trigger: .minUsers(200),
            choices: [
                .init("Alenen cevap ver, düzelt", detail: "+itibar uzun vade", effects: [.reputation(10), .morale(4), .usersPercent(-0.05)],
                      result: "Olgunluk gösterdin; topluluk saygı duydu."),
                .init("Sessiz kal, yama yap", detail: "Kısa vade rahat", effects: [.reputation(-4), .usersPercent(-0.08)],
                      result: "Sessizlik bazılarına kötü kültür gibi göründü.")
            ]),

        DecisionCard("famous-tweet", category: .press, speaker: "Ünlü Teknoloji Figürü", icon: "🐦",
            prompt: "Milyonlarca takipçisi olan biri ürünü tweet'ledi: \"Bu inanılmaz!\" Sunucular zaten zorlanıyor.",
            trigger: .minUsers(500),
            choices: [
                .init("Tweet'e dayan, büyü", detail: "+kullanıcı patlaması / sunucu riski", effects: [.usersPercent(0.5), .cash(-8_000), .reputation(15)],
                      result: "Sunucular yutkundu ama büyüme çılgındı."),
                .init("Bekleme listesine al", detail: "Kaliteyi koru", effects: [.usersPercent(0.15), .reputation(6)],
                      result: "\"Davet bekliyor\" ibaresi merak yarattı.")
            ]),

        // MARK: - Kriz

        DecisionCard("burnout", category: .team, speaker: "Takım Lideri", icon: "😮‍💨",
            prompt: "Ekip haftalardır mesai yapıyor. Tükenmişlik sinyalleri var. Ne yaparsın?",
            trigger: .lowMorale(45),
            choices: [
                .init("Herkese izin ver", detail: "+moral / kısa duraklama", effects: [.morale(18), .moraleTargetBonus(3)],
                      result: "Dinlenen ekip geri döndü, enerji yükseldi."),
                .init("Pizza ısmarla, devam", detail: "Küçük teselli", effects: [.morale(4), .cash(-500)],
                      result: "Pizza geldi ama yorgunluk sürüyor.")
            ]),

        DecisionCard("data-breach", category: .crisis, speaker: "Güvenlik Ekibi", icon: "🛡️",
            prompt: "Küçük bir veri sızıntısı tespit edildi. Basına yansımadan harekete geçmelisin.",
            trigger: .minUsers(500),
            choices: [
                .init("Şeffaf ol, duyur", detail: "−kullanıcı / +itibar", effects: [.usersPercent(-0.08), .reputation(8), .cash(-3_000)],
                      result: "Dürüstlük uzun vadede güven kazandırdı."),
                .init("Sessizce yama geç", detail: "Risk: ifşa", effects: [.reputation(-6), .users(0)],
                      result: "Sorunu sessizce kapattın... şimdilik.")
            ]),

        DecisionCard("payroll-risk", category: .crisis, speaker: "Mali İşler", icon: "💸",
            prompt: "Bu ayki maaşları ödemek nakit açısından çok sıkışık. Plan?",
            trigger: .lowRunwayMonths(2),
            choices: [
                .init("Köprü kredisi al", detail: "+nakit, −gelecek", effects: [.cash(20_000), .reputation(-3)],
                      result: "Kredi geldi, biraz nefes aldın."),
                .init("Maaşları ertele", detail: "−moral ağır", effects: [.morale(-20)],
                      result: "Ekip anlayışlı ama gergin.")
            ]),

        DecisionCard("server-crash", category: .crisis, speaker: "Mühendislik", icon: "🔥",
            prompt: "Ana sunucu çöktü. Kullanıcılar bağlanamıyor, sosyal medya kaynıyor. Her dakika itibar kaybı.",
            trigger: .minUsers(300),
            choices: [
                .init("Herkesi çağır, geceyi çalış", detail: "−nakit, +moral uzun vade", effects: [.cash(-5_000), .morale(-6), .reputation(5), .usersPercent(-0.03)],
                      result: "Sabaha karşı sistem ayaktaydı. Kahraman oldunuz."),
                .init("Bulut yedek sisteme geç", detail: "+nakit harcama / hızlı çözüm", effects: [.cash(-12_000), .reputation(8), .usersPercent(-0.01)],
                      result: "Pahalıydı ama sorun hızla çözüldü.")
            ]),

        DecisionCard("fraud-attempt", category: .crisis, speaker: "Operasyon", icon: "🚨",
            prompt: "Biri ödeme sisteminizde açık buldu ve sahte işlemler yapıyor. Yasal süreç açacak mısın?",
            trigger: .minUsers(400),
            choices: [
                .init("Hemen engelle, hukuka bildir", detail: "+itibar, +güven", effects: [.cash(-4_000), .reputation(7), .morale(3)],
                      result: "Çabuk aksiyon güven sinyali verdi."),
                .init("Sessizce engelle, kapatma", detail: "−itibar riski", effects: [.cash(-1_000), .reputation(-4)],
                      result: "Hukuki risk devam ediyor, ama sessiz kaldın.")
            ]),

        DecisionCard("regulation-shock", category: .crisis, speaker: "Hukuk Danışmanı", icon: "⚖️",
            prompt: "Yeni bir regülasyon sektörünüzü doğrudan etkiliyor. Uyum maliyeti yüksek; geç kalma cezası daha yüksek.",
            once: true, trigger: .minStage(2),
            choices: [
                .init("Hemen uyum sağla", detail: "+itibar, −nakit", effects: [.cash(-30_000), .reputation(10), .morale(-4)],
                      result: "Pahalıydı ama sektörde öncü oldun."),
                .init("Lobi yap, zaman kazan", detail: "Riskli bekleme", effects: [.cash(-8_000), .reputation(-3), .morale(2)],
                      result: "Süre kazandın ama risk asılı duruyor.")
            ]),

        // MARK: - Takım

        DecisionCard("key-hire", category: .team, speaker: "İK", icon: "🌟",
            prompt: "Üst düzey bir mühendis ekibe katılmak istiyor ama maaş beklentisi yüksek.",
            trigger: .minStage(1),
            choices: [
                .init("İşe al", detail: "+Mühendislik, −nakit", effects: [.cash(-8_000), .headcount(dept: 0, delta: 1), .morale(4)],
                      result: "Yıldız mühendis ekipte. Herkes motive."),
                .init("Bütçe yok", detail: "Vazgeç", effects: [.reputation(-1)],
                      result: "Teklifi geri çevirdin.")
            ]),

        DecisionCard("cofounder-conflict", category: .team, speaker: "Kurucu Ortağın", icon: "🤝",
            prompt: "Kurucu ortağınla vizyon konusunda derin bir anlaşmazlık var. O şirketi satmak istiyor, sen büyümeye devam etmek.",
            once: true, trigger: .minStage(1),
            choices: [
                .init("Uzlaş, ortak yol bul", detail: "İlişki korunur, vizyon bulanır", effects: [.morale(-5), .reputation(3)],
                      result: "Anlaşma yapıldı ama ikisi de tam mutlu değil."),
                .init("Hisselerini satın al, devam et", detail: "−nakit, +özgürlük", effects: [.cash(-50_000), .equity(0.08), .morale(10), .reputation(4)],
                      result: "Pahalıydı ama şirket senin.")
            ]),

        DecisionCard("star-resign", category: .team, speaker: "Yıldız Mühendis", icon: "👋",
            prompt: "En iyi mühendislerin istifa mektubu masanda. Rakip şirketten 1,5 kat maaş teklifi almış.",
            trigger: .minStage(1),
            choices: [
                .init("Karşı teklif yap", detail: "+nakit maliyet / ekip kaldı", effects: [.cash(-5_000), .morale(6), .headcount(dept: 0, delta: 0)],
                      result: "Kaldı. Ama kıl payı."),
                .init("Uğurla, referans ver", detail: "−mühendislik kısa vade", effects: [.morale(-8), .reputation(3), .headcount(dept: 0, delta: -1)],
                      result: "Vedalaştınız. Sonraki kapı açık olacak.")
            ]),

        DecisionCard("remote-vs-office", category: .team, speaker: "Ekip Oylaması", icon: "🏠",
            prompt: "Ekibin %60'ı tam remote istiyor. Ofis kirası yüksek. Ama yüz yüze iletişimi özlüyorsun.",
            once: true, trigger: .minStage(1),
            choices: [
                .init("Tam remote geç", detail: "+moral, −kira, −spontan sinerji", effects: [.cash(3_000), .morale(10), .moraleTargetBonus(2)],
                      result: "Ofis kapandı. Herkes mutlu, ama bazen sessiz."),
                .init("Hibrit model kur", detail: "Denge, maliyet orta", effects: [.cash(-2_000), .morale(5), .moraleTargetBonus(1)],
                      result: "Salı-Perşembe ofis, uzlaşı sağlandı."),
                .init("Ofiste kal", detail: "+kültür, +kira", effects: [.cash(-3_000), .morale(-4), .reputation(2)],
                      result: "Kültür korundu ama bazıları isteksiz.")
            ]),

        DecisionCard("culture-values", category: .team, speaker: "İK Danışmanı", icon: "🎯",
            prompt: "Ekip büyüdükçe kültür kayıyor. Resmi değerler belgesi mi, yoksa organik kültür mü?",
            once: true, trigger: .minStage(2),
            choices: [
                .init("Değer manifestosu yaz", detail: "+moral, +işe alım", effects: [.morale(8), .reputation(6), .cash(-2_000)],
                      result: "\"Neden buradayız?\" sorusu netleşti."),
                .init("Organik bırak", detail: "Serbest ama belirsiz", effects: [.morale(2)],
                      result: "Kültür yaşıyor ama tutarsız.")
            ]),

        DecisionCard("office-move", category: .team, speaker: "Operasyon Müdürü", icon: "🏢",
            prompt: "Mevcut ofis çok küçük kaldı. Daha büyük yere taşınmak pahalı ama verimlilik acı çekiyor.",
            trigger: .minStage(2),
            choices: [
                .init("Taşın, büyük ofis al", detail: "+verimlilik, −nakit", effects: [.cash(-15_000), .morale(8), .moraleTargetBonus(2)],
                      result: "Yeni ofis açıldı. Ekip coşkulu."),
                .init("Sıkışık kal, dayan", detail: "+nakit, −moral", effects: [.morale(-5), .cash(0)],
                      result: "Tasarruf ettiniz ama kol kola çalışıyorsunuz.")
            ]),

        // MARK: - Ürün & Pazar

        DecisionCard("competitor", category: .market, speaker: "Pazar Sinyali", icon: "⚔️",
            prompt: "Bir rakip, aynı özelliği bedavaya sundu. Kullanıcıların tedirgin.",
            trigger: .minUsers(200),
            choices: [
                .init("Fiyatı düşür", detail: "−ARPU baskısı / kullanıcıyı tut", effects: [.usersPercent(0.05), .moraleTargetBonus(-1)],
                      result: "Fiyat savaşına girdin, kullanıcılar kaldı."),
                .init("Kaliteye odaklan", detail: "+moral, +itibar", effects: [.morale(6), .reputation(6), .usersPercent(-0.04)],
                      result: "\"Biz farklıyız\" dedin, sadıklar kaldı.")
            ]),

        DecisionCard("pivot", category: .product, speaker: "Ürün Ekibi", icon: "🔀",
            prompt: "Veriler farklı bir kullanım şeklini işaret ediyor. Pivot yapalım mı?",
            trigger: .minUsers(300),
            choices: [
                .init("Cesur pivot", detail: "Kullanıcı sallanır / büyük fırsat", effects: [.usersPercent(-0.15), .reputation(8), .moraleTargetBonus(2)],
                      result: "Yeni yöne döndün; cesur ama umut verici."),
                .init("Rotada kal", detail: "İstikrar", effects: [.morale(2)],
                      result: "Mevcut planda kararlı kaldın.")
            ]),

        DecisionCard("open-source", category: .product, speaker: "Kıdemli Mühendis", icon: "🔓",
            prompt: "Çekirdek kodunu açık kaynak yapma önerildi. Topluluğu büyütersin ama rekabet avantajın azalır.",
            once: true, trigger: .minStage(2),
            choices: [
                .init("Açık kaynak yap", detail: "+itibar, +topluluk, −avantaj", effects: [.reputation(14), .usersPercent(0.2), .moraleTargetBonus(3)],
                      result: "GitHub yıldızları patladı. Topluluk sevdi."),
                .init("Kapalı tut, moat koru", detail: "Avantaj korunur", effects: [.reputation(2), .morale(2)],
                      result: "Tescilli kaldı. Yavaş ama güvenli büyüme.")
            ]),

        DecisionCard("pricing-change", category: .product, speaker: "Ürün & Büyüme", icon: "💰",
            prompt: "Freemium modelin çalışmıyor; bedava kullananlar ödeme yapmıyor. Fiyatı iki katına çıkar mı?",
            trigger: .minUsers(500),
            choices: [
                .init("Fiyatı artır, freemium'u kısıt", detail: "+gelir, −kullanıcı", effects: [.cashPercent(0.3), .usersPercent(-0.12), .reputation(-3)],
                      result: "Ödeyenler arttı, bedavacılar ayrıldı."),
                .init("Freemium koru, upsell dene", detail: "Daha az gelir, daha büyük huni", effects: [.usersPercent(0.1), .morale(3)],
                      result: "Büyüme devam etti ama kârlılık uzak.")
            ]),

        DecisionCard("feature-request-flood", category: .product, speaker: "Destek Ekibi", icon: "📬",
            prompt: "Kullanıcılar yüzlerce farklı özellik istiyor. Roadmap dağılıyor. Focus mu, herkesi mutlu et mi?",
            trigger: .minUsers(400),
            choices: [
                .init("Tek özelliğe odaklan", detail: "+ürün kalitesi, −gürültü", effects: [.morale(6), .reputation(8), .usersPercent(-0.05)],
                      result: "\"Daha az, daha iyi\" kararı verildi."),
                .init("En çok istenenin hepsini yap", detail: "+kullanıcı memnuniyeti kısa vade", effects: [.usersPercent(0.1), .morale(-5), .cash(-6_000)],
                      result: "Ekip yoruldu ama kullanıcılar memnun.")
            ]),

        DecisionCard("b2b-opportunity", category: .product, speaker: "Potansiyel Kurumsal Müşteri", icon: "🏗️",
            prompt: "Büyük bir kurumsal müşteri ürünü B2B olarak kullanmak istiyor. Ama B2C odağını bozacak.",
            once: true, trigger: .minStage(2),
            choices: [
                .init("B2B kolunu aç", detail: "+nakit, −odak", effects: [.cash(80_000), .headcount(dept: 3, delta: 1), .morale(-3), .reputation(5)],
                      result: "Yeni bir gelir kapısı açıldı. Ama roadmap değişti."),
                .init("B2C'de kal, reddet", detail: "+odak, −büyük nakit", effects: [.morale(5), .reputation(3)],
                      result: "Vizyon korundu. Saf B2C yoluna devam.")
            ]),

        // MARK: - Pazar & Büyüme

        DecisionCard("viral-tiktok", category: .market, speaker: "Sosyal Medya", icon: "📱",
            prompt: "Bir içerik üreticisi ürününü videoya koydu ve video patladı!",
            trigger: .minUsers(100),
            choices: [
                .init("Anı yakala, sunucu aç", detail: "+kullanıcı, −nakit", effects: [.usersPercent(0.6), .cash(-4_000), .reputation(6)],
                      result: "Sunucular zorlandı ama büyüme muazzam."),
                .init("Organik bırak", detail: "Daha az risk", effects: [.usersPercent(0.2)],
                      result: "Dalga kendiliğinden yayıldı.")
            ]),

        DecisionCard("growth-hack", category: .market, speaker: "Büyüme Ekibi", icon: "🚀",
            prompt: "Referral sistemi önerildi: her davet için kullanıcıya kredi ver. Maliyet yüksek ama büyüme hızlanır.",
            trigger: .minUsers(200),
            choices: [
                .init("Referral başlat", detail: "+kullanıcı, −nakit", effects: [.usersPercent(0.35), .cash(-10_000), .reputation(5)],
                      result: "Davet zinciri başladı; büyüme ivmelendi."),
                .init("Organik büyme sürsün", detail: "+nakit, −hız", effects: [.morale(2)],
                      result: "Yavaş ama sağlıklı büyüme devam etti.")
            ]),

        DecisionCard("international-launch", category: .market, speaker: "Büyüme Stratejisti", icon: "🌍",
            prompt: "Avrupa pazarından yoğun ilgi var. Lokalizasyon ve hukuki uyum çok maliyetli ama potansiyel büyük.",
            once: true, trigger: .minStage(3),
            choices: [
                .init("Avrupa'ya aç", detail: "+büyüme, −nakit, +itibar", effects: [.cash(-40_000), .usersPercent(0.3), .reputation(12), .headcount(dept: 2, delta: 1)],
                      result: "Uçuş başladı. Avrupa kullanıcıları geliyor."),
                .init("Önce yurt içini doyur", detail: "Odak koru", effects: [.morale(4), .reputation(2)],
                      result: "Temeli sağlamlaştırdın; zaman kazandın.")
            ]),

        DecisionCard("ad-spend-temptation", category: .market, speaker: "Pazarlama Danışmanı", icon: "📊",
            prompt: "Meta reklamlarına büyük bütçe bas: CAC yüksek ama bilinirlik patlayabilir. Risk almaya hazır mısın?",
            trigger: .minStage(1),
            choices: [
                .init("Agresif reklam bas", detail: "+kullanıcı, −nakit", effects: [.usersPercent(0.4), .cash(-20_000), .reputation(4)],
                      result: "Kullanıcılar geldi ama CAC acıtıyor."),
                .init("İçerik odaklı büy", detail: "+uzun vade, daha az nakit", effects: [.usersPercent(0.1), .reputation(5), .cash(-3_000)],
                      result: "Yavaş ama organik; daha uzun soluk.")
            ]),

        // MARK: - Fırsatlar

        DecisionCard("acquihire", category: .opportunity, speaker: "Büyük Şirket", icon: "🏢",
            prompt: "Büyük bir şirket küçük ekibini satın almak istiyor. Erken çıkış mı, devam mı?",
            once: true, trigger: .minStage(2),
            choices: [
                .init("Nakit teklifi al", detail: "+büyük nakit, −itibar", effects: [.cash(200_000), .reputation(-5), .moraleTargetBonus(-2)],
                      result: "Büyük çek geldi ama vizyon ertelendi."),
                .init("Reddet, büyü", detail: "+moral, +itibar", effects: [.morale(8), .reputation(10)],
                      result: "Ekip \"biz daha büyüğüz\" diye coştu.")
            ]),

        DecisionCard("acquisition-offer", category: .opportunity, speaker: "Stratejik Alıcı", icon: "💎",
            prompt: "Sektörün büyük oyuncusu $5 milyon teklif etti. Ekip ikiye bölündü: satış mı, bağımsızlık mı?",
            once: true, trigger: .minStage(4),
            choices: [
                .init("Sat, çıkış yap", detail: "Büyük exit / rüya bitti", effects: [.cash(5_000_000), .equity(0.10), .morale(-10), .reputation(5)],
                      result: "Çek imzalandı. Ekibin bir kısmı hayal kırıklığı yaşadı."),
                .init("Reddet, ilerle", detail: "Bağımsız kal, büyü", effects: [.morale(15), .reputation(12)],
                      result: "\"Biz satılık değiliz\" — ekip birleşti.")
            ]),

        DecisionCard("partnership-offer", category: .opportunity, speaker: "Stratejik Ortak", icon: "🤝",
            prompt: "Büyük bir platform entegrasyon ortaklığı teklif ediyor. Dağıtım kazanırsın ama bağımlı kalırsın.",
            once: true, trigger: .minStage(2),
            choices: [
                .init("Ortaklığı kur", detail: "+dağıtım, −bağımsızlık", effects: [.usersPercent(0.25), .reputation(8), .morale(5)],
                      result: "Platform sayesinde yeni kitlelere ulaştın."),
                .init("Bağımsız kal", detail: "+özgürlük, −erişim", effects: [.morale(4), .reputation(3)],
                      result: "Serbest kaldın; kendi kanallarını büyüttün.")
            ]),

        DecisionCard("accelerator-invite", category: .opportunity, speaker: "Hızlandırıcı Program", icon: "🎓",
            prompt: "Prestijli bir hızlandırıcıdan davet geldi: $120K nakit + mentorluk, karşılığında %7 hisse.",
            once: true,
            choices: [
                .init("Katıl", detail: "+nakit, +ağ, −hisse", effects: [.cash(120_000), .equity(-0.07), .reputation(15), .moraleTargetBonus(4)],
                      result: "Demo Day yaklaşıyor. Ağın genişledi."),
                .init("Reddet, kendi yolun", detail: "Hisseni koru, bağ koru", effects: [.morale(5), .reputation(2)],
                      result: "Bağımsız kalmayı seçtin.")
            ]),

        DecisionCard("grant-opportunity", category: .opportunity, speaker: "Devlet Fonu", icon: "🏛️",
            prompt: "Kamu destekli bir hibe programı için başvurabilirsin: $80K hibe ama bürokratik süreç uzun.",
            trigger: .minStage(1),
            choices: [
                .init("Başvur, uğraş", detail: "+nakit bedelsiz, −zaman", effects: [.cash(80_000), .morale(-4), .reputation(4)],
                      result: "Hibe geldi! Hisse vermeden nakit."),
                .init("Zamanına değmez", detail: "+odak, −fırsatçı nakit", effects: [.morale(3)],
                      result: "O zamanı ürüne harcadın.")
            ]),

    ]
}
