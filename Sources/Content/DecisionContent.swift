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

        // MARK: - Ölçek & Altyapı

        DecisionCard("scaling-crisis", category: .crisis, speaker: "Altyapı Ekibi", icon: "📈",
            prompt: "Kullanıcı sayısı patladı ama mimari kaldıramıyor. Her gün 3 kez çöküyor. Teknik borç kapıyı tekmeliyor.",
            trigger: .minUsers(2_000),
            choices: [
                .init("Mimariyi yeniden yaz", detail: "−nakit, −hız kısa vade, +sağlamlık", effects: [.cash(-25_000), .morale(-6), .reputation(6), .usersPercent(-0.04)],
                      result: "Acı bir refactor turu; ama temel artık sağlam."),
                .init("Yama üstüne yama", detail: "Hızlı ama kırılgan", effects: [.cash(-5_000), .reputation(-5), .morale(-3)],
                      result: "Bant yapıştırdın; bir sonraki çöküş zaman meselesi.")
            ]),

        DecisionCard("cloud-bill-shock", category: .crisis, speaker: "Mali İşler", icon: "☁️",
            prompt: "Bulut faturası bir gecede 4 katına çıktı; bir job sonsuz döngüye girmiş. Nakit eriyor.",
            trigger: .minUsers(1_000),
            choices: [
                .init("Acil maliyet optimizasyonu", detail: "−nakit kısa, +verim", effects: [.cash(-8_000), .morale(-4), .reputation(3)],
                      result: "FinOps ekibi devreye girdi; harcama dizginlendi."),
                .init("Görmezden gel, büyümeye odaklan", detail: "Riskli", effects: [.cashPercent(-0.15), .morale(2)],
                      result: "Fatura sızdırmaya devam ediyor.")
            ]),

        DecisionCard("technical-debt-vote", category: .product, speaker: "Mühendislik Lideri", icon: "🧱",
            prompt: "Ekip iki çeyrektir özellik fışkırttı, hiç temizlik yapmadı. Bir sprint'i tamamen borç ödemeye ayıralım mı?",
            trigger: .minStage(2),
            choices: [
                .init("Temizlik sprint'i yap", detail: "−hız kısa, +moral, +sağlamlık", effects: [.morale(8), .reputation(4), .usersPercent(-0.02)],
                      result: "Ekip nefes aldı; build artık yeşil."),
                .init("Özellik basmaya devam", detail: "+kullanıcı, −moral", effects: [.usersPercent(0.06), .morale(-6)],
                      result: "Roadmap doldu ama borç faiziyle birikiyor.")
            ]),

        // MARK: - Müşteri & Gelir Krizleri

        DecisionCard("whale-churn", category: .crisis, speaker: "Müşteri Başarısı", icon: "🐋",
            prompt: "Gelirinin %30'unu tek başına getiren en büyük kurumsal müşterin sözleşmeyi yenilemiyor.",
            trigger: .minStage(2),
            choices: [
                .init("CEO seviyesinde kurtarma operasyonu", detail: "−nakit, müşteriyi tut", effects: [.cash(-12_000), .reputation(4), .morale(2)],
                      result: "Özel indirim ve yol haritası sözüyle kaldılar — kıl payı."),
                .init("Bırak gitsin, çeşitlendir", detail: "−gelir, +bağımsızlık", effects: [.cashPercent(-0.25), .morale(-5), .reputation(2)],
                      result: "Tek müşteriye bağımlılık dersini pahalı öğrendin.")
            ]),

        DecisionCard("pricing-experiment", category: .product, speaker: "Büyüme Ekibi", icon: "🧪",
            prompt: "Kullanıcıların yarısına %40 daha yüksek fiyat gösteren bir A/B testi öneriliyor. Etik mi, akıllı mı?",
            trigger: .minUsers(1_500),
            choices: [
                .init("Testi başlat, veriye bak", detail: "+gelir verisi, −itibar riski", effects: [.cashPercent(0.12), .reputation(-3), .morale(1)],
                      result: "Fiyat esnekliği netleşti; biraz dedikodu çıktı."),
                .init("Şeffaf tek fiyat", detail: "+güven, −optimizasyon", effects: [.reputation(6), .morale(4)],
                      result: "Herkese aynı fiyat; topluluk güveni arttı.")
            ]),

        DecisionCard("enterprise-rfp", category: .opportunity, speaker: "Satış Direktörü", icon: "📑",
            prompt: "Devasa bir kurumun ihalesini kazanmak üzeresin ama 6 aylık özel entegrasyon ve SOC2 sertifikası istiyorlar.",
            once: true, trigger: .minStage(3),
            choices: [
                .init("İhaleye gir, kaynağı ayır", detail: "+büyük nakit, −odak", effects: [.cash(150_000), .headcount(dept: 3, delta: 1), .morale(-4), .reputation(10)],
                      result: "Logoyu kazandın; ekip uyum maratonuna girdi."),
                .init("Vazgeç, ürüne odaklan", detail: "+odak, −büyük fırsat", effects: [.morale(5), .reputation(2)],
                      result: "Kısa vadeli cazibeye direndin.")
            ]),

        // MARK: - Kurucu & İnsan

        DecisionCard("founder-burnout", category: .team, speaker: "İç Ses", icon: "🪫",
            prompt: "Aylardır uyumuyorsun. Ellerin titriyor, kararların bulanık. Bedenin dur diyor.",
            trigger: .lowMorale(40),
            choices: [
                .init("Bir hafta tamamen kopart", detail: "−ivme kısa, +moral büyük", effects: [.morale(16), .moraleTargetBonus(3), .reputation(2)],
                      result: "Dinlenmiş bir zihinle döndün; karar kaliten arttı."),
                .init("İçeceğe devam, dişini sık", detail: "Kısa vade üretim, uzun vade risk", effects: [.morale(-10), .usersPercent(0.03)],
                      result: "Bir sprint daha kazandın ama tank boşalıyor.")
            ]),

        DecisionCard("cofounder-departure", category: .team, speaker: "Kurucu Ortağın", icon: "🚪",
            prompt: "Kurucu ortağın \"ben yokum\" dedi ve ayrılıyor. Cap table'da %20'si var. Ekip sarsıldı.",
            once: true, trigger: .minStage(2),
            choices: [
                .init("Adil vesting ile uğurla", detail: "−nakit, +temiz cap table", effects: [.cash(-30_000), .equity(0.12), .morale(-6), .reputation(4)],
                      result: "Dostça ayrılık; hisseler düzene girdi."),
                .init("Hukuki kavgaya gir", detail: "−moral, −itibar, hisse koru", effects: [.equity(0.18), .morale(-12), .reputation(-8)],
                      result: "Mahkeme uzadı; ekip morali dibi gördü.")
            ]),

        DecisionCard("talent-raid", category: .team, speaker: "Rakip CEO", icon: "🎯",
            prompt: "Rakip şirket en iyi 3 mühendisine aynı anda agresif teklifler yaptı. Kapıdan kaçacaklar.",
            trigger: .minStage(2),
            choices: [
                .init("Hisse + maaş paketiyle tut", detail: "−nakit, −hisse, ekip kalır", effects: [.cash(-10_000), .equity(-0.03), .morale(8)],
                      result: "Üçü de kaldı; sadakat hisseyle mühürlendi."),
                .init("İkisini feda et, birini kurtar", detail: "−kapasite, +nakit", effects: [.headcount(dept: 0, delta: -2), .morale(-7), .cash(5_000)],
                      result: "İki koltuk boşaldı; en kritik isim kaldı.")
            ]),

        DecisionCard("diversity-push", category: .team, speaker: "İK & Kültür", icon: "🌈",
            prompt: "Ekip tek tip oldu. Bilinçli çeşitlilik programı zaman ve para ister ama uzun vadede daha güçlü kararlar getirir.",
            once: true, trigger: .minStage(2),
            choices: [
                .init("Programı başlat", detail: "−nakit, +moral, +itibar", effects: [.cash(-6_000), .morale(7), .reputation(8)],
                      result: "Farklı sesler masada; tartışmalar zenginleşti."),
                .init("Sonraya bırak", detail: "+odak kısa vade", effects: [.morale(-2)],
                      result: "\"Önce büyüyelim\" dedin; bazıları hayal kırıklığına uğradı.")
            ]),

        // MARK: - Regülasyon & Hukuk

        DecisionCard("gdpr-audit", category: .crisis, speaker: "Veri Koruma Otoritesi", icon: "📜",
            prompt: "Bir veri koruma otoritesi denetim başlattı. Eksiklerin var; ceza ciro bazlı olabilir.",
            trigger: .minUsers(3_000),
            choices: [
                .init("Tam uyum, danışman tut", detail: "−nakit ağır, +itibar", effects: [.cash(-22_000), .reputation(9), .morale(-3)],
                      result: "Temiz çıktın; sertifika bir satış argümanı oldu."),
                .init("Minimum düzeltme yap", detail: "−nakit az, ceza riski", effects: [.cash(-5_000), .reputation(-6)],
                      result: "Şimdilik geçtin ama dosya açık kaldı.")
            ]),

        DecisionCard("patent-troll", category: .crisis, speaker: "Hukuk Müşaviri", icon: "📿",
            prompt: "Bir patent trolü çekirdek özelliğin için ihlal davası açtı. Davalar yıllarca sürer ve yorar.",
            trigger: .minStage(3),
            choices: [
                .init("Mahkemede savaş", detail: "−nakit, +emsal güç", effects: [.cash(-18_000), .reputation(5), .morale(-4)],
                      result: "Pahalı ama trolü püskürttün; sektöre mesaj verdin."),
                .init("Sus payı öde, kurtul", detail: "−nakit hızlı, kötü emsal", effects: [.cash(-12_000), .reputation(-4)],
                      result: "Sorun kapandı ama troller artık adresini biliyor.")
            ]),

        DecisionCard("ip-ownership", category: .crisis, speaker: "Eski Çalışan", icon: "©️",
            prompt: "Erken dönem bir geliştirici, kodun bir kısmının kendisine ait olduğunu iddia ediyor. Sözleşme belirsizdi.",
            once: true, trigger: .minStage(2),
            choices: [
                .init("Adil bedel öde, hakları al", detail: "−nakit, +temiz IP", effects: [.cash(-15_000), .reputation(3), .morale(2)],
                      result: "Fikri mülkiyet artık tartışmasız şirketin."),
                .init("Reddet, riske gir", detail: "+nakit, hukuki bulut", effects: [.reputation(-5), .morale(-3)],
                      result: "Tehdit havada asılı; due diligence'ta sorun olabilir.")
            ]),

        // MARK: - Basın & Kriz

        DecisionCard("pr-scandal", category: .press, speaker: "İletişim Direktörü", icon: "🎤",
            prompt: "Bir çalışanın eski tweet'leri ortaya çıktı ve şirketle ilişkilendiriliyor. Sosyal medyada linç başladı.",
            trigger: .minReputation(40),
            choices: [
                .init("Net açıklama yap, değerleri vurgula", detail: "+itibar uzun vade, −moral kısa", effects: [.reputation(7), .morale(-4), .usersPercent(-0.03)],
                      result: "Dürüst ve hızlı yanıt fırtınayı dindirdi."),
                .init("Sessiz kal, geçsin bekle", detail: "Risk: büyür", effects: [.reputation(-9), .usersPercent(-0.06)],
                      result: "Sessizlik suçluluk gibi okundu; haber büyüdü.")
            ]),

        DecisionCard("influencer-backfire", category: .press, speaker: "Pazarlama", icon: "💥",
            prompt: "Anlaştığın bir influencer başka bir skandala karıştı ve markanla birlikte anılıyor. Kampanya yarıda.",
            trigger: .minUsers(800),
            choices: [
                .init("Sözleşmeyi hemen bitir, duyur", detail: "−nakit, +itibar", effects: [.cash(-7_000), .reputation(5), .usersPercent(-0.02)],
                      result: "Hızlı mesafe koydun; kriz sıçramadı."),
                .init("Kampanyayı bitir ama sessizce", detail: "+nakit, itibar riski", effects: [.reputation(-4)],
                      result: "Az konuştun; bazı kullanıcılar yine de bağ kurdu.")
            ]),

        DecisionCard("misinformation-wave", category: .press, speaker: "Topluluk Yöneticisi", icon: "📢",
            prompt: "Ürün hakkında yanlış bir iddia viral oldu: \"Verilerinizi satıyorlar.\" Doğru değil ama yayılıyor.",
            trigger: .minUsers(1_000),
            choices: [
                .init("Şeffaf rapor yayınla", detail: "−nakit, +güven", effects: [.cash(-3_000), .reputation(8), .morale(3)],
                      result: "Açık veri politikası belgesiyle iddia çürüdü."),
                .init("Avukatla tehdit et", detail: "Risk: Streisand etkisi", effects: [.reputation(-6), .usersPercent(-0.04)],
                      result: "Susturma çabası ateşe körük oldu.")
            ]),

        // MARK: - Yatırımcı & Board

        DecisionCard("board-pressure", category: .investor, speaker: "Yönetim Kurulu", icon: "🪑",
            prompt: "Board, kârlılık için ekibin %20'sini çıkarmanı istiyor. Sen kültürü korumak istiyorsun.",
            trigger: .minStage(3),
            choices: [
                .init("Hedefli, küçük küçülme yap", detail: "+nakit, −moral", effects: [.cashPercent(0.15), .headcount(dept: 4, delta: -1), .morale(-9), .reputation(-2)],
                      result: "Zor bir gün; runway uzadı ama yaralar kaldı."),
                .init("Direnci koru, alternatif sun", detail: "+moral, board gerilimi", effects: [.morale(8), .reputation(3), .cashPercent(-0.05)],
                      result: "Gelir planıyla board'u ikna ettin — bu sefer.")
            ]),

        DecisionCard("strategic-investor", category: .investor, speaker: "Kurumsal Yatırımcı", icon: "🏦",
            prompt: "Büyük bir kurum stratejik yatırım teklif ediyor: bol nakit ama rakiplerinle çalışmanı kısıtlayan maddeler içeriyor.",
            once: true, trigger: .minStage(3),
            choices: [
                .init("Stratejik parayı al", detail: "+büyük nakit, −esneklik", effects: [.cash(800_000), .equity(-0.10), .reputation(8), .moraleTargetBonus(-1)],
                      result: "Kasan doldu ama artık bazı kapılar kapalı."),
                .init("Finansal yatırımcı ara", detail: "−hız, +özgürlük", effects: [.cash(400_000), .equity(-0.08), .morale(4)],
                      result: "Daha az nakit ama hiçbir bağ yok.")
            ]),

        DecisionCard("secondary-sale", category: .investor, speaker: "Yatırımcın", icon: "💵",
            prompt: "Yatırımcın, kişisel hisselerinin bir kısmını satıp nakit çekmen için secondary sunuyor: ev al, rahatla.",
            once: true, trigger: .minStage(4),
            choices: [
                .init("Biraz hisse sat, güvene al", detail: "+kişisel nakit, −hisse, +rahatlık", effects: [.equity(-0.04), .cash(200_000), .morale(10), .reputation(-2)],
                      result: "Cebine para girdi; kararların daha sakin."),
                .init("Hepsini şirkette tut", detail: "+inanç sinyali", effects: [.morale(5), .reputation(6)],
                      result: "\"Tek kuruş çıkarmıyorum\" dedin; board etkilendi.")
            ]),

        // MARK: - Pazar & Makro

        DecisionCard("market-downturn", category: .crisis, speaker: "Makro Ekonomi", icon: "🌪️",
            prompt: "Piyasa çöküyor. Yatırım musluğu kurudu, müşteriler bütçe kesiyor. Kış geliyor.",
            once: true, trigger: .minStage(3),
            choices: [
                .init("Default alive moduna geç", detail: "−büyüme, +runway", effects: [.cashPercent(0.1), .usersPercent(-0.05), .morale(-3), .reputation(4)],
                      result: "Harcamayı kıstın; fırtınayı atlatacak yakıtın var."),
                .init("Karşı-döngü büyü, pay kap", detail: "+kullanıcı, −nakit, risk", effects: [.usersPercent(0.2), .cashPercent(-0.2), .reputation(6)],
                      result: "Herkes saklanırken sen saldırdın — yüksek bahis.")
            ]),

        DecisionCard("copycat-clone", category: .market, speaker: "Pazar İstihbaratı", icon: "👯",
            prompt: "İyi finanse edilmiş bir klon ürününü birebir kopyaladı ve agresif pazarlama yapıyor.",
            trigger: .minUsers(2_000),
            choices: [
                .init("Markaya ve topluluğa yaslan", detail: "+itibar, +moral", effects: [.reputation(9), .morale(6), .usersPercent(-0.03)],
                      result: "Sadık topluluk \"orijinali biz\" diye sahip çıktı."),
                .init("Özellik hızında yarış", detail: "+kullanıcı, −moral, −nakit", effects: [.usersPercent(0.08), .cash(-8_000), .morale(-5)],
                      result: "Hız savaşına girdin; ekip yoruldu ama öndesin.")
            ]),

        DecisionCard("viral-moment", category: .opportunity, speaker: "Büyüme Ekibi", icon: "🎆",
            prompt: "Bir haber döngüsü tam ürününün konusu hakkında; 24 saatlik bir viral pencere var. Hazır mısın?",
            trigger: .minUsers(500),
            choices: [
                .init("Tüm gücü pazarlamaya ver", detail: "+büyük kullanıcı, −nakit", effects: [.usersPercent(0.45), .cash(-9_000), .reputation(7), .morale(-3)],
                      result: "Anı yakaladın; trafik tavan yaptı."),
                .init("Temkinli kal, hazır ol", detail: "Güvenli, daha az kazanç", effects: [.usersPercent(0.12), .reputation(3)],
                      result: "Dalganın bir kısmını aldın; sunucular sağlam.")
            ]),

        DecisionCard("supply-dependency", category: .crisis, speaker: "Operasyon", icon: "🔗",
            prompt: "Tek tedarikçin olan bir API sağlayıcısı fiyatları 3 katına çıkardı ve sözleşmeyi tek taraflı değiştirdi.",
            trigger: .minStage(2),
            choices: [
                .init("Kendi çözümünü inşa et", detail: "−nakit, −hız, +bağımsızlık", effects: [.cash(-18_000), .morale(-4), .reputation(5), .usersPercent(-0.02)],
                      result: "Acı bir çeyrek; ama artık kimseye bağımlı değilsin."),
                .init("Yeni fiyatı yut", detail: "−nakit sürekli, +hız", effects: [.cashPercent(-0.12), .morale(1)],
                      result: "Ödedin ve devam ettin; kılıç hâlâ tepende.")
            ]),

    ]
}
