import Foundation

/// Karar kartı havuzu (Türkçe). İçerik ajanı bu listeyi genişletir.
/// Gerçek startup senaryolarından esinli, anonim ama tanınabilir durumlar.
enum DecisionContent {
    static let all: [DecisionCard] = [

        // MARK: - Başlangıç / Melek Yatırım

        DecisionCard("angel-1", category: .investor, speaker: "Melek Yatırımcı", icon: "👼",
            prompt: "Melek yatırımcı {{company}}'a uğradı: \"{{firstName}}, 50 bin dolar veririm — %8 hisse karşılığında. {{project}} ilgimi çekti.\" Kabul mü?",
            once: true,
            choices: [
                .init("Kabul et", detail: "+$50K nakit / −%8 hisse kalıcı", effects: [.cash(50_000), .equity(-0.08), .reputation(5)],
                      result: "Çek elinde — ama %8 sonsuza kadar gitti. (İlk melek ucuz görünür; sonraki turlarda fiyatın çapasıdır.)"),
                .init("Reddet, bootstrap'le", detail: "Hisse tam sende / kasada para yok", effects: [.morale(4), .reputation(-2), .moraleTargetBonus(1)],
                      result: "Bağımsız kaldın. (Default-alive'a yakınsan dilution'ın faturası genellikle daha ağırdır.)")
            ]),

        DecisionCard("friends-family", category: .investor, speaker: "Aile & Arkadaşlar", icon: "👨‍👩‍👧",
            prompt: "{{firstName}}, annen ve eski sınıf arkadaşın {{company}}'a toplam 20 bin dolar yatırmak istiyor. Kişisel ilişkileri işe karıştırmak riskli.",
            once: true,
            choices: [
                .init("Al, teşekkür et", detail: "+$20K şimdi / ilişki teminat", effects: [.cash(20_000), .morale(4), .reputation(-1)],
                      result: "Aile desteğiyle umut tazelendi. (F&F turu en pahalı sermayedir — başarısızlıkta Şükran Günü'nü öder.)"),
                .init("Hayır de, koruyucu ol", detail: "İlişkiyi koru / kasa boş", effects: [.morale(-3), .reputation(3), .moraleTargetBonus(1)],
                      result: "Onları korumayı seçtin. (Bilinçli \"hayır\" da bir hisse stratejisidir.)")
            ]),

        // MARK: - Erken-oyun kurucu ikilemleri (tekrarlanabilir, düşük-stake)
        // Garaj evresinde karar havuzu çabuk boşalmasın diye: gerçek trade-off'lu,
        // küçük etkili, zamansız "kurucu hayatı" kararları. once:false → akış kopmaz.
        // (cashPercent YOK — istismar riski yaratmaz.)

        DecisionCard("early-focus", category: .product, speaker: "Ortağın", icon: "🎯",
            prompt: "Ortağın \"bir sürü özellik ekleyelim, daha çok kişiye hitap eder\" diyor. Sen tek bir şeyi mükemmel yapmak istiyorsun.",
            trigger: .minUsers(0),
            choices: [
                .init("Tek işi cilala", detail: "+derinlik + moral / büyüme yavaş", effects: [.morale(3), .reputation(3), .usersPercent(0.02)],
                      result: "Daha az ama daha iyi. (Erken aşamada 100 kişinin bayıldığı ürün, 1000 kişinin umursamadığından iyidir.)"),
                .init("Özellik ekle, geniş tut", detail: "+kısa vade kullanıcı / odak dağılır", effects: [.usersPercent(0.05), .morale(-2)],
                      result: "Yelpaze açıldı. (Geniş ürün = sığ ürün riski; \"herkes için\" çoğu zaman \"hiç kimse için\"dir.)")
            ]),

        DecisionCard("early-channel", category: .market, speaker: "Sen", icon: "📣",
            prompt: "İlk kullanıcıları nasıl bulacaksın? Tek tek elle mi, yoksa hemen reklam mı?",
            trigger: .minUsers(0),
            choices: [
                .init("Elle, tek tek konuş", detail: "yavaş / +öğrenme + sadık çekirdek", effects: [.usersPercent(0.03), .reputation(4), .moraleTargetBonus(1)],
                      result: "İlk 10 kullanıcıyı tanıyorsun. (\"Ölçeklenmeyen şeyleri yap\" — erken çekirdek elle kazanılır.)"),
                .init("Hemen reklam ver", detail: "+hızlı sayı / pahalı + sığ", effects: [.usersPercent(0.06), .cash(-3_000)],
                      result: "Sayılar arttı ama tutmuyor. (Ürün-pazar uyumu yokken reklam, delik kovaya su taşır.)")
            ]),

        DecisionCard("early-sidegig", category: .opportunity, speaker: "Eski Müşteri", icon: "💼",
            prompt: "Eski bir müşteri sana 2 haftalık danışmanlık için iyi para teklif ediyor. Ama o 2 hafta ürününe gitmeyecek.",
            trigger: .minUsers(0),
            choices: [
                .init("Kabul et, kasayı doldur", detail: "+nakit / 2 hafta ürün durur", effects: [.cash(8_000), .moraleTargetBonus(-1)],
                      result: "Runway uzadı ama ürün bekledi. (Danışmanlık geliri tatlıdır; bağımlılık yaparsa startup'ı ajansa çevirir.)"),
                .init("Reddet, ürüne odaklan", detail: "kasa aynı / +momentum", effects: [.morale(3), .reputation(2), .usersPercent(0.02)],
                      result: "Odağı korudun. (Para kazanmak ile şirket kurmak farklı işlerdir; hangisini yaptığını bil.)")
            ]),

        DecisionCard("early-burnout", category: .team, speaker: "Vücudun", icon: "😮‍💨",
            prompt: "3 haftadır günde 14 saat çalışıyorsun. Bu hız sürdürülebilir değil ama liste uzun.",
            trigger: .minUsers(0),
            choices: [
                .init("Tempoyu düşür, dinlen", detail: "−kısa vade hız / +sürdürülebilir moral", effects: [.morale(6), .moraleTargetBonus(1), .usersPercent(-0.01)],
                      result: "Nefes aldın. (Startup maraton; tükenmiş kurucu, en pahalı tek-nokta-arızasıdır.)"),
                .init("Sıkı dişini, push'la", detail: "+kısa vade ilerleme / moral erir", effects: [.usersPercent(0.03), .morale(-5)],
                      result: "Liste kısaldı, sen de. (Sprint ara sıra iyidir; kalıcı kriz modu ekibi de seni de yer.)")
            ]),

        DecisionCard("early-feedback", category: .product, speaker: "İlk Kullanıcı", icon: "🗣️",
            prompt: "İlk kullanıcılardan biri \"şu olmadan kullanamam\" dediği bir özellik istiyor. Ama bu senin vizyonunda yoktu.",
            trigger: .minUsers(0),
            choices: [
                .init("Dinle, hızlı dene", detail: "+kullanıcı yakınlığı / vizyon esner", effects: [.usersPercent(0.04), .reputation(3), .morale(-1)],
                      result: "Kullanıcıyı dinledin. (Tek kullanıcının çığlığı sinyal olabilir de gürültü de; deseni ara.)"),
                .init("Vizyona sadık kal", detail: "+netlik / o kullanıcı küser", effects: [.reputation(2), .moraleTargetBonus(1), .usersPercent(-0.01)],
                      result: "Çizgini korudun. (Her isteğe evet = yön kaybı; ama tüm \"hayır\"lar da körlük olabilir.)")
            ]),

        DecisionCard("early-equity-split", category: .team, speaker: "Kurucu Ortak", icon: "🤝",
            prompt: "Ortağınla hisse dağılımını netleştirme zamanı. 50-50 mi, yoksa katkıya göre mi?",
            once: true, trigger: .minUsers(0),
            choices: [
                .init("Eşit böl, basit tut", detail: "+güven / gelecekte adaletsizlik riski", effects: [.morale(4), .moraleTargetBonus(1)],
                      result: "El sıkıştınız. (50-50 ilişkiyi rahatlatır; ama vesting yoksa ayrılıkta şirketi kilitleyebilir.)"),
                .init("Katkıya göre + vesting", detail: "+adil yapı / zor konuşma", effects: [.reputation(3), .morale(-2), .moraleTargetBonus(1)],
                      result: "Zor ama net konuştunuz. (Vesting kurucu kavgasının sigortasıdır; rahatken yapılır, kriz anında değil.)")
            ]),

        // MARK: - Yatırımcı Turları

        DecisionCard("seed-termsheet", category: .investor, speaker: "VC Fonu", icon: "📋",
            prompt: "İki VC'den term sheet geldi: A Fonu %18 hisse için $500K istiyor, B Fonu %12 için $300K — ama B'nin ağı daha geniş.",
            once: true, trigger: .minStage(1),
            choices: [
                .init("A Fonu — daha fazla nakit", detail: "+$500K şimdi / −%18 hisse + büyüme baskısı", effects: [.cash(500_000), .equity(-0.18), .reputation(4), .moraleTargetBonus(-1)],
                      result: "Büyük çek geldi. (Daha çok para = daha çok beklenti; agresif tempo şarttı.)"),
                .init("B Fonu — akıllı para", detail: "+$300K / −%12 hisse + ağ", effects: [.cash(300_000), .equity(-0.12), .reputation(10), .moraleTargetBonus(2)],
                      result: "Daha az nakit ama her kapı açık. (Erken turlarda valuation değil, partner kalitesi belirleyici.)")
            ]),

        DecisionCard("vc-board-seat", category: .investor, speaker: "Lider Yatırımcı", icon: "🪑",
            prompt: "Yatırımcı yatırım karşılığında yönetim kurulunda oy hakkı istiyor. Kontrol devri mi, yoksa küçük tur mu?",
            once: true, trigger: .minStage(2),
            choices: [
                .init("Oy hakkı ver, Seri A kapat", detail: "+$1M / −%15 / board kontrolü dağılır", effects: [.cash(1_000_000), .equity(-0.15), .reputation(8), .moraleTargetBonus(-1)],
                      result: "Seri A kapandı. (Bir koltuk = bir veto; majority kurucuda kalsa bile yön artık ortak kararla çiziliyor.)"),
                .init("SAFE ile kapat", detail: "+$400K / −%6 / kontrol sende", effects: [.cash(400_000), .equity(-0.06), .morale(6), .reputation(3)],
                      result: "Kontrol senin, para daha az. (SAFE ertelenmiş dilution: bir sonraki turda fatura kabarık çıkabilir.)")
            ]),

        DecisionCard("down-round", category: .investor, speaker: "Yatırımcı Toplantısı", icon: "📉",
            prompt: "Piyasa kötü. Mevcut yatırımcılar down round öneriyor — önceki değerlemenin altında. Kabul mü?",
            trigger: .lowRunwayMonths(3),
            choices: [
                .init("Down round'u kabul et", detail: "+$300K / −%12 + moral darbesi", effects: [.cash(300_000), .equity(-0.12), .morale(-9), .reputation(-5)],
                      result: "Acı ama runway kurtarıldı. (Default-alive olmadan büyüme bir kumardır; ego turun yerine, ölmemek için para almak doğru karardır.)"),
                .init("Köprü kredi dene", detail: "+$80K / borç + 6 ay sonra geri ödeme", effects: [.cash(80_000), .reputation(-2), .morale(-2)],
                      result: "Köprüden geçtin — şimdilik. (Borç hisseni korur ama saatli bombadır.)")
            ]),

        // MARK: - Basın & İtibar

        DecisionCard("press-launch", category: .press, speaker: "Teknoloji Blogu", icon: "📰",
            prompt: "Tanınmış bir teknoloji blogu {{company}} hakkında ({{sector}} dikeyinde) yazmak istiyor. Ama erken; {{project}} tam hazır değil.",
            trigger: .minUsers(50),
            choices: [
                .init("Röportajı ver", detail: "+itibar + kullanıcı patlaması / hazır değilse churn", effects: [.reputation(10), .usersPercent(0.35), .morale(-3)],
                      result: "Haber viral oldu. (Önce-launch erken trafik getirir; ürün tutamazsa kullanıcıyı iki kez kaybedersin.)"),
                .init("\"Hazır olunca\" de", detail: "İtibar sessiz / D7 retention'ı pişir", effects: [.reputation(-1), .morale(2), .moraleTargetBonus(1)],
                      result: "Basın sonra konuşur. (PMF'i bulmadan tanıtım yapmak, delik kovaya su dökmektir.)")
            ]),

        DecisionCard("negative-review", category: .press, speaker: "Etki Sahibi Kullanıcı", icon: "😡",
            prompt: "Ürünü eleştiren uzun bir blog yazısı yayınlandı. Binlerce kişi okudu. Cevap verecek misin?",
            trigger: .minUsers(200),
            choices: [
                .init("Alenen cevap ver, düzelt", detail: "+itibar uzun vade / kısa vade gerilim", effects: [.reputation(8), .morale(2), .usersPercent(-0.04)],
                      result: "Olgunluk gösterdin. (Açıkta savunmak korkutur ama topluluk savunan kurucuya sadakatle bağlanır.)"),
                .init("Sessiz kal, yama gönder", detail: "+kısa vade ürün düzelmesi / itibar erir", effects: [.reputation(-3), .usersPercent(-0.06), .morale(1)],
                      result: "Eleştiri haklıydı, sessizce kapattın. (Bazen aksiyon kelimeden daha gürültülü konuşur.)")
            ]),

        DecisionCard("famous-tweet", category: .press, speaker: "Ünlü Teknoloji Figürü", icon: "🐦",
            prompt: "Milyonlarca takipçisi olan biri {{project}}'i tweet'ledi: \"Bu inanılmaz!\" {{company}}'nın sunucuları zaten zorlanıyor.",
            trigger: .minUsers(500),
            choices: [
                .init("Tweet'e dayan, büyü", detail: "+çok kullanıcı / nakit yakıt + çöküş riski", effects: [.usersPercent(0.45), .cash(-9_000), .reputation(10), .morale(-3)],
                      result: "Sunucular yutkundu ama büyüme çılgındı. (Hazırlıksız tutuşan trafik kalıcı kullanıcı bırakmayabilir; D1 yüksek, D30 hayalet.)"),
                .init("Bekleme listesine al", detail: "+kalite + merak / +daha az nakit / +daha az hız", effects: [.usersPercent(0.12), .reputation(8), .morale(3)],
                      result: "\"Davet bekliyor\" merak yarattı. (Scarcity bir pazarlama aracıdır; kontrollü onboarding retention'ı korur.)")
            ]),

        // MARK: - Kriz

        DecisionCard("burnout", category: .team, speaker: "Takım Lideri", icon: "😮‍💨",
            prompt: "Ekip haftalardır mesai yapıyor. Tükenmişlik sinyalleri var. Ne yaparsın?",
            trigger: .lowMorale(45),
            choices: [
                .init("Herkese hafta izin", detail: "+büyük moral / ship date 1 hafta kayar", effects: [.morale(14), .moraleTargetBonus(2), .usersPercent(-0.02)],
                      result: "Dinlenen ekip geri döndü. (Tükenmişlik 3x maliyetlidir; bir hafta dur, üç hafta kazan.)"),
                .init("Pizza + esnek saat", detail: "+küçük moral / +hız korunur", effects: [.morale(5), .cash(-500), .moraleTargetBonus(-1)],
                      result: "Pizza geldi ama yorgunluk sürüyor. (Sembolik jest, sistemik soruna çare değildir.)")
            ]),

        DecisionCard("data-breach", category: .crisis, speaker: "Güvenlik Ekibi", icon: "🛡️",
            prompt: "Küçük bir veri sızıntısı tespit edildi. Basına yansımadan harekete geçmelisin.",
            trigger: .minUsers(500),
            choices: [
                .init("Şeffaf ol, hemen duyur", detail: "−kullanıcı kısa vade / +güven uzun vade", effects: [.usersPercent(-0.07), .reputation(9), .cash(-3_000)],
                      result: "Dürüstlük güven kazandırdı. (Kötü haberi sen duyurursan kontrol sende; basın duyurursa kontrol gitmiş demektir.)"),
                .init("Sessizce yama geç", detail: "+kullanıcıyı kaybetme / ifşa olursa katlanır ceza", effects: [.reputation(-6), .morale(-3), .usersPercent(-0.02)],
                      result: "Sorunu sessizce kapattın... şimdilik. (Cover-up ifşa edildiğinde, kriz ikiye katlanır.)")
            ]),

        DecisionCard("payroll-risk", category: .crisis, speaker: "Mali İşler", icon: "💸",
            prompt: "Bu ayki maaşları ödemek nakit açısından çok sıkışık. Plan?",
            trigger: .lowRunwayMonths(2),
            choices: [
                .init("Köprü kredisi al", detail: "+nakit şimdi / faiz + 6 ay sonra geri ödeme", effects: [.cash(20_000), .reputation(-3), .moraleTargetBonus(-1)],
                      result: "Kredi geldi. (Borç runway'i uzatır ama yeni bir saat kurar; gelir yetişmezse ikinci kriz bekliyor.)"),
                .init("Şeffaf konuş, kurucu maaşı kıs", detail: "−moral / +runway + ekip güveni", effects: [.cash(8_000), .morale(-10), .reputation(2)],
                      result: "Kurucu örneği koydun. (Default-alive olmak için önce kurucu kemerini sıkar; ekip bunu hatırlar.)")
            ]),

        DecisionCard("server-crash", category: .crisis, speaker: "Mühendislik", icon: "🔥",
            prompt: "{{project}}'in ana sunucusu çöktü. Kullanıcılar bağlanamıyor, sosyal medya kaynıyor. Her dakika {{company}}'nın itibarı eriyor.",
            trigger: .minUsers(300),
            choices: [
                .init("Herkesi çağır, gece nöbeti", detail: "+kahramanlık + öğrenme / ekip tükenmesi başlar", effects: [.cash(-5_000), .morale(-7), .reputation(5), .usersPercent(-0.03)],
                      result: "Sabah sistem ayaktaydı. (Kahramanlık kültürü kısa vadede satar, uzun vadede burnout zinciri başlatır.)"),
                .init("Failover'a geç, postmortem yap", detail: "−nakit / +sistem sağlamlığı + öğrenme dokümante", effects: [.cash(-12_000), .reputation(7), .usersPercent(-0.01)],
                      result: "Pahalıydı ama sorun hızla çözüldü. (İyi postmortem suçlama değildir; sistemin kör noktasına yatırımdır.)")
            ]),

        DecisionCard("fraud-attempt", category: .crisis, speaker: "Operasyon", icon: "🚨",
            prompt: "Biri ödeme sisteminizde açık buldu ve sahte işlemler yapıyor. Yasal süreç açacak mısın?",
            trigger: .minUsers(400),
            choices: [
                .init("Hemen engelle, hukuka bildir", detail: "+güven sinyali / −nakit + zaman", effects: [.cash(-4_000), .reputation(6), .morale(3)],
                      result: "Çabuk aksiyon. (Compliance bir yatırımdır; iyi yapılan fraud yanıtı sonraki sözleşmelerin satış argümanı olur.)"),
                .init("Sessizce engelle, monitör et", detail: "+nakit korunur / itibar bombası asılı kalır", effects: [.cash(-1_000), .reputation(-4), .morale(-1)],
                      result: "Sessiz kaldın. (Cover-up cazip görünür ama bir gün şeffaflık talebi gelir — o gün hazırlıklı değilsen kriz iki kat ağırdır.)")
            ]),

        DecisionCard("regulation-shock", category: .crisis, speaker: "Hukuk Danışmanı", icon: "⚖️",
            prompt: "Yeni bir regülasyon sektörünüzü doğrudan etkiliyor. Uyum maliyeti yüksek; geç kalma cezası daha yüksek.",
            once: true, trigger: .minStage(2),
            choices: [
                .init("Hemen uyum sağla", detail: "−nakit ağır + 1 çeyrek odak / +sektör öncülüğü", effects: [.cash(-30_000), .reputation(8), .morale(-5), .usersPercent(-0.03)],
                      result: "Sektörde öncü oldun. (Regülasyon erken uyumu rekabet engeline çevirir; geç kalan oyuncular oyun dışına atılır.)"),
                .init("Lobi yap + minimum uyum", detail: "−daha az nakit / ceza riski + politika belirsizliği", effects: [.cash(-8_000), .reputation(-3), .morale(1)],
                      result: "Süre kazandın. (Zamanı satın aldın, ama hak satın almadın; politika değişimi ya yararına ya aleyhine; kontrolün yok.)")
            ]),

        // MARK: - Takım

        DecisionCard("key-hire", category: .team, speaker: "İK", icon: "🌟",
            prompt: "Üst düzey bir mühendis ekibe katılmak istiyor ama maaş beklentisi yüksek.",
            trigger: .minStage(1),
            choices: [
                .init("İşe al, yüksek maaş ver", detail: "+kapasite + moral / burn artar + ücret çapası", effects: [.cash(-8_000), .headcount(dept: 0, delta: 1), .morale(5), .moraleTargetBonus(-1)],
                      result: "Yıldız mühendis ekipte. (İlk yüksek maaş şirketin ücret tavanını belirler; sonraki tüm hire'lar bu çapaya göre fiyatlanır.)"),
                .init("Hisse ağırlıklı teklif yap", detail: "−nakit baskısı / −%2 hisse + uzun vade hizalama", effects: [.cash(-3_000), .equity(-0.02), .headcount(dept: 0, delta: 1), .morale(3)],
                      result: "Düşük maaş, yüksek inanç. (Cap table'da küçük dilim, kasanı korur — ama dilution birikir.)")
            ]),

        DecisionCard("cofounder-conflict", category: .team, speaker: "Kurucu Ortağın", icon: "🤝",
            prompt: "Kurucu ortağınla vizyon konusunda derin bir anlaşmazlık var. O şirketi satmak istiyor, sen büyümeye devam etmek.",
            once: true, trigger: .minStage(1),
            choices: [
                .init("Uzlaş, ortak yol bul", detail: "İlişki + cap table sağlam / vizyon bulanır", effects: [.morale(-4), .reputation(3), .moraleTargetBonus(-1)],
                      result: "Anlaşma yapıldı ama ikisi de tam mutlu değil. (Yarım anlaşma uzun vadede aşınır; netlik konfordan değerlidir.)"),
                .init("Hisselerini satın al, devam et", detail: "−nakit ağır / +tek karar verici", effects: [.cash(-50_000), .equity(0.08), .morale(8), .reputation(2)],
                      result: "Pahalıydı ama şirket senin. (Co-founder buyout cap table'ı temizler; sonraki turlarda due diligence kolaylaşır.)")
            ]),

        DecisionCard("star-resign", category: .team, speaker: "Yıldız Mühendis", icon: "👋",
            prompt: "{{firstName}}, en iyi mühendisinin istifa mektubu masanda. Rakip {{sector}} şirketinden 1,5 kat maaş teklifi almış — {{project}} ekibinde boşluk büyük olur.",
            trigger: .minStage(1),
            choices: [
                .init("Karşı teklif yap", detail: "+kapasite korunur / ücret çapası yükselir + 6 ay sonra tekrar gider istatistiği", effects: [.cash(-5_000), .morale(4), .moraleTargetBonus(-1)],
                      result: "Kaldı, kıl payı. (Karşı tekliflerle kalan çalışanların %60'ı 12 ay içinde yine gider — para problemi nadiren paradır.)"),
                .init("Uğurla, referans ver", detail: "−kapasite kısa vade / +alumni ağı + ücret disiplini", effects: [.morale(-6), .reputation(4), .headcount(dept: 0, delta: -1)],
                      result: "Vedalaştınız. (Eski çalışan en iyi referans kaynağıdır; iyi ayrılış sonraki hire'ını da getirir.)")
            ]),

        DecisionCard("remote-vs-office", category: .team, speaker: "Ekip Oylaması", icon: "🏠",
            prompt: "Ekibin %60'ı tam remote istiyor. Ofis kirası yüksek. Ama yüz yüze iletişimi özlüyorsun.",
            once: true, trigger: .minStage(1),
            choices: [
                .init("Tam remote geç", detail: "+nakit + moral / spontan sinerji erir", effects: [.cash(3_000), .morale(8), .moraleTargetBonus(1)],
                      result: "Ofis kapandı. (Remote yazılı kültür ister; sözlü kültür kuran liderlerin işi şimdi iki kat zor.)"),
                .init("Hibrit model kur", detail: "Denge / maliyet orta + tam memnuniyet zor", effects: [.cash(-2_000), .morale(4), .moraleTargetBonus(0)],
                      result: "Salı-Perşembe ofis. (Hibrit en zoru: hem ofis hem remote'un dezavantajını taşır, ikisinin avantajı yarım kalır.)"),
                .init("Ofiste kal", detail: "+kültür yoğunluğu / −kira + ekip parçalanır", effects: [.cash(-3_000), .morale(-5), .reputation(2)],
                      result: "Kültür korundu ama bazıları isteksiz. (Kasıtlı kültür, ofis duvarlarına değil ritüellere dayanır.)")
            ]),

        DecisionCard("culture-values", category: .team, speaker: "İK Danışmanı", icon: "🎯",
            prompt: "Ekip büyüdükçe kültür kayıyor. Resmi değerler belgesi mi, yoksa organik kültür mü?",
            once: true, trigger: .minStage(2),
            choices: [
                .init("Değer manifestosu yaz", detail: "+kasıtlı hizalama / kâğıt üstünde kalma riski", effects: [.morale(6), .reputation(5), .cash(-2_000)],
                      result: "\"Neden buradayız?\" netleşti. (Değerler işe alım filtresi ve red sinyalidir; yazılı kültür, ölçek için altyapıdır.)"),
                .init("Organik bırak", detail: "+otantik / +tutarsız + yeni gelene öğretmek zor", effects: [.morale(3), .moraleTargetBonus(-1)],
                      result: "Kültür yaşıyor ama tutarsız. (50 kişilikten sonra organik kültür fraksiyon kültürlerine bölünür.)")
            ]),

        DecisionCard("office-move", category: .team, speaker: "Operasyon Müdürü", icon: "🏢",
            prompt: "Mevcut ofis çok küçük kaldı. Daha büyük yere taşınmak pahalı ama verimlilik acı çekiyor.",
            trigger: .minStage(2),
            choices: [
                .init("Taşın, büyük ofis al", detail: "+moral + verimlilik / −runway + kira çapası", effects: [.cash(-15_000), .morale(7), .moraleTargetBonus(1)],
                      result: "Yeni ofis açıldı. (Premature kira sözleşmesi pek çok startup'ı default-dead yapmıştır.)"),
                .init("Sıkışık kal, esnek alan kirala", detail: "+nakit korunur / −moral kademeli", effects: [.cash(-2_000), .morale(-3), .reputation(1)],
                      result: "Tasarruf ettiniz. (Sıkışık dönem ekibi birbirine yaklaştırır; sözsüz iletişim kasları gelişir.)")
            ]),

        // MARK: - Ürün & Pazar

        DecisionCard("competitor", category: .market, speaker: "Pazar Sinyali", icon: "⚔️",
            prompt: "{{sector}} pazarında bir rakip, {{project}}'in özelliğini bedavaya sundu. {{company}}'nın kullanıcıları tedirgin.",
            trigger: .minUsers(200),
            choices: [
                .init("Fiyatı düşür, yarışa gir", detail: "+kullanıcı kalır / ARPU eridi + dipe yarış", effects: [.usersPercent(0.06), .cashPercent(-0.08), .moraleTargetBonus(-1)],
                      result: "Fiyat savaşına girdin. (Race to zero kazananı yoktur; sadece dayanıklı kasalar hayatta kalır.)"),
                .init("Kalite + segmente odaklan", detail: "+itibar + sadakat / kullanıcı erimesi", effects: [.morale(5), .reputation(7), .usersPercent(-0.05)],
                      result: "\"Biz farklıyız\" dedin. (Niş uzmanlaşma, geniş bedavanın panzehridir; tüm pazara değil, doğru pazara konuş.)")
            ]),

        DecisionCard("pivot", category: .product, speaker: "Ürün Ekibi", icon: "🔀",
            prompt: "{{project}} verisi farklı bir kullanım şeklini işaret ediyor. {{firstName}}, pivot yapalım mı?",
            trigger: .minUsers(300),
            choices: [
                .init("Cesur pivot", detail: "+yeni segment + öğrenme / −kullanıcı + ekip yorgun", effects: [.usersPercent(-0.15), .reputation(6), .morale(-4), .moraleTargetBonus(2)],
                      result: "Yeni yöne döndün. (Pivot, başarısızlığın itirafı değil verinin takibidir; ama her yeni yön bir öğrenme borcu açar.)"),
                .init("Rotada kal, daha derin müşteri görüşmesi", detail: "+odak / sinyali kaçırma riski", effects: [.morale(3), .reputation(2), .moraleTargetBonus(1)],
                      result: "Mevcut planda kararlı kaldın. (Pivot etmeden önce 20 müşteriyle konuş; veri yorumlanırken sinyal-gürültü ayrılır.)")
            ]),

        DecisionCard("open-source", category: .product, speaker: "Kıdemli Mühendis", icon: "🔓",
            prompt: "Çekirdek kodunu açık kaynak yapma önerildi. Topluluğu büyütersin ama rekabet avantajın azalır.",
            once: true, trigger: .minStage(2),
            choices: [
                .init("Açık kaynak yap", detail: "+topluluk + dağıtım / monetizasyon zor + fork riski", effects: [.reputation(11), .usersPercent(0.18), .morale(4), .moraleTargetBonus(1)],
                      result: "GitHub yıldızları patladı. (Open core modelinde değer çekirdek değil, hizmettir; iyi managed cloud satıyorsan yıldız sayar.)"),
                .init("Kapalı tut, moat koru", detail: "+monetizasyon kolay + IP kontrolü / +daha az dağıtım", effects: [.reputation(3), .morale(3), .moraleTargetBonus(1)],
                      result: "Tescilli kaldı. (Moat olmadan büyümek; özellik kopyalanır, marka ve veri kopyalanmaz.)")
            ]),

        DecisionCard("pricing-change", category: .product, speaker: "Ürün & Büyüme", icon: "💰",
            prompt: "Freemium modelin çalışmıyor; bedava kullananlar ödeme yapmıyor. Fiyatı iki katına çıkar mı?",
            once: true, trigger: .minUsers(500),
            choices: [
                .init("Paywall'ı sertleştir", detail: "+gelir + ARPU netleşir / kullanıcı erimesi", effects: [.cashPercent(0.25), .usersPercent(-0.14), .reputation(-3), .moraleTargetBonus(-1)],
                      result: "Ödeyenler arttı. (Freemium dönüşmüyorsa, ödeyen segmentin gerçek değerini sakladığın için kaybediyorsundur.)"),
                .init("Freemium katmanı genişlet, upsell ekle", detail: "+kullanıcı + huni / kârlılık uzak", effects: [.usersPercent(0.12), .cashPercent(-0.04), .morale(3), .reputation(4)],
                      result: "Büyüme devam etti. (Freemium dağıtım kanalıdır, ürün değil; ödeyene gerçek değer paketi şart.)")
            ]),

        DecisionCard("feature-request-flood", category: .product, speaker: "Destek Ekibi", icon: "📬",
            prompt: "Kullanıcılar yüzlerce farklı özellik istiyor. Roadmap dağılıyor. Focus mu, herkesi mutlu et mi?",
            trigger: .minUsers(400),
            choices: [
                .init("Tek özelliğe odaklan", detail: "+derinlik / kısa vade memnuniyetsizlik", effects: [.morale(5), .reputation(6), .usersPercent(-0.05)],
                      result: "\"Daha az, daha iyi\" kararı verildi. (Hayır demek bir ürün stratejisidir; kullanıcı sesini dinle ama emrini değil.)"),
                .init("Top 3'ü yap", detail: "+kısa vade memnuniyet / ekip yorgun + roadmap dağılır", effects: [.usersPercent(0.08), .morale(-5), .cash(-6_000)],
                      result: "Kullanıcılar memnun ama ekip yorgun. (Müşteri talebinin %20'si değerin %80'ini taşır; geri kalanı listenin sonunda kalmalı.)")
            ]),

        DecisionCard("b2b-opportunity", category: .product, speaker: "Potansiyel Kurumsal Müşteri", icon: "🏗️",
            prompt: "Büyük bir kurumsal müşteri ürünü B2B olarak kullanmak istiyor. Ama B2C odağını bozacak.",
            once: true, trigger: .minStage(2),
            choices: [
                .init("B2B kolunu aç", detail: "+büyük nakit + sözleşme / −odak + custom roadmap", effects: [.cash(80_000), .headcount(dept: 3, delta: 1), .morale(-4), .reputation(5)],
                      result: "Yeni gelir kapısı açıldı. (B2B çek getirir, B2C ölçek getirir; iki motoru aynı anda çalıştırmak iki ürün ekibi ister.)"),
                .init("B2C'de kal, reddet", detail: "+odak korunur / büyük nakit kayboldu", effects: [.morale(4), .reputation(3), .moraleTargetBonus(1)],
                      result: "Vizyon korundu. (Strategic partnership trap: tek büyük müşteri için yapılan custom, ürünün kendi yönünü kaybeder.)")
            ]),

        // MARK: - Pazar & Büyüme

        DecisionCard("viral-tiktok", category: .market, speaker: "Sosyal Medya", icon: "📱",
            prompt: "Bir içerik üreticisi ürününü videoya koydu ve video patladı!",
            trigger: .minUsers(100),
            choices: [
                .init("Anı yakala, sunucu + onboarding'i bük", detail: "+kullanıcı patlaması / −nakit + retention belirsiz", effects: [.usersPercent(0.5), .cash(-4_000), .reputation(5), .morale(-2)],
                      result: "Büyüme muazzam. (Viral kullanıcı sadık kullanıcı değildir; D30'da kaç kişi kaldığı asıl sayıdır.)"),
                .init("Organik bırak", detail: "+nakit korunur / +daha az hız", effects: [.usersPercent(0.18), .morale(2), .moraleTargetBonus(1)],
                      result: "Dalga kendiliğinden yayıldı. (Yakalanmayan dalga kaybedilmiş değildir; başka dalga gelir, sürdürülebilir tempoyu koru.)")
            ]),

        DecisionCard("growth-hack", category: .market, speaker: "Büyüme Ekibi", icon: "🚀",
            prompt: "Referral sistemi önerildi: her davet için kullanıcıya kredi ver. Maliyet yüksek ama büyüme hızlanır.",
            trigger: .minUsers(200),
            choices: [
                .init("Referral başlat", detail: "+hızlı kullanıcı / −nakit + kalitesiz davetli riski", effects: [.usersPercent(0.3), .cash(-10_000), .reputation(3), .moraleTargetBonus(-1)],
                      result: "Davet zinciri başladı. (Para için davet edilen kullanıcının LTV'si genellikle CAC'i karşılamaz; metriği takip et.)"),
                .init("Organik + içerik büyüme", detail: "+sürdürülebilir / −hız", effects: [.morale(3), .reputation(4), .usersPercent(0.05)],
                      result: "Yavaş ama sağlıklı büyüme. (Organik kullanıcı CAC ile satın alınmaz, içerikle çekilir; arketibin Bootstrap-Frugal'sa bu senin patikan.)")
            ]),

        DecisionCard("international-launch", category: .market, speaker: "Büyüme Stratejisti", icon: "🌍",
            prompt: "Avrupa pazarından yoğun ilgi var. Lokalizasyon ve hukuki uyum çok maliyetli ama potansiyel büyük.",
            once: true, trigger: .minStage(3),
            choices: [
                .init("Avrupa'ya aç", detail: "+pazar büyüklüğü / −nakit + GDPR yükü", effects: [.cash(-40_000), .usersPercent(0.25), .reputation(8), .headcount(dept: 2, delta: 1), .morale(-3)],
                      result: "Uçuş başladı. (Premature internationalization: ana pazarda PMF yokken ikinciye girmek odağı ikiye böler.)"),
                .init("Önce yurt içini doyur", detail: "+derinlik / büyük fırsat ertelenir", effects: [.morale(5), .reputation(3), .usersPercent(0.05)],
                      result: "Temeli sağlamlaştırdın. (Bir pazarda baskınlık, iki pazarda ortalıkta olmaktan değerlidir.)")
            ]),

        DecisionCard("ad-spend-temptation", category: .market, speaker: "Pazarlama Danışmanı", icon: "📊",
            prompt: "Meta reklamlarına büyük bütçe bas: CAC yüksek ama bilinirlik patlayabilir. Risk almaya hazır mısın?",
            trigger: .minStage(1),
            choices: [
                .init("Agresif reklam bas", detail: "+hızlı kullanıcı / −nakit + CAC>LTV riski", effects: [.usersPercent(0.32), .cash(-20_000), .reputation(2), .moraleTargetBonus(-1)],
                      result: "Kullanıcılar geldi ama CAC acıtıyor. (LTV bilinmeden ad spend, ısınan veriden geleceği okumaktır; önce kohort verisi, sonra ölçek.)"),
                .init("İçerik + topluluk büyütme", detail: "+düşük CAC / −yavaş hız", effects: [.usersPercent(0.1), .reputation(7), .cash(-3_000), .morale(3)],
                      result: "Yavaş ama organik. (İçerik birikim varlığıdır; reklam kiradır — biri bırakırsa söner, diğeri bırakırsan kalır.)")
            ]),

        // MARK: - Fırsatlar

        DecisionCard("acquihire", category: .opportunity, speaker: "Büyük Şirket", icon: "🏢",
            prompt: "Büyük bir şirket küçük ekibini satın almak istiyor. Erken çıkış mı, devam mı?",
            once: true, trigger: .minStage(2),
            choices: [
                .init("Nakit teklifi al", detail: "+kişisel exit + yumuşak iniş / vizyon kapanır", effects: [.cash(200_000), .reputation(-4), .moraleTargetBonus(-2)],
                      result: "Büyük çek geldi. (Acquihire başarısızlık değil, ekibinin tercihen değer biçilmesidir; kasanın küçükse kötü pazarlık yapar.)"),
                .init("Reddet, büyü", detail: "+moral + bağımsızlık / kasa kuruyabilir", effects: [.morale(7), .reputation(8), .moraleTargetBonus(1)],
                      result: "Ekip coştu. (\"Hayır\" demek bir bahistir; bir sonraki tura ulaşamazsan, ret pahalıya patlar.)")
            ]),

        DecisionCard("acquisition-offer", category: .opportunity, speaker: "Stratejik Alıcı", icon: "💎",
            prompt: "Sektörün büyük oyuncusu $5 milyon teklif etti. Ekip ikiye bölündü: satış mı, bağımsızlık mı?",
            once: true, trigger: .minStage(4),
            choices: [
                .init("Sat, çıkış yap", detail: "+büyük exit / vizyon kapanır + ekip dağılır", effects: [.cash(5_000_000), .equity(0.10), .morale(-8), .reputation(4)],
                      result: "Çek imzalandı. (En iyi satış kararı en kötü pazarlık koşulundayken alınmaz; \"satılık değil\" havası fiyatı artırır.)"),
                .init("Reddet, ilerle", detail: "+ekip + vizyon / bir sonraki teklif gelmeyebilir", effects: [.morale(11), .reputation(10), .moraleTargetBonus(2)],
                      result: "\"Biz satılık değiliz\". (Reddedilen exit teklifleri, gelecekte aynı fiyata gelmeyebilir; bu da bir trade-off.)")
            ]),

        DecisionCard("partnership-offer", category: .opportunity, speaker: "Stratejik Ortak", icon: "🤝",
            prompt: "Büyük bir platform entegrasyon ortaklığı teklif ediyor. Dağıtım kazanırsın ama bağımlı kalırsın.",
            once: true, trigger: .minStage(2),
            choices: [
                .init("Ortaklığı kur", detail: "+dağıtım + hız / platform kuralı değiştirirse kanal kapanır", effects: [.usersPercent(0.22), .reputation(6), .morale(4), .moraleTargetBonus(-1)],
                      result: "Yeni kitlelere ulaştın. (Platform riski: tek kanaldan gelen kullanıcı, platformun politikasıyla bir gecede gidebilir.)"),
                .init("Bağımsız kal", detail: "+kendi kanalın / dağıtım kaybedildi", effects: [.morale(5), .reputation(4), .usersPercent(0.04)],
                      result: "Serbest kaldın. (Sahip olduğun kanal, kiraladığın kanaldan değerlidir; yavaş ama dayanıklı.)")
            ]),

        DecisionCard("accelerator-invite", category: .opportunity, speaker: "Hızlandırıcı Program", icon: "🎓",
            prompt: "Prestijli bir hızlandırıcıdan davet geldi: $120K nakit + mentorluk, karşılığında %7 hisse.",
            once: true,
            choices: [
                .init("Katıl", detail: "+nakit + ağ + Demo Day / −%7 + 3 ay odak dağılır", effects: [.cash(120_000), .equity(-0.07), .reputation(12), .moraleTargetBonus(2), .morale(-2)],
                      result: "Demo Day yaklaşıyor. (Hızlandırıcının değeri parada değil ağdadır; mentor erişimi tek başına %7'yi kurtarabilir.)"),
                .init("Reddet, kendi yolun", detail: "Hisse korunur / ağ kayboldu", effects: [.morale(5), .reputation(2), .moraleTargetBonus(1)],
                      result: "Bağımsız kalmayı seçtin. (PMF'i bulduysan accelerator yavaşlatıcıya dönüşebilir; her şirketin doğru zamanı farklı.)")
            ]),

        DecisionCard("grant-opportunity", category: .opportunity, speaker: "Devlet Fonu", icon: "🏛️",
            prompt: "Kamu destekli bir hibe programı için başvurabilirsin: $80K hibe ama bürokratik süreç uzun.",
            trigger: .minStage(1),
            choices: [
                .init("Başvur, uğraş", detail: "+dilution'sız nakit / −kurucu zamanı + raporlama yükü", effects: [.cash(80_000), .morale(-5), .reputation(4), .usersPercent(-0.02)],
                      result: "Hibe geldi! (Bedelsiz para yoktur; hibenin fiyatı kurucu zamanıdır ve compliance defteridir.)"),
                .init("Zamanına değmez, ürüne odaklan", detail: "+odak / +nakit kayboldu", effects: [.morale(3), .reputation(1), .usersPercent(0.04)],
                      result: "O zamanı ürüne harcadın. (Kurucunun zamanı en pahalı kaynaktır; dilution değil, dikkat dağıtmak öldürür.)")
            ]),

        // MARK: - Ölçek & Altyapı

        DecisionCard("scaling-crisis", category: .crisis, speaker: "Altyapı Ekibi", icon: "📈",
            prompt: "Kullanıcı sayısı patladı ama mimari kaldıramıyor. Her gün 3 kez çöküyor. Teknik borç kapıyı tekmeliyor.",
            trigger: .minUsers(2_000),
            choices: [
                .init("Mimariyi yeniden yaz", detail: "−nakit + 1 çeyrek hız / +sağlamlık", effects: [.cash(-25_000), .morale(-5), .reputation(6), .usersPercent(-0.04)],
                      result: "Acı bir refactor turu. (Borcu temizlerken faiziniz kalkar; refactor sırasında kullanıcı kaybı doğal.)"),
                .init("Yama üstüne yama", detail: "+hız korunur / sonraki çöküş zaman meselesi", effects: [.cash(-5_000), .reputation(-4), .morale(-4), .usersPercent(-0.02)],
                      result: "Bant yapıştırdın. (Teknik borç faizle birikir; bugün ödememek, yarın daha büyük ödemek demektir.)")
            ]),

        DecisionCard("cloud-bill-shock", category: .crisis, speaker: "Mali İşler", icon: "☁️",
            prompt: "Bulut faturası bir gecede 4 katına çıktı; bir job sonsuz döngüye girmiş. Nakit eriyor.",
            trigger: .minUsers(1_000),
            choices: [
                .init("Acil FinOps + alarm sistemi", detail: "−mühendis haftası / +sürdürülebilir maliyet", effects: [.cash(-8_000), .morale(-4), .reputation(3), .usersPercent(-0.02)],
                      result: "Harcama dizginlendi. (Bulut faturasını izlemeyen, runway'ini sessizce yakar; ölçüm ilk savunma hattıdır.)"),
                .init("Geçici cap koy, devam et", detail: "+hız korunur / dümen çürür", effects: [.cashPercent(-0.10), .morale(1), .moraleTargetBonus(-1)],
                      result: "Fatura sızdırmaya devam. (Görünmeyen burn, görünen burn'den tehlikelidir; sızıntı ay sonu sürprizi olur.)")
            ]),

        DecisionCard("technical-debt-vote", category: .product, speaker: "Mühendislik Lideri", icon: "🧱",
            prompt: "Ekip iki çeyrektir özellik fışkırttı, hiç temizlik yapmadı. Bir sprint'i tamamen borç ödemeye ayıralım mı?",
            trigger: .minStage(2),
            choices: [
                .init("Temizlik sprint'i", detail: "+moral + sağlamlık / 1 sprint hız kaybı", effects: [.morale(6), .reputation(3), .usersPercent(-0.03)],
                      result: "Build artık yeşil. (Bir sprintlik temizlik bir çeyreklik krizi önler — bu basit bir faiz hesabı.)"),
                .init("Özellik basmaya devam, sonraya bırak", detail: "+kullanıcı + roadmap / faiz birikir", effects: [.usersPercent(0.06), .morale(-5), .reputation(-2)],
                      result: "Roadmap doldu. (Bazen pazar penceresi teknik borçtan değerlidir; bilinçli borç stratejidir, ihmal borçsa intihardır.)")
            ]),

        // MARK: - Müşteri & Gelir Krizleri

        DecisionCard("whale-churn", category: .crisis, speaker: "Müşteri Başarısı", icon: "🐋",
            prompt: "Gelirinin %30'unu tek başına getiren en büyük kurumsal müşterin sözleşmeyi yenilemiyor.",
            trigger: .minStage(2),
            choices: [
                .init("CEO seviyesinde kurtarma", detail: "+gelir kaldı / −yol haritası bükülür + custom borç", effects: [.cash(-12_000), .reputation(4), .morale(2), .moraleTargetBonus(-1)],
                      result: "Kaldılar — kıl payı. (Whale'i tutmak gelir kurtarır ama yol haritanı esir alır; bir sonraki anlaşmada kapan açılır.)"),
                .init("Bırak gitsin, segmenti çeşitlendir", detail: "−büyük gelir / +sağlıklı dağılım", effects: [.cashPercent(-0.22), .morale(-4), .reputation(3), .moraleTargetBonus(2)],
                      result: "Tek müşteriye bağımlılık dersini öğrendin. (10 küçük müşteri 1 büyükten daha sağlam bir gelir; concentration risk bir gece sinyali olmadan vurur.)")
            ]),

        DecisionCard("pricing-experiment", category: .product, speaker: "Büyüme Ekibi", icon: "🧪",
            prompt: "Kullanıcıların yarısına %40 daha yüksek fiyat gösteren bir A/B testi öneriliyor. Etik mi, akıllı mı?",
            trigger: .minUsers(1_500),
            choices: [
                .init("Testi başlat, veriye bak", detail: "+fiyat esnekliği verisi / −şeffaflık + sosyal kriz riski", effects: [.cashPercent(0.10), .reputation(-4), .morale(-1)],
                      result: "Fiyat esnekliği netleşti. (A/B fiyat testi öğretir ama sızarsa marka erozyonu uzun sürer; segmente göre fiyatlandırma daha sürdürülebilirdir.)"),
                .init("Açık değer paketleri kur", detail: "+güven + yeni katman / −optimizasyon hızı", effects: [.cashPercent(0.05), .reputation(6), .morale(3)],
                      result: "Şeffaf paketlere geçtin. (Pricing power testin değer iletişimindendir; aynı kullanıcıya iki fiyat değil, iki kullanıcıya iki paket.)")
            ]),

        DecisionCard("enterprise-rfp", category: .opportunity, speaker: "Satış Direktörü", icon: "📑",
            prompt: "Devasa bir kurumun ihalesini kazanmak üzeresin ama 6 aylık özel entegrasyon ve SOC2 sertifikası istiyorlar.",
            once: true, trigger: .minStage(3),
            choices: [
                .init("İhaleye gir, kaynağı ayır", detail: "+büyük çek + logo / −6 ay odak + custom borç", effects: [.cash(150_000), .headcount(dept: 3, delta: 1), .morale(-5), .reputation(8), .moraleTargetBonus(-1)],
                      result: "Logoyu kazandın. (Tek büyük kontrat kasayı doldurur ama ürünü iki yönde çeker; SOC2 yatırımı sonraki müşterilere de açıktır — yatırım mı borç mu, kullanım belirler.)"),
                .init("Vazgeç, ürüne odaklan", detail: "+odak korunur / +büyük nakit kayboldu", effects: [.morale(4), .reputation(2), .usersPercent(0.04)],
                      result: "Kısa vadeli cazibeye direndin. (Enterprise satış 18 ay sürer; bu pencerede ürün-pazar uyumun derinleşir.)")
            ]),

        // MARK: - Kurucu & İnsan

        DecisionCard("founder-burnout", category: .team, speaker: "İç Ses", icon: "🪫",
            prompt: "Aylardır uyumuyorsun. Ellerin titriyor, kararların bulanık. Bedenin dur diyor.",
            trigger: .lowMorale(40),
            choices: [
                .init("Bir hafta tamamen kopart", detail: "+karar kalitesi + uzun vade moral / 1 hafta hız kaybı", effects: [.morale(13), .moraleTargetBonus(2), .usersPercent(-0.02)],
                      result: "Dinlenmiş bir zihinle döndün. (Kurucu tükenirse şirket tükenir; istirahat üretkenlik aleyhine değil, lehinedir.)"),
                .init("İçeceğe devam, dişini sık", detail: "+kısa vade çıktı / yargı bulanıklığı + uzun vade çöküş", effects: [.morale(-9), .usersPercent(0.04), .reputation(-2)],
                      result: "Bir sprint daha. (Tükenmiş kurucunun verdiği kararlar ortalama kötüdür; öğrenmek için yargı netliği şarttır.)")
            ]),

        DecisionCard("cofounder-departure", category: .team, speaker: "Kurucu Ortağın", icon: "🚪",
            prompt: "Kurucu ortağın \"ben yokum\" dedi ve ayrılıyor. Cap table'da %20'si var. Ekip sarsıldı.",
            once: true, trigger: .minStage(2),
            choices: [
                .init("Adil vesting ile uğurla", detail: "−nakit + +%12 hisse + temiz ayrılık / kısa moral darbesi", effects: [.cash(-30_000), .equity(0.12), .morale(-5), .reputation(5)],
                      result: "Dostça ayrılık. (Cap table sağlığı bir sonraki turun ön koşuludur; due diligence eski ortağın imzasını arar.)"),
                .init("Hukuki kavgaya gir", detail: "+%18 hisse savaşı / −moral + itibar + zaman", effects: [.equity(0.18), .morale(-13), .reputation(-9)],
                      result: "Mahkeme uzadı. (Hukuk yolu hak getirir ama yatırımcılar 'mahkemelik kurucu' notu görünce kapıyı kapatır.)")
            ]),

        DecisionCard("talent-raid", category: .team, speaker: "Rakip CEO", icon: "🎯",
            prompt: "Rakip şirket en iyi 3 mühendisine aynı anda agresif teklifler yaptı. Kapıdan kaçacaklar.",
            trigger: .minStage(2),
            choices: [
                .init("Hisse + maaş paketiyle tut", detail: "+kapasite + sadakat / −nakit + −%3 + ücret tavanı kayar", effects: [.cash(-10_000), .equity(-0.03), .morale(7), .moraleTargetBonus(-1)],
                      result: "Üçü de kaldı. (İnsanlar para için kalır, anlam için büyür; karşı teklif geçici bir kazanım.)"),
                .init("Hisse vermeden vizyon konuş, kararı onlara bırak", detail: "+nakit korunur / kapasite riski", effects: [.headcount(dept: 0, delta: -1), .morale(-3), .reputation(3)],
                      result: "Vizyonla konuştun. (Talent'i hisseyle değil sebeplerle tutmak daha uzun ömürlü; gidenlerin gitmesi de ekibe iyi gelir.)")
            ]),

        DecisionCard("diversity-push", category: .team, speaker: "İK & Kültür", icon: "🌈",
            prompt: "Ekip tek tip oldu. Bilinçli çeşitlilik programı zaman ve para ister ama uzun vadede daha güçlü kararlar getirir.",
            once: true, trigger: .minStage(2),
            choices: [
                .init("Programı başlat", detail: "−nakit + ilk hire yavaş / +karar kalitesi + itibar", effects: [.cash(-6_000), .morale(6), .reputation(6), .moraleTargetBonus(1)],
                      result: "Farklı sesler masada. (Çeşitli ekip kör nokta sayısını azaltır; daha iyi ürün, daha az tasarım hatası.)"),
                .init("Sonraya bırak, organic büyüt", detail: "+kısa vade odak / kültür kemikleşir", effects: [.morale(-3), .moraleTargetBonus(-1)],
                      result: "\"Önce büyüyelim\" dedin. (Kültür ilk 20 hire'da donar; sonra değiştirmek 10x maliyet ister.)")
            ]),

        // MARK: - Regülasyon & Hukuk

        DecisionCard("gdpr-audit", category: .crisis, speaker: "Veri Koruma Otoritesi", icon: "📜",
            prompt: "Bir veri koruma otoritesi denetim başlattı. Eksiklerin var; ceza ciro bazlı olabilir.",
            trigger: .minUsers(3_000),
            choices: [
                .init("Tam uyum, danışman tut", detail: "−nakit ağır / +sertifika satış kapısı", effects: [.cash(-22_000), .reputation(8), .morale(-3)],
                      result: "Temiz çıktın. (Compliance bir gider değil, kurumsal müşteri için kapı anahtarıdır.)"),
                .init("Minimum düzeltme yap", detail: "−nakit az / büyük ceza riski sürer", effects: [.cash(-5_000), .reputation(-6), .morale(-3)],
                      result: "Şimdilik geçtin. (Regülasyon riski 'kazansak olur' diye bahse girilmez; sonradan ödenen ceza kapatma ücretidir.)")
            ]),

        DecisionCard("patent-troll", category: .crisis, speaker: "Hukuk Müşaviri", icon: "📿",
            prompt: "Bir patent trolü çekirdek özelliğin için ihlal davası açtı. Davalar yıllarca sürer ve yorar.",
            trigger: .minStage(3),
            choices: [
                .init("Mahkemede savaş", detail: "−nakit + 18 ay yıpranma / +emsal + caydırıcılık", effects: [.cash(-18_000), .reputation(5), .morale(-5), .usersPercent(-0.02)],
                      result: "Trolü püskürttün. (Bir kez ödersen liste başısın; mahkeme uzun, ama uzun vadeli koruma.)"),
                .init("Sus payı öde, kurtul", detail: "−nakit hızlı / iştahları açar + tekrar saldırı", effects: [.cash(-12_000), .reputation(-4), .morale(-2)],
                      result: "Sorun kapandı. (Erken aşamada zaman bütçenden yıpratıcı bir mahkeme savaşı daha pahalı olabilir; bağlam doğru karara karar verir.)")
            ]),

        DecisionCard("ip-ownership", category: .crisis, speaker: "Eski Çalışan", icon: "©️",
            prompt: "Erken dönem bir geliştirici, kodun bir kısmının kendisine ait olduğunu iddia ediyor. Sözleşme belirsizdi.",
            once: true, trigger: .minStage(2),
            choices: [
                .init("Adil bedel öde, hakları al", detail: "−nakit / +temiz IP + due diligence kolayı", effects: [.cash(-15_000), .reputation(3), .morale(2)],
                      result: "Fikri mülkiyet tartışmasız şirketin. (Sözleşmesiz kod, sahibi belirsiz koddur; IP düğümünü erken çöz.)"),
                .init("Reddet, riske gir", detail: "+nakit korunur / DD'de bulut + sonraki tur riski", effects: [.reputation(-5), .morale(-4), .moraleTargetBonus(-1)],
                      result: "Tehdit havada asılı. (Yatırımcılar IP bulutlarına alerjik; bir sonraki due diligence'ta bu kalem alarm yakar.)")
            ]),

        // MARK: - Basın & Kriz

        DecisionCard("pr-scandal", category: .press, speaker: "İletişim Direktörü", icon: "🎤",
            prompt: "Bir çalışanın eski tweet'leri ortaya çıktı ve şirketle ilişkilendiriliyor. Sosyal medyada linç başladı.",
            trigger: .minReputation(40),
            choices: [
                .init("Net açıklama, değerleri vurgula", detail: "+itibar uzun vade / −moral içeride", effects: [.reputation(6), .morale(-4), .usersPercent(-0.02)],
                      result: "Yanıt fırtınayı dindirdi. (Kriz iletişiminde ilk 24 saat kontrolü belirler; netlik suskunluğa baskındır.)"),
                .init("İç soruşturma başlat, kısa açıklama", detail: "+süreç güveni / dış basınç sürer", effects: [.reputation(-4), .morale(2), .moraleTargetBonus(0)],
                      result: "Süreci başlattın. (Bazen erken açıklama daha çok zarar verir; süreç sinyali olgunluk gösterir, ama yavaşlık linçi büyütür.)")
            ]),

        DecisionCard("influencer-backfire", category: .press, speaker: "Pazarlama", icon: "💥",
            prompt: "Anlaştığın bir influencer başka bir skandala karıştı ve markanla birlikte anılıyor. Kampanya yarıda.",
            trigger: .minUsers(800),
            choices: [
                .init("Sözleşmeyi hemen bitir, duyur", detail: "−nakit / +itibar + temiz pozisyon", effects: [.cash(-7_000), .reputation(5), .usersPercent(-0.02)],
                      result: "Hızlı mesafe koydun. (İnfluencer'ın itibarı senin itibarındır; iyi seç, gerekiyorsa hızlı ayır.)"),
                .init("Sessizce sözleşmeyi bitir", detail: "+nakit korunur / +itibar uzun vade riski", effects: [.reputation(-3), .cash(-2_000), .morale(-1)],
                      result: "Az konuştun. (Bazen sessizlik en az kötü cevaptır; konuşmak haberi büyüten Streisand etkisi olabilir.)")
            ]),

        DecisionCard("misinformation-wave", category: .press, speaker: "Topluluk Yöneticisi", icon: "📢",
            prompt: "Ürün hakkında yanlış bir iddia viral oldu: \"Verilerinizi satıyorlar.\" Doğru değil ama yayılıyor.",
            trigger: .minUsers(1_000),
            choices: [
                .init("Şeffaf rapor + açık veri politikası", detail: "−nakit / +güven uzun vade", effects: [.cash(-3_000), .reputation(7), .morale(3)],
                      result: "İddia çürüdü. (Şeffaflık en ucuz PR kanalıdır; veri belgesi sonraki krizlere de gönderme yapılabilen bir varlık.)"),
                .init("Topluluk elçilerinden yanıt", detail: "+ucuz / kontrolsüz mesaj riski", effects: [.reputation(-2), .morale(2), .usersPercent(-0.02)],
                      result: "Topluluk konuştu. (Topluluk kendini savunur ama mesaj kontrolden çıkabilir; resmi ses ile dengele.)")
            ]),

        // MARK: - Yatırımcı & Board

        DecisionCard("board-pressure", category: .investor, speaker: "Yönetim Kurulu", icon: "🪑",
            prompt: "Board, kârlılık için ekibin %20'sini çıkarmanı istiyor. Sen kültürü korumak istiyorsun.",
            trigger: .minStage(3),
            choices: [
                .init("Hedefli küçülme yap", detail: "+runway uzar / −moral ağır + tedbir kültürü oturur", effects: [.cashPercent(0.15), .headcount(dept: 4, delta: -1), .morale(-9), .reputation(-2)],
                      result: "Runway uzadı ama yaralar kaldı. (Layoff'un timing'i her şeydir; geç kalan layoff iki kez yapılır.)"),
                .init("Gelir planı sun, board'u ikna et", detail: "+moral korunur / board gerilimi + sözleşme riski", effects: [.morale(7), .reputation(3), .cashPercent(-0.04), .moraleTargetBonus(-1)],
                      result: "Board'u ikna ettin — bu sefer. (Board veriyle ikna olur; vaat 6 ay sonra teslim edilmezse güven katmerli erir.)")
            ]),

        DecisionCard("strategic-investor", category: .investor, speaker: "Kurumsal Yatırımcı", icon: "🏦",
            prompt: "Büyük bir kurum stratejik yatırım teklif ediyor: bol nakit ama rakiplerinle çalışmanı kısıtlayan maddeler içeriyor.",
            once: true, trigger: .minStage(3),
            choices: [
                .init("Stratejik parayı al", detail: "+büyük nakit / −esneklik + rakip yasağı + exit kısıtı", effects: [.cash(800_000), .equity(-0.10), .reputation(6), .moraleTargetBonus(-2)],
                      result: "Kasan doldu, bazı kapılar kapalı. (Stratejik para hızlıdır ama bağlar getirir; right of first refusal bir exit'i 2 yıl erteleyebilir.)"),
                .init("Finansal yatırımcı ara", detail: "−daha az nakit + −süreç uzun / +özgürlük", effects: [.cash(400_000), .equity(-0.08), .morale(4), .moraleTargetBonus(1)],
                      result: "Daha az nakit, daha az kısıt. (Bağsız sermaye genelde en pahalı sermaye; ama uzun vade çoklu strateji için açık kalır.)")
            ]),

        DecisionCard("secondary-sale", category: .investor, speaker: "Yatırımcın", icon: "💵",
            prompt: "Yatırımcın, kişisel hisselerinin bir kısmını satıp nakit çekmen için secondary sunuyor: ev al, rahatla.",
            once: true, trigger: .minStage(4),
            choices: [
                .init("Biraz hisse sat, güvene al", detail: "+kişisel finansal güvence / −%4 + inanç sinyali zayıflar", effects: [.equity(-0.04), .cash(200_000), .morale(9), .reputation(-3)],
                      result: "Cebine para girdi. (Kişisel risk azaltma ile yargı netliği sağlanır; tükenmiş kurucudan daha kötü hiçbir CEO yoktur.)"),
                .init("Hepsini şirkette tut", detail: "+inanç sinyali + cap table güçlü / kişisel finansal stres", effects: [.morale(4), .reputation(7), .moraleTargetBonus(-1)],
                      result: "\"Tek kuruş çıkarmıyorum\" dedin. (Kurucu konsantrasyonu uzun vade upside ama kişisel hayat finansal baskı altında.)")
            ]),

        // MARK: - Pazar & Makro

        DecisionCard("market-downturn", category: .crisis, speaker: "Makro Ekonomi", icon: "🌪️",
            prompt: "Piyasa çöküyor. Yatırım musluğu kurudu, müşteriler bütçe kesiyor. Kış geliyor.",
            once: true, trigger: .minStage(3),
            choices: [
                .init("Default-alive moduna geç", detail: "+runway uzar / −büyüme dondu", effects: [.cashPercent(0.1), .usersPercent(-0.05), .morale(-3), .reputation(4)],
                      result: "Harcamayı kıstın. (Downturn'da en güçlü silah disiplindir; hayatta kalan herkes sonraki upturn'ün galibi olabilir.)"),
                .init("Karşı-döngü büyü, pay kap", detail: "+kullanıcı + ucuz CAC / −nakit + risk = sonra köprü", effects: [.usersPercent(0.18), .cashPercent(-0.18), .reputation(5), .moraleTargetBonus(-1)],
                      result: "Herkes saklanırken sen saldırdın. (Kasası dolu olanlar için downturn fırsat; kasanı yanlış okursan ertesi çeyrek payroll-risk kartı bekler.)")
            ]),

        DecisionCard("copycat-clone", category: .market, speaker: "Pazar İstihbaratı", icon: "👯",
            prompt: "İyi finanse edilmiş bir klon ürününü birebir kopyaladı ve agresif pazarlama yapıyor.",
            trigger: .minUsers(2_000),
            choices: [
                .init("Markaya ve topluluğa yaslan", detail: "+itibar + sadakat / hız savaşını kaybetme riski", effects: [.reputation(7), .morale(6), .usersPercent(-0.03)],
                      result: "Sadık topluluk sahip çıktı. (Klonlar özelliği kopyalar ama topluluğu, markayı ve veriyi kopyalayamaz.)"),
                .init("Özellik hızında yarış", detail: "+kullanıcı korunur / −moral + ekip yorgun", effects: [.usersPercent(0.08), .cash(-8_000), .morale(-5), .moraleTargetBonus(-1)],
                      result: "Hız savaşı. (Feature parity oyunu bitiren değildir; daha derin değer, daha iyi yanıt.)")
            ]),

        DecisionCard("viral-moment", category: .opportunity, speaker: "Büyüme Ekibi", icon: "🎆",
            prompt: "Bir haber döngüsü tam ürününün konusu hakkında; 24 saatlik bir viral pencere var. Hazır mısın?",
            trigger: .minUsers(500),
            choices: [
                .init("Tüm gücü pazarlamaya ver", detail: "+büyük kullanıcı + ücretsiz dikkat / nakit yanar + ekip tükeniyor", effects: [.usersPercent(0.35), .cash(-9_000), .reputation(6), .morale(-4)],
                      result: "Trafik tavan yaptı. (Dikkat ekonomisinde 24 saatlik pencereler nadir; ama yorgun ekip ürünü çuvallarsa eksi puan kalır.)"),
                .init("Hazırla, organik bırak", detail: "+sürdürülebilir / büyük dalgayı kaçırma", effects: [.usersPercent(0.1), .reputation(4), .morale(3)],
                      result: "Bir kısmını aldın. (Dalgayı kaçırmak başarısızlık değildir; her viral nokta retention'ı kanıtlamayı zorunlu kılar.)")
            ]),

        DecisionCard("supply-dependency", category: .crisis, speaker: "Operasyon", icon: "🔗",
            prompt: "Tek tedarikçin olan bir API sağlayıcısı fiyatları 3 katına çıkardı ve sözleşmeyi tek taraflı değiştirdi.",
            trigger: .minStage(2),
            choices: [
                .init("Kendi çözümünü inşa et", detail: "−nakit ağır + 1 çeyrek hız / +tam kontrol", effects: [.cash(-18_000), .morale(-4), .reputation(5), .usersPercent(-0.02)],
                      result: "Acı bir çeyrek. (Tek tedarikçi platform riskidir; sahip olduğun kanal kiraladığından değerlidir.)"),
                .init("Yeni fiyatı yut, alternatif ara", detail: "+kısa vade hız korunur / sürekli marj erozyonu", effects: [.cashPercent(-0.10), .morale(-1), .moraleTargetBonus(-1)],
                      result: "Ödedin. (Kılıç tepende: 'şimdi nakit zamanı, sonra kaçma planı' bilinçli bir taktiktir; bilinçsizse pasif tuzaktır.)")
            ]),

        // MARK: - PMF Hipotezi & Müşteri Keşfi

        DecisionCard("pmf-hypothesis-width", category: .product, speaker: "Ürün Yöneticisi", icon: "🧭",
            prompt: "Yeni özelliği test etmek için iki yol var: 5 müşteriyle derin görüşme + prototip, ya da 50 müşteriye ankette gösterip metriklere bakmak.",
            trigger: .minUsers(150),
            choices: [
                .init("5 müşteriyle derinleş", detail: "+yüksek sinyal kalitesi / örneklem küçük + yanlılık", effects: [.morale(4), .reputation(3), .usersPercent(-0.01)],
                      result: "İçgörü derindi. (5 kullanıcıyla 10 saat, 50 kullanıcıyla 10 dakikadan değerlidir; PMF anketle değil, samimi sohbetle bulunur.)"),
                .init("50 müşteriyle ölçekli test", detail: "+istatistik / +yüzeysel sinyal + güncel davranışı kaçırma", effects: [.usersPercent(0.04), .reputation(2), .morale(-2)],
                      result: "Veri geldi. (Geniş test, niş insight'ı kaçırır; ölçek doğru soru sonrası anlamlı.)")
            ]),

        DecisionCard("d7-retention-drop", category: .crisis, speaker: "Analitik Ekibi", icon: "📉",
            prompt: "D7 retention son iki ay %30'dan %18'e düştü. Onboarding'i mi elden geçirmeli, yoksa pivot mu konuşmalı?",
            trigger: .minUsers(800),
            choices: [
                .init("Onboarding'i yeniden tasarla", detail: "+ürün hipotezini koru / +1 çeyrek iş + sinyali yanlış okuma riski", effects: [.cash(-6_000), .morale(2), .reputation(3), .usersPercent(-0.03)],
                      result: "Akış değiştirildi. (Retention sorunu çoğunlukla 'değer' değil 'değer iletişimi' sorunudur — önce küçük hipotez.)"),
                .init("20 churn'lemiş müşteriyle konuş", detail: "+gerçek sinyal / hız kaybı + pivot baskısı", effects: [.morale(1), .reputation(5), .usersPercent(-0.02)],
                      result: "Görüşmeler yapıldı. (Kohort analizi sayıları gösterir; müşteri görüşmesi nedenleri gösterir — kararı veri + sebep birlikte verir.)")
            ]),

        // MARK: - Default-Alive & Nakit Yönetimi

        DecisionCard("salary-cut-promise", category: .team, speaker: "Mali İşler", icon: "✂️",
            prompt: "Runway 4 ay. Ya tüm ekipte %15 maaş kesintisi konuşmalısın, ya da işten çıkarmaya hazırlanmalısın.",
            trigger: .lowRunwayMonths(5),
            choices: [
                .init("Şeffaf konuş, maaş kes", detail: "+ekip korunur + 3 ay runway / moral darbesi + güven yıpranır", effects: [.cashPercent(0.12), .morale(-10), .reputation(-2), .moraleTargetBonus(-1)],
                      result: "Herkes kemerini sıktı. (Default-alive olmak demokratik değil pragmatiktir; ama bilgi paylaşmadan kesinti güveni öldürür.)"),
                .init("Layoff yap, kalan ekibe odaklan", detail: "−headcount + acı / +sağlam runway", effects: [.cash(8_000), .headcount(dept: 0, delta: -1), .morale(-12), .reputation(-3)],
                      result: "Acı bir gün. (İkiye böl, bir kez yap — iki kez yapılan layoff her seferinde güveni iki kez yer.)")
            ]),

        DecisionCard("vc-bridge-loan", category: .investor, speaker: "Lider Yatırımcı", icon: "🌉",
            prompt: "Yatırımcın köprü kredi öneriyor: $200K, 12 ay sonra geri öde + sonraki turda dönüşüm hakkı.",
            trigger: .lowRunwayMonths(4),
            choices: [
                .init("Köprüyü al, 12 ay kazan", detail: "+nakit hızlı / 12 ay sonra geri ödeme baskısı + valuation çapası", effects: [.cash(200_000), .reputation(2), .moraleTargetBonus(-2)],
                      result: "Köprüden geçtin. (Bridge financing saatli bombadır; rakam değil, plan kurtarır — geri ödeme planı net olmalı.)"),
                .init("Reddet, gelir odaklı küçül", detail: "+bağımsız karar / kasada nakit yok + cesur bahis", effects: [.morale(-4), .reputation(5), .cashPercent(0.08)],
                      result: "Kendi gelirini büyütmeyi seçtin. (Borçtan kaçmak disiplinli; ama gelir hedeflerin gerçekçi değilse iki ay sonra payroll kartı bekler.)")
            ]),

        // MARK: - Cap Table & Erken Danışman

        DecisionCard("advisor-equity", category: .investor, speaker: "Tanınmış Danışman", icon: "🧙",
            prompt: "Sektörün ünlü ismi danışman olmaya hazır: ayda 2 saat, %1 hisse 4 yıllık vesting.",
            once: true, trigger: .minStage(1),
            choices: [
                .init("Anlaşmayı imzala", detail: "+kapı açıcı + güvenilirlik / −%1 + dilution birikir", effects: [.equity(-0.01), .reputation(14), .moraleTargetBonus(2)],
                      result: "Danışman bordoda. (Tek bir doğru danışman %1'ini fazlasıyla geri öder; ama 5 danışman da %5'tir — toplam dikkat.)"),
                .init("Saatlik öde, hisse verme", detail: "+hisse korunur / +taahhüt düşük + erişim sınırlı", effects: [.cash(-3_000), .reputation(4), .morale(2)],
                      result: "Saatlik kontrat. (Ücretli danışman da çalışır ama hizalanma seviyesi farklıdır; uzun vadede 'kendi şirketim' hissetmez.)")
            ]),

        // MARK: - Erken Hire vs Outsource

        DecisionCard("ctO-vs-contract", category: .team, speaker: "Operasyon Lideri", icon: "👨‍💻",
            prompt: "Mühendislik gücüne ihtiyacın var. Üç yol: full-time CTO (%4 hisse), yarı zamanlı CTO ($5K/ay), ya da kontrat geliştirici ($8K/ay).",
            once: true, trigger: .minStage(1),
            choices: [
                .init("Full-time CTO al", detail: "+derin bağ + uzun vade / −%4 hisse + agresif maaş", effects: [.equity(-0.04), .headcount(dept: 0, delta: 1), .morale(6), .reputation(4)],
                      result: "Co-founder düzeyinde mühendislik. (Doğru CTO kurucu kadar değerlidir; yanlış CTO cap table'ı zorla temizlemek anlamına gelir.)"),
                .init("Yarı zamanlı CTO + kontrat dev", detail: "+esneklik + hızlı çıkış / +parçalı kültür + bağlılık zayıf", effects: [.cash(-7_000), .morale(2), .reputation(2), .usersPercent(0.02)],
                      result: "Hibrit yapı. (Erken aşamada esneklik değerli; ölçek geldiğinde sahip-CTO ihtiyacı tekrar gündeme gelir.)")
            ]),

        // MARK: - Cohort & Müşteri Kaybı

        DecisionCard("whale-reacquisition", category: .market, speaker: "Müşteri Başarısı", icon: "🎯",
            prompt: "Geçen ay kaybettiğin whale müşteri 'belki dönerim' diyor — yeni özelliği isterse. Yol haritasını bükecek özel istekleri var.",
            trigger: .minStage(3),
            choices: [
                .init("Geri alma için custom yap", detail: "+gelir geri gelir / roadmap çapası + custom borç", effects: [.cash(15_000), .reputation(2), .morale(-3), .usersPercent(-0.02)],
                      result: "Whale döndü. (Geri kazanılan müşteri sadık değildir; bir kez gitti, ikinci kez gitmesi kolaydır.)"),
                .init("Yeni segmente yatırım yap", detail: "+kontrol / +zaman + gelir hedefi geri kalır", effects: [.cash(-5_000), .reputation(5), .morale(3), .usersPercent(0.05)],
                      result: "İleri baktın. (Concentration risk öğretmen kartıdır; 1 büyük yerine 10 küçük arayışı, daha sağlam gelir tabanı yaratır.)")
            ]),

        // MARK: - Monetization & Open Core

        DecisionCard("freemium-paywall-decision", category: .product, speaker: "Büyüme Lideri", icon: "🚪",
            prompt: "Ücretsiz katmanın 20.000 aktif kullanıcı çekti ama gelir hâlâ marjinal. Sert paywall mı, premium katman mı?",
            trigger: .minUsers(1_500),
            choices: [
                .init("Sert paywall: temel özellikleri kilitle", detail: "+gelir hızlı / kullanıcı erimesi + topluluk kırılır", effects: [.cashPercent(0.2), .usersPercent(-0.18), .reputation(-5), .moraleTargetBonus(-1)],
                      result: "Ödeyenler arttı, ses yükseldi. (Sert paywall bir gece kararı değildir; topluluk bir kez kırılırsa marka uzun süre toparlanır.)"),
                .init("Premium katman + freemium genişlet", detail: "+daha yumuşak / +gelir yavaş + iki ürün dengesi", effects: [.cashPercent(0.08), .usersPercent(0.04), .reputation(4), .morale(3)],
                      result: "İki katman koştu. (Iyi monetizasyon değer ayrımıdır; aynı şey için fiyat değişimi değil, farklı paket için farklı fiyat.)")
            ]),

        // MARK: - VC Blitzscale Baskısı

        DecisionCard("blitzscale-pressure", category: .investor, speaker: "Board Üyesi", icon: "🚀",
            prompt: "Yatırımcı 'pazarı kap, kârı sonra düşün' diyor. Sen sürdürülebilir tempoya inanıyorsun.",
            trigger: .minStage(3),
            choices: [
                .init("Blitzscale moduna geç", detail: "+pazar payı + bilinirlik / −runway kısalır + ekip yorgun", effects: [.cashPercent(-0.25), .usersPercent(0.3), .reputation(6), .morale(-7), .moraleTargetBonus(-2)],
                      result: "Gaz pedalına bastın. (Blitzscale belli ürün-pazarlarda doğru: winner-takes-all dinamiği yoksa kasanı kendi elinle yakarsın.)"),
                .init("Disiplinli tempo, board'a sun", detail: "+sürdürülebilir / board gerilimi + sonraki tur zor", effects: [.cashPercent(0.05), .usersPercent(0.08), .reputation(2), .morale(6), .moraleTargetBonus(1)],
                      result: "Plan B sundun. (Tek doğru yol yoktur; Bootstrap-Frugal arketipi de Unicorn'a varır — sadece patikası farklı.)")
            ]),

        // MARK: - Strategic Partnership Trap

        DecisionCard("custom-feature-trap", category: .product, speaker: "Satış Müdürü", icon: "🪤",
            prompt: "Büyük müşteri özel bir özellik istiyor: 'yapın, $200K öderim — ama sadece bize'. Diğer müşterilere açamayacaksınız.",
            trigger: .minStage(2),
            choices: [
                .init("Custom yap, çekleri al", detail: "+büyük nakit / roadmap çapalı + ürün ayrışır", effects: [.cash(200_000), .morale(-4), .reputation(2), .moraleTargetBonus(-2)],
                      result: "Çek geldi. (Custom işler kasayı doldurur ama ürünü bir consulting şirketine dönüştürür; ölçek yerine saat satarsın.)"),
                .init("Standart paketle 'hayır' de", detail: "+ürün odağı korunur / büyük müşteri kaybedildi", effects: [.morale(3), .reputation(4), .usersPercent(0.03)],
                      result: "Hayır dedin. (Hayır demek bir ürün stratejisidir; tek müşteri için yapılan, tüm müşterileri kaybettirebilir.)")
            ]),

        // MARK: - Hiring Bar

        DecisionCard("hiring-bar-vs-speed", category: .team, speaker: "İK Lideri", icon: "🎚️",
            prompt: "Roadmap için 3 mühendis lazım. 8 ay görüştün, 1 'evet' var. Bar'ı düşürüp 3 hire mı, beklemeye devam mı?",
            trigger: .minStage(2),
            choices: [
                .init("Bar'ı koru, beklemeye devam", detail: "+kültür + uzun vade hız / +roadmap kayar + fırsat penceresi daralır", effects: [.morale(4), .reputation(5), .usersPercent(-0.04), .moraleTargetBonus(1)],
                      result: "Yavaş ama doğru. (İlk 20 hire kültürü oluşturur; yanlış birini geri çıkarmak 5 doğru birini almaktan zor.)"),
                .init("Bar'ı esnet, hızlı doldur", detail: "+kapasite hızlı / kültür sulanır + 6 ay sonra çıkış", effects: [.cash(-12_000), .headcount(dept: 0, delta: 2), .morale(-3), .usersPercent(0.05)],
                      result: "Üç hire bitti. (Hızlı dolduran bar, hızlı sızdıran bardır; mediocre hire'lar A-player'ları kovar.)")
            ]),

        // MARK: - Internal Compensation Pressure

        DecisionCard("comp-band-pressure", category: .team, speaker: "Kıdemli Mühendis", icon: "⚖️",
            prompt: "Üç kıdemli '%20 zam yoksa giderim' dedi. Aynı bütçeyle iki yeni hire alabilirsin. Hangi tarafa para?",
            trigger: .minStage(3),
            choices: [
                .init("Zam ver, kıdemli ekibi tut", detail: "+kurumsal bilgi korunur / +yeni hire kapasitesi gitti + ücret tavanı yükselir", effects: [.cashPercent(-0.08), .morale(7), .moraleTargetBonus(-2)],
                      result: "Kıdemliler kaldı. (Kurumsal bilgi pahalı bir varlıktır; ama her zamla şirketin tüm ücret bandı yukarı kayar.)"),
                .init("Yeni hire'a yatır, gidenle vedalaş", detail: "+kapasite genişler / kurumsal bilgi gider + 6 ay onboarding borcu", effects: [.cash(-5_000), .headcount(dept: 0, delta: 1), .morale(-5), .reputation(2)],
                      result: "Veda + alım. (Comp band disiplini stratejidir; ama deneyimli ekip kaybı görünmez bir hız kaybıdır.)")
            ]),

        // MARK: - Burnout vs Ship Date

        DecisionCard("crunch-vs-launch", category: .team, speaker: "Ürün Lideri", icon: "🏁",
            prompt: "Launch'a 3 hafta var ve ekip yorgun. Crunch yap, ship et — yoksa 4 hafta erteleyip moralle gel.",
            trigger: .minStage(2),
            choices: [
                .init("Crunch, ship et", detail: "+launch tarihinde / +moral darbesi + sonraki sprint düşük üretim", effects: [.usersPercent(0.06), .morale(-9), .reputation(2), .moraleTargetBonus(-2)],
                      result: "Ship oldu. (Bir kez crunch öğretilir, hep crunch beklenir; teslimat ritmi kültürdür.)"),
                .init("Ertele, dinlenmiş ekiple ship", detail: "+moral + kalite / launch fırsat penceresi kayar", effects: [.usersPercent(-0.02), .morale(6), .reputation(4), .moraleTargetBonus(1)],
                      result: "4 hafta sonraya alındı. (İyi launch geç launch'tan iyidir; kötü launch hiç olmamış gibi davranır pazar.)")
            ]),

        // MARK: - Pricing Power Test

        DecisionCard("price-bump-30", category: .product, speaker: "CFO", icon: "📈",
            prompt: "Mevcut müşterilere %30 fiyat artırmayı düşünüyorsun. Sektörde altındasın; ama churn riski var.",
            once: true, trigger: .minUsers(2_000),   // once: pozitif cashPercent istismarını kapat (audit #2 deseni)
            choices: [
                .init("Yeni kullanıcılara artır, eski grandfathered", detail: "+yeni gelir / +eski kullanıcı korunur + iki fiyat karmaşası", effects: [.cashPercent(0.15), .usersPercent(-0.04), .reputation(3), .morale(2)],
                      result: "Yeni fiyat etiketi. (Pricing power'ın varsa erken kullan; sektör altı fiyat değer sinyali değil, alt değer algısıdır.)"),
                .init("Tüm hattı %30 artır", detail: "+yüksek gelir / churn riski + topluluk reaksiyonu", effects: [.cashPercent(0.22), .usersPercent(-0.12), .reputation(-4), .morale(-2)],
                      result: "Genel artış. (Fiyat değişimi ürün değişimi gibi iletilirse kabul edilir; sessiz artış güveni en çabuk yer.)")
            ]),

        // MARK: - Geç-oyun: Çıkış, Halka Arz & Kurumsal Olgunluk (#16)

        DecisionCard("ipo-vs-stay-private", category: .investor, speaker: "Yatırım Bankacısı", icon: "🔔",
            prompt: "Bankacılar {{company}} için halka arz penceresinin açık olduğunu söylüyor: likidite + prestij, ama çeyreklik kâr baskısı ve kamuya açık her sayı. Yoksa özel kalıp uzun vadeli oynamak mı?",
            once: true, trigger: .minStage(4),
            choices: [
                .init("Halka arza hazırlan", detail: "+büyük likidite + prestij / +çeyrek baskısı + raporlama yükü", effects: [.cash(3_000_000), .reputation(12), .morale(-4), .moraleTargetBonus(-1)],
                      result: "Zil çalmaya hazırlanıyorsun. (IPO bir bitiş değil yeni bir kısıt: kamu piyasası uzun vadeli bahisleri çeyreklik beklentiye sıkıştırır.)"),
                .init("Özel kal, sabırlı sermaye bul", detail: "+kontrol + uzun vade odak / likidite ertelenir", effects: [.reputation(6), .morale(5), .moraleTargetBonus(1)],
                      result: "Özel kalmayı seçtin. (Özel kalmak ürün vizyonuna nefes alanı verir; ama erken çalışanların ve yatırımcıların likidite beklentisi bir gün masaya gelir.)")
            ]),

        DecisionCard("secondary-market-employees", category: .investor, speaker: "İK & Finans", icon: "💱",
            prompt: "Erken çalışanlar yıllardır kâğıt üstünde zengin ama cebinde nakit yok. İkincil pazar turu açıp hisselerinin bir kısmını satmalarına izin verir misin?",
            once: true, trigger: .minStage(4),
            choices: [
                .init("İkincil pazarı aç", detail: "+ekip sadakati + moral / dış yatırımcı cap table'a girer", effects: [.morale(9), .reputation(3), .moraleTargetBonus(1)],
                      result: "Ekip biraz rahatladı. (Likidite penceresi sadakat satın alır; ama kontrolsüz ikincil, cap table'a istemediğin yatırımcıları sokabilir.)"),
                .init("Şimdilik kapat, büyümeye yatır", detail: "+cap table temiz / +çalışan sabırsızlığı birikir", effects: [.reputation(2), .morale(-5), .moraleTargetBonus(-1)],
                      result: "\"Daha büyük çıkışta hepimiz kazanırız\" dedin. (Ertelenen likidite bir bahistir; en iyi çalışanlar nakdi başka yerde bulabilir.)")
            ]),

        DecisionCard("antitrust-scrutiny", category: .crisis, speaker: "Düzenleyici Kurum", icon: "🏛️",
            prompt: "{{company}} pazarda baskın hale geldi; bir rekabet otoritesi inceleme başlattı. İşbirliği yapıp yavaşlamak mı, yoksa agresif savunup büyümeye devam mı?",
            once: true, trigger: .minStage(4),
            choices: [
                .init("İşbirliği yap, taahhüt ver", detail: "−nakit + bazı kısıtlar / +meşruiyet + risk düşer", effects: [.cash(-60_000), .reputation(6), .usersPercent(-0.03), .morale(-2)],
                      result: "Masaya oturdun. (Düzenleyiciyle erken işbirliği pahalıdır ama varoluşsal riski azaltır; baskınlık görünürlük getirir.)"),
                .init("Hukuki savunma, statükoyu koru", detail: "+kısa vade büyüme korunur / −uzun davalar + itibar riski", effects: [.cash(-25_000), .reputation(-5), .usersPercent(0.04), .moraleTargetBonus(-1)],
                      result: "Savunmaya geçtin. (Düzenleyici savaşı yıllar sürer ve dikkat çalar; bazen kazanmak bile kaybettirir.)")
            ]),

        DecisionCard("mergers-acquisitions-buyer", category: .opportunity, speaker: "Kurumsal Geliştirme", icon: "🧩",
            prompt: "Artık alıcı sensin: küçük bir rakip satın alınmaya hazır. Yeteneği ve teknolojisi sana sıçrama yaptırır, ama entegrasyon ekibini aylarca meşgul eder.",
            trigger: .minStage(4),
            choices: [
                .init("Satın al, entegre et", detail: "+yetenek + teknoloji / −büyük nakit + entegrasyon yükü", effects: [.cash(-400_000), .headcount(dept: 0, delta: 1), .usersPercent(0.08), .reputation(5), .morale(-3)],
                      result: "İlk satın alman tamam. (M&A büyümeyi hızlandırır ama entegrasyonların çoğu kültür çatışmasında değer kaybeder; satın almak kolay, kaynaştırmak zor.)"),
                .init("Organik büyü, yeteneği kendin yetiştir", detail: "+kontrol + kültür bütünlüğü / +daha yavaş + fırsat rakibe gider", effects: [.morale(4), .reputation(3), .moraleTargetBonus(1)],
                      result: "Kendi yolunda kaldın. (Organik büyüme kültürü korur ama pencere kapanabilir; rakip o ekibi başkası kaparsa pişman olabilirsin.)")
            ]),

        DecisionCard("founder-ceo-transition", category: .team, speaker: "Yönetim Kurulu", icon: "👔",
            prompt: "Şirket bir kurucunun tek başına yönetemeyeceği ölçeğe ulaştı. Board deneyimli bir operasyon CEO'su getirip senin ürün/vizyona geçmeni öneriyor. Koltuğu bırakır mısın?",
            once: true, trigger: .minStage(4),
            choices: [
                .init("Profesyonel CEO getir, başkan ol", detail: "+operasyonel olgunluk / −günlük kontrol + kimlik sancısı", effects: [.reputation(8), .morale(3), .moraleTargetBonus(1), .equity(-0.02)],
                      result: "Direksiyonu paylaştın. (Kurucu-CEO geçişi başarısızlık değil olgunluktur; ama yanlış CEO kültürü bir çeyrekte eritebilir — seçim her şeydir.)"),
                .init("CEO olarak kal, yanına güçlü COO al", detail: "+vizyon kontrolü / +kurucu üzerinde yük + ölçek riski", effects: [.cash(-20_000), .headcount(dept: 4, delta: 1), .morale(-2), .reputation(4)],
                      result: "Koltukta kaldın, yükü paylaştın. (Kurucu kalmak vizyonu korur; ama her kurucu operatör değildir — kendine dürüst ol.)")
            ]),

        DecisionCard("strategic-acquirer-megaoffer", category: .opportunity, speaker: "Dev Teknoloji Şirketi", icon: "🐳",
            prompt: "Sektörün devi {{company}} için yüklü bir satın alma teklifi masaya koydu: hayat değiştiren para, ama ürün onların ekosistemine gömülür ve marka kaybolur.",
            once: true, trigger: .minStage(5),
            choices: [
                .init("Sat, mega çıkış yap", detail: "+devasa nakit / vizyon + marka kapanır + ekip dağılabilir", effects: [.cash(50_000_000), .equity(0.08), .reputation(6), .morale(-6)],
                      result: "Tarihî çek imzalandı. (En büyük çıkış en büyük bahsin sonu olabilir; \"ya unicorn olsaydık\" sorusu ömür boyu kalır — ama kuş eldeyken de bir bilgelik var.)"),
                .init("Reddet, bağımsız unicorn'a oyna", detail: "+upside + bağımsızlık / teklif bir daha gelmeyebilir", effects: [.morale(12), .reputation(11), .moraleTargetBonus(2)],
                      result: "\"Biz daha büyüğüz\" dedin. (Reddedilen mega teklif cesarettir; ama piyasa döner ve aynı fiyat bir daha gelmeyebilir — bu da bir risk.)")
            ]),

        DecisionCard("dual-class-shares", category: .investor, speaker: "Hukuk & Finans", icon: "⚖️",
            prompt: "Halka arz öncesi yapı kurarken çift sınıflı hisse önerildi: kurucu oyların çoğunu elinde tutar ama yatırımcılar yönetişim açısından çekinik.",
            once: true, trigger: .minStage(5),
            choices: [
                .init("Çift sınıflı yapı kur", detail: "+uzun vade kontrol + vizyon koruması / yatırımcı güveni gerilir", effects: [.equity(0.03), .reputation(-3), .morale(4), .moraleTargetBonus(1)],
                      result: "Kontrolü çapaladın. (Çift sınıf vizyonu kısa vadeli baskıdan korur; ama hesap verebilirliği zayıflatır — güç sorumlulukla dengelenmezse körlük getirir.)"),
                .init("Tek sınıf, eşit oy", detail: "+yatırımcı güveni + yönetişim / kurucu daha kırılgan", effects: [.reputation(6), .equity(-0.02), .moraleTargetBonus(-1)],
                      result: "Eşit oy hakkı seçtin. (Tek sınıf piyasanın güvenini kazanır; ama aktivist yatırımcılar bir gün yön değiştirmeye zorlayabilir.)")
            ]),

    ]
}
