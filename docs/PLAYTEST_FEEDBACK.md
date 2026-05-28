# Unicorn: Garajdan Zirveye — Oynanış Geri Bildirimi (QA + Tasarım)

> Bu rapor oyunu simülatörde 4 farklı evrede oynayarak (Garaj / Series A / Series C /
> iflasa yakın) + kaynak kod incelemesiyle hazırlandı. Ekran görüntüleri `/tmp/qa_*.png`.
> Hedef: oyunu **uzun vadede sürdürülebilir ve tatmin edici** kılacak ÖNCELİKLİ backlog.

---

## Genel İzlenim

İskelet sağlam ve şaşırtıcı derecede bütün: temiz HUD, evreye göre değişen tema/ofis
adı, büyüyen çalışan kalabalığı (SpriteKit), 35 kart içeren anlamlı bir karar havuzu,
funding kutlaması, iflas/kazanma ekranları, offline rapor, onboarding ve prestij
(founderXP) zemini mevcut. Ekonomi de dengeli görünüyor (BALANCE_REPORT: ~95 dk'lık
tam eğri, ilk tur 3 dk'da). Yani **temel "number-go-up" ve ilk hook ÇALIŞIYOR.**

Ama oyun şu an **bir simülasyon uygulaması gibi**, "oyun" gibi değil. Üç temel boşluk:
1. **Oyuncunun yapacak işi az.** Tek aktif eylemler: işe al, modül al, kararı yanıtla,
   tur topla. Aralarda 22-40 sn boyunca sadece sayıları izliyorsun — ofis sahnesi
   tıklanabilir/etkileşimli değil, "tap to collect" yok, aktif bir dürtü yok.
2. **Geri-dönüş (retention) motoru neredeyse yok.** Günlük ödül, hedef/görev, etkinlik,
   bildirim, FOMO, streak — hiçbiri yok. Offline raporu var ama oyuncuyu geri *çağıran*
   bir kanca yok.
3. **Kriz anı kırık.** İflasa yakınken (Görüntü: `qa_d_crisis2/bankrupt`) oyun, can simidi
   yerine alakasız bir "viral TikTok" fırsat kartı sundu. Oyuncu ölürken oyun parti veriyor.

Aşağıdaki backlog bu üç eksene odaklanır.

---

## Ekran Görüntüsü Bulguları (ne gördüm)

- **`qa_a_garaj`** (Garaj, $7.86K, 4 ay runway): HUD net, okunur. Ofis sahnesi neredeyse
  boş (2 figür + 1 bitki); cansız, etkileşimsiz. Founder ipucu balonu iyi.
- **`qa_a_decision`** (Teknoloji Blogu kartı): Karar kartı tasarımı çok iyi — ikon, konuşan
  kişi, prompt, etki ipuçları (gri alt yazı) net. Bu sistemin sunumu oyunun en güçlü yanı.
- **`qa_b_seriesA`** (Series A, $615K, mor tema, "Açık Plan Kat"): Tema geçişi hoş, ofis
  artık dolu bir grid. Ama Series B hedefi %6 — uzun bir grind başlıyor, bu aralıkta yeni
  "oyuncak" yok (modüllerin çoğu zaten açık).
- **`qa_c_seriesC`** (Series C, $42M, teal, "PLAZA", karlı/♾️ runway): Büyük sayılar düzgün
  formatlanıyor. ANCAK ofis ~30 birebir aynı küçük figürün düzgün grid'i — artık ilerleme
  *hissi* vermiyor; bina büyümüyor, prestij görseli yok. Founder ipucu hâlâ jenerik
  "Runway her şeydir" diyor (karlıyken absürt).
- **`qa_d_crisis` / `qa_d_crisis2` / `qa_d_bankrupt`** (Seed, -$11K→-$19.9K, moral 19→0):
  Kriz görsel geri bildirimi GÜÇLÜ — kırmızı nakit, ⚠️ runway, kırmızı moral barı, "biri
  istifa etti" toast'ı, ipucu otomatik runway-uyarısına dönüyor. Ölüm sarmalı iyi
  hissediliyor. AMA tetiklenen karar bir kriz/kurtarma kartı değil, alakasız bir büyüme
  fırsatıydı (aşağıda P0).

---

## Sonraki İterasyon — Öncelikli Backlog

### P0 — Kritik (oyun hissi & adalet)

**P0-1 · Kriz anında doğru kart: "acil köprü/yatırımcı" lifeline'ı garanti et.**
*Ne:* Runway < ~2 ay veya cash < 0 olduğunda, sıradaki kart MUTLAKA bir kurtarma kararı
olsun (köprü kredisi / down round / acil melek / işten çıkarma teklifi). Şu an
`DecisionSystem.pick` kriz kartlarını yalnızca `Bool.random()` ile %50 önceliklendiriyor
ve `payroll-risk`/`down-round` tüm `always` kartlarıyla aynı havuzda yarışıyor.
*Neden:* Oynarken (`qa_d_crisis2`) ölürken oyun "viral TikTok" fırsatı sundu — hem
sürükleyiciliği kırıyor hem oyuncuyu çaresiz bırakıyor. Lifeline yoksa iflas öğretici
değil cezalandırıcı olur.
*Nasıl:* `pick()` içinde önce bir "urgency" kontrolü: `model.runwayMonths < 2 || cash<0`
ise yalnızca `trigger == .lowRunwayMonths/.crisis` kartlarından seç; ayrıca düşük-runway'e
özel yeni bir "acil yatırımcı" kartı ekle (DecisionContent). `forceDecisionIfAvailable`
zaten var; ilk kez runway<2'ye düşüldüğünde anında tetikle.

**P0-2 · Aktif etkileşim ekle (idle ≠ pasif izleme).**
*Ne:* Bekleme süresinde oyuncuya bir "dokunma dürtüsü" ver. En basit/temkinli versiyon:
ofis sahnesinde ara sıra beliren toplanabilir balon (💡 fikir / 💰 gelir / 🐛 bug) — tıkla,
küçük ödül/penaltı. Veya "Hızlandır / Boost" butonu (ör. reklam izle → 2x 60 sn).
*Neden:* Oyunlar "tap-to-do-something" döngüsüne ihtiyaç duyar; şu an 22-40 sn'lik
ölü zaman var ve ofis sahnesi tamamen dekoratif. Bu, "uygulama" hissini "oyun"a çevirir.
*Nasıl:* `OfficeScene`'e periyodik spawn + tap handler; `GameModel`'de `collectBubble()`.

**P0-3 · Geri-dönüş kancası: hedefli push bildirimleri + offline'ı kanca yap.**
*Ne:* (1) "Runway 6 saat sonra bitiyor", (2) "Bir sonraki tura %90 — dön ve topla!",
(3) "Ekibin X kullanıcı kazandı, gel gör" yerel bildirimleri. Offline cap dolunca
"Ofisin seni bekliyor" hatırlatması.
*Neden:* Şu an oyun oyuncuyu geri *çağırmıyor*. iOS idle oyunlarında D1/D7 retention'ın
1 numaralı sürücüsü yerel bildirimdir. Tek başına bu özellik retention'ı kat kat artırır.
*Nasıl:* `UNUserNotificationCenter`, onboarding'de izin iste; `saveOnBackground`'da
runway/tur-ETA hesaplayıp bildirim zamanla.

### P1 — Yüksek değer (derinlik & retention)

**P1-1 · Günlük dönüş döngüsü: günlük görev + streak + günlük hibe.**
*Ne:* Her gün 2-3 küçük görev ("1 işe al", "1 kart çöz", "$X kazan") + tamamlayınca
nakit/boost ödülü; ardışık gün streak'i artan ödül verir.
*Neden:* Hedef/ödül döngüsü tamamen eksik. Görevler oyuncuya her oturumda "yapılacak"
verir; streak FOMO yaratır. Düşük maliyetli, yüksek retention etkisi.
*Nasıl:* `GameState`'e `lastDailyClaim`, `streak`, `dailyTasks` ekle; yeni `DailyPanel`
veya HUD rozeti.

**P1-2 · Orta-oyun platosunu kır: evre 3-5'te yeni mekanik/modül aç.**
*Ne:* Series A→B→C aralıkları (BALANCE_REPORT'a göre 16-28 dk) yeni oyuncak sunmuyor —
modüllerin tamamı stage 0-2'de açık. Stage 3-4-5'e yeni modüller (ör. "Yapay Zeka Otomasyonu",
"Veri Platformu", "M&A Ekibi") ya da yeni bir departman/mekanik ekle.
*Neden:* `qa_b_seriesA`'da görüldü: uzun grind, yeni hiçbir şey açılmıyor → ilgi düşer.
*Nasıl:* `Balance.modules`'a `unlockStage: 3/4` modüller; veya stage'e bağlı "özel proje"
sistemi (tek seferlik büyük yatırım → kalıcı çarpan).

**P1-3 · Rakipler / pazar payı mekaniği (özgünlük + gerilim).**
*Ne:* Görünür 2-3 rakip startup; senin büyümen onların payını yer, onların hamleleri
(fiyat kırma, kopya özellik) senin churn/growth'unu etkiler. "Pazar lideri ol" alt-hedefi.
*Neden:* Şu an dünya boş — sadece sen varsın. Rakip yaşayan bir ekosistem ve sürekli
gerilim/karar kaynağı yaratır; "rakipler" ekranı oyuncuya izlenecek bir rakip metriği verir.
*Nasıl:* `Competitor` modeli + market-share hesabı; mevcut `competitor`/`pivot` kartlarını
buna bağla.

**P1-4 · Başarımlar / kilometre taşları + kalıcı meta-ödül.**
*Ne:* "İlk 10K kullanıcı", "Hiç işten çıkarmadan Seed", "3 turda Unicorn" gibi rozetler;
bazıları kalıcı pasif bonus verir. İflas sonrası `founderXP` zaten var — bunu görünür bir
"Kurucu Kariyeri / Prestij" ekranına bağla.
*Neden:* Uzun vadeli hedef ve "topla" güdüsü; meta-ilerleme NG+ döngüsünü besler.
*Nasıl:* `Achievement` listesi + kontrol; `StatsPanel`'e veya yeni 6. sekmeye yerleştir.

**P1-5 · İflası "ceza" değil "kariyer dönüm noktası" yap.**
*Ne:* İflas ekranında (mevcut `BankruptcyView`) "şu dersi öğrendin → sonraki şirkete kalıcı
+%X bonus seç" gibi bir prestij seçimi sun; founderXP'yi somut çarpana çevir.
*Neden:* Şu an iflas = sıfırla + biraz nakit. Roguelike-meta hissi verirse "tekrar dene"
güçlü bir retention döngüsü olur (BALANCE_REPORT da bunu öneriyor).
*Nasıl:* `restartAfterBankruptcy` öncesi bonus-seçim modali; `GameState`'e `perks: [Int]`.

### P2 — İyileştirme & cila

**P2-1 · Geç-oyun prestij görseli: ofis sadece "daha çok nokta" olmasın.**
`qa_c_seriesC`'de 30 birebir figür ilerleme hissi vermiyor. Evreye göre bina/arka plan
ölçeği büyüsün, kademeli landmark'lar (kahve makinesi, sunucu odası, çatı katı) eklensin.

**P2-2 · Bağlama duyarlı founder ipuçları.** Karlıyken "Runway her şeydir" demesin; evre,
moral, runway, son karara göre ipucu seç. Mevcut `runwayTip` mantığını genişlet.

**P2-3 · Yatırımcı ilişkileri / cap table ekranı.** Hisse %'si HUD'da var ama "kime ne
kadar verdin", "sonraki turda ne kadar erir" görünmüyor. Küçük bir cap-table görünümü
hisse kararlarını daha anlamlı kılar (oyunun temasıyla çok uyumlu, özgün).

**P2-4 · Karar sıklığı & çeşit.** 22-40 sn aralık erken oyunda iyi ama geç-oyunda monoton;
evre ilerledikçe daha büyük/nadir "stratejik" kararlar (kategori bazlı kotalar) eklenebilir.
`once` kartlar tükendikçe havuz tekrar ediyor — evreye özel kart setleri ekle.

**P2-5 · Tur topla anını güçlendir.** `FundingRoundView` iyi ama "şu yeni şey açıldı"
(modül/departman/etkinlik) vurgusu yok. Kutlamada "Yeni: X modülü açıldı!" satırı ekle.

---

## Hızlı Kazanımlar (Quick Wins)

- **Kriz lifeline garantisi** (P0-1) — birkaç satır `pick()` mantığı + 1 yeni kart;
  en yüksek etki/efor oranı.
- **Bağlama duyarlı ipuçları** (P2-2) — sadece `tipText` koşullarını genişlet; absürtlüğü
  bitirir, kişiselleşme hissi verir.
- **Funding kutlamasına "yeni açıldı" satırı** (P2-5) — number-go-up dopaminini ucuza artırır.
- **Yerel bildirim — tek tip bile yeter** (P0-3'ün minimal hali): "Runway azalıyor" /
  "Tura %X kaldı" tek bildirim bile D1 dönüşünü ciddi artırır.
- **Karlıyken runway "♾️ karlı" yerine "Aylık +$X kâr" göster** — pozitif pekiştirme,
  oyuncuya kazandığını hissettir (HUD `runwayText`).
- **Stage 3-4'e 1-2 modül ekle** (P1-2 minimal) — sadece `Balance.modules` dizisine ekleme;
  orta-oyun platosunu anında yumuşatır.

---

## Playtest — 2026-05-28 (İterasyon 1.5: gider/büyüme/para birimi/hız/font)

> Bu oturum 5 evreyi tohumlanmış save'lerle oynayarak yapıldı: (a) erken Garaj düşük
> nakit, (b) Series A dolu ekip + reklam bütçeli, (c) Series C büyük rakam/yüksek
> kullanıcı, (d) iflasa yakın (moral~20, nakit negatif), (e) para birimi `try`. Ekran
> görüntüleri `/tmp/pt_*.png`. Kaynak kod (GameModel/Balance/GameState/GrowthPanel/
> StatsPanel/OfficeScene/EventOverlays/DecisionSystem) ayrıca incelendi.
>
> **Önemli kısıt:** Sekme değiştirmek için dokunamadığım için Büyüme ve İstatistik
> ekranlarını çalışan uygulamada GÖREMEDİM (varsayılan sekme: Ofis). Bu iki ekranın
> değerlendirmesi yalnızca KAYNAK KOD okumasına dayanıyor; canlı ekran görüntüsüyle
> doğrulanması gerekir.

### 1. Yeni özelliklerin değerlendirmesi

**Büyüme & CAC ekranı (GrowthPanel — koddan):** Sunum konsepti çok güçlü. Bütçe ±/×5/
Sıfırla butonları + anlık "Ücretli kullanıcı/ay" ve "CAC" projeksiyonu, ardından
LTV / LTV:CAC / Geri Ödeme / Churn / Organik / Net büyüme metrik grid'i ve renk
kodlu (yeşil≥3 / sarı≥1 / kırmızı<1) sağlık notu — bu, oyunu gerçek bir SaaS-kurucu
simülasyonuna dönüştüren en eğitici eklenti. Ekonomi modeli de sağlam: CAC evreyle
artıyor (`cacStageScaling`), harcama ölçeğiyle doyuyor (`saturation`), pazarlama gücü
ve `qualityFactor` ile düşüyor; organik/ücretli ayrımı net (`organicUserGrowthPerMonth`
vs `paidUserGrowthPerMonth`). **Tek risk:** bu ekran Ofis sekmesinde değil; oyuncu
"reklam bütçesini ayarla" döngüsünü keşfetmek için sekmeye geçmek zorunda — ilk kez
açılışta bir işaret/onboarding ipucu olmadan birçok oyuncu bunu hiç görmeyebilir.

**Gider dağılımı (StatsPanel — koddan):** Maaş + 6 OpEx kalemi (Kira/SaaS/Bulut/Yasal/
Ekipman/Genel) + Reklam, büyükten küçüğe sıralı bar'larla gösteriliyor; her kalemin
farklı sürücüsü var (perSeat / perThousandUsers / perStage). Bu öğretici: oyuncu
"neden 480K kullanıcıda bulut gideri patlıyor" veya "neden Series C'de kira 5.4× pahalı"
sorusunun cevabını görebiliyor. Modül indirimleri (Sunucu Optimizasyonu→bulut,
Hibrit Ofis→kira) bu kalemlere bağlı — güzel bir sebep-sonuç. Yine canlı doğrulanmalı.

**Para birimi (Görüntü: `pt_e`):** `try` ile ₺ sembolü her yerde temiz render oluyor
(₺614K nakit, ₺7.38M değerleme, ₺79.9K/ay MRR) — Space Grotesk ₺'yi sorunsuz çiziyor.
ÇALIŞIYOR. **Caveat:** para birimi yalnızca SEMBOLÜ değiştiriyor, büyüklükleri değil;
yani `try` seçilince ARPU hâlâ ₺3.5, başlangıç nakdi ₺40K. Gerçek TL için bunlar absürt
düşük (gerçekçi TL ARPU ~₺100+). Kozmetik sembol-takası olarak kusursuz, ama "TL oyna"
isteyen Türk oyuncuya tutarsız gelebilir.

**Zaman hızı 1×/2×/3× (kod + Ofis):** Buton Ofis sağ üstte (`speedButton`), aktifken
accent renkle dolu. `tick()` içinde `dt = realDt * speed` ile doğru uygulanmış —
ekonomi, moral, kararlar hepsi hızlanır. Sağlam ve idle oyunlarda beklenen bir konfor.
**Caveat:** `speed` kalıcı değil (GameState'te yok), uygulama yeniden açılınca 1×'e
döner; ufak bir UX pürüzü.

**İki font (tüm görüntüler):** Sayılar Space Grotesk, metin Inter ayrımı net çalışıyor;
HUD'daki büyük nakit rakamı ve metrikler karakterli, etiketler okunur. Görsel kimlik
belirgin biçimde yükseldi. ÇALIŞIYOR.

**Yeni 2 modül (Balance):** Sunucu Optimizasyonu (id6, infraCostReduce) ve Hibrit Ofis
(id7, rentCostReduce) eklendi ve gider kalemlerine doğru bağlandı. Ekonomik olarak
anlamlı. ANCAK ikisi de `unlockStage` 1 ve 2 — yani hâlâ erken-orta evrede açılıyor;
P1-2'deki "stage 3-4 platosunu kır" sorunu çözülmedi (aşağıya bak).

### 2. Hâlâ duran P0/P1 eksikler (önceki rapora göre durum)

**P0-1 · Kriz lifeline garantisi — DÜZELMEDİ (en kritik).** `DecisionSystem.pick` hâlâ
kriz kartlarını yalnızca `Bool.random()` ile %50 önceliklendiriyor ve düşük-runway'de
GARANTİLİ kurtarma kartı sunmuyor. Oynarken birebir gözlemledim:
- `pt_a` / `pt_a2` (Garaj, runway 1 ay, moral 45'e düştü): runway kritik olmasına rağmen
  ~70 sn içinde HİÇBİR karar/kriz kartı tetiklenmedi; oyuncu çaresizce ölüme akıyor.
- `pt_d` / `pt_d3` (Seed, nakit -$26K, runway 0, moral 0): tetiklenen kriz kartı
  **"🔥 Ana sunucu çöktü"** oldu — HER İKİ seçenek de nakit HARCATIYOR (−$5K / −$12K).
  Yani oyun, oyuncu negatif nakitte ölürken ona "daha fazla para harca" diyor. Bir
  köprü kredisi / acil yatırımcı / işten çıkarma lifeline'ı YOK. `payroll-risk` ve
  `down-round` kartları tüm diğer kriz kartlarıyla aynı rastgele havuzda yarışıyor.
  Bu, iflası "öğretici" değil "cezalandırıcı + adaletsiz" yapıyor. **EN YÜKSEK ÖNCELİK.**

**P0-2 · Aktif etkileşim — DÜZELMEDİ.** `OfficeScene`'de tap handler / toplanabilir
balon YOK (`touchesBegan` yok, `collectBubble` yok). `pt_a`'daki ortadaki parlayan
"orb" bir toplanabilir değil — garaj evresinin dekoratif **sallanan ampulü**
(`addHangingBulb`). 22-40 sn'lik ölü zaman ve "dokun-bir-şey-yap" eksikliği duruyor.
Sahne hâlâ tamamen dekoratif.

**P0-3 · Geri-dönüş kancası / bildirim — DÜZELMEDİ.** Kod tabanında `UNUserNotification`
hiç yok. Offline rapor (`OfflineReportView`) var ama oyuncuyu geri *çağıran* hiçbir
mekanizma yok. D1/D7 retention'ın 1 numaralı sürücüsü hâlâ eksik.

**P1-1 · Günlük döngü (görev/streak/hibe) — DÜZELMEDİ.** `GameState`'te `lastDailyClaim`/
`streak`/`dailyTasks` yok; `DailyPanel` yok. Oturum-başı "yapılacak" ve FOMO eksik.

**P1-2 · Orta-oyun platosu — KISMEN.** 2 yeni modül eklendi ama stage 1-2'de açılıyor;
stage 3-5 aralığında (Series A→B→C, BALANCE'a göre 16-28 dk grind) hâlâ yeni oyuncak
açılmıyor. `pt_b`/`pt_e` (Series A, Series B %9): uzun grind doğrulandı, yeni mekanik yok.

**P1-5 · İflas = prestij seçimi — DÜZELMEDİ.** `BankruptcyView` hâlâ sadece "Yeniden Kur";
perk/ders seçimi yok. `founderXP` çarpanı görünmez kalıyor.

**P2-2 · Bağlama duyarlı ipuçları — KISMEN (önemli pürüz).** `OfficePanel.tipText` artık
runway<3 iken `runwayTip` gösteriyor (iyi — `pt_a`/`pt_d`'de "Runway daralıyor/bir
aydan az" doğru çıktı). AMA runway≥3 iken hâlâ rastgele jenerik havuzdan çekiyor:
`pt_b` (29 ay runway), `pt_c` (♾️ karlı, Series C) ve `pt_e`'de kurucu ipucu **"Runway
her şeydir. Nakit biterse oyun biter."** diyordu — karlı bir Series C şirketi için absürt.
Evre/moral/karlılık bazlı ipucu seçimi hâlâ yok.

**P2-1 · Geç-oyun prestij görseli — KISMEN.** `pt_c`'de 🦄 duvar logosu, kahve istasyonu,
gelişmiş şehir silüeti var (güzel detaylar). Ama çalışan grid'i hâlâ ~24 birebir aynı
küçük figür; "bina büyümüyor / ilerleme hissi vermiyor" eleştirisi büyük ölçüde duruyor.

**P2-5 · Tur kutlamasına "yeni açıldı" satırı — DÜZELMEDİ.** `FundingRoundView` yeni ofis
adını gösteriyor ama "Yeni: X modülü açıldı!" vurgusu yok.

**Karlıyken "+$X/ay kâr" göster — DÜZELMEDİ.** `pt_c`'de runway hâlâ sadece "♾️ karlı";
HUD aylık kâr rakamını göstermiyor (pozitif pekiştirme fırsatı kaçıyor).

### 3. Yeni özellik önerileri (3 adet, somut)

**Ö-1 · [P0] Garantili kriz lifeline + tek "Acil Köprü/Yatırımcı" kartı.**
*Ne:* runway<2 veya nakit<0 olduğunda `pick()` MUTLAKA bir kurtarma kartı döndürsün ve
ilk kez bu eşiğe inildiğinde `forceDecisionIfAvailable()` ile ANINDA tetiklensin.
*Neden:* `pt_d3`'te oyun ölmekte olan oyuncuya nakit harcatan "sunucu çöktü" kartı
sundu — adaletsiz ve sürükleyiciliği kıran #1 sorun. Bu olmadan iflas eğitici değil.
*Nasıl:* `DecisionSystem.pick`'e bir "urgency" dalı: `model.runwayMonths < 2 || cash<0`
ise `eligible`'ı yalnızca `category == .crisis && (en az bir choice'ta net +cash)`
kartlarına daralt; ayrıca yeni bir `emergency-bridge` kartı ekle ("Acil melek: +$X nakit,
−%Y hisse" / "Köprü kredisi: +nakit, gelecek faiz" / "Acil işten çıkarma: −maaş yükü").

**Ö-2 · [P0/P1] Ofis sahnesinde toplanabilir balonlar (aktif dokunma döngüsü).**
*Ne:* Ofiste ara sıra (örn. her 12-25 sn) 💡/💰/🐛 balon belirsin; dokununca küçük ödül
(nakit sıçraması / geçici büyüme boost'u / küçük bug-penaltısı). Toplanmazsa solup gider.
*Neden:* P0-2 hâlâ açık; `pt_a`-`pt_c` arası 22-40 sn ölü zaman var ve sahne tamamen
dekoratif. "Tap-to-collect" oyunu "uygulama" hissinden "oyun" hissine taşır — idle
türünün temel çekirdeği.
*Nasıl:* `OfficeScene`'e `touchesBegan` + periyodik `spawnCollectible()`; tıklamada
`model.collectBubble(kind:)` → `GameModel`'de küçük efekt + juice (mevcut konfeti
altyapısı yeniden kullanılabilir).

**Ö-3 · [P1] Stage 3-5'e özel "Büyük Proje" mekaniği + tur kutlamasında duyuru.**
*Ne:* Series A/B/C'de açılan tek-seferlik büyük yatırımlar (örn. "Yapay Zeka Otomasyonu"
stage3, "Veri Platformu" stage4, "Küresel Altyapı" stage5) — pahalı ama kalıcı çarpan.
Tur kapanınca `FundingRoundView`'da "🔓 Yeni açıldı: X" satırı.
*Neden:* P1-2 + P2-5 birlikte; orta-oyun platosu (`pt_b`/`pt_e`'de doğrulandı) ve
"yeni oyuncak yok" sorununu çözer, number-go-up dopaminini pekiştirir.
*Nasıl:* `Balance.modules`'a `unlockStage: 3/4/5` modüller (yapısal olarak mevcut sistemi
kullanır, sadece dizi ekleme); `FundingRoundView`'a yeni-açılan modülleri listeleyen satır.

### 4. Hızlı kazanımlar (bu oturumda doğrulanan)

- **Karlı/sağlıklı ipucu** (P2-2 tamamlama): `tipText`, runway≥3 iken bile evre/karlılığa
  bakıp ipucu seçsin — `pt_c`'deki "Runway her şeydir" absürtlüğünü bitirir (birkaç koşul).
- **Karlıyken HUD'da "+₺/$X/ay kâr"** göster (`runwayText`) — `pt_c`'de pozitif pekiştirme
  fırsatı boşta; ♾️ yerine aylık net kâr rakamı motive eder.
- **`speed`'i GameState'e kaydet** — şu an yeniden açılışta 1×'e dönüyor; tek alan ekleme.
- **Büyüme sekmesine ilk-açılış işareti/rozet** — oyuncu CAC/bütçe döngüsünü kaçırmasın
  (ekran çok iyi ama keşfedilmesi gerekiyor; Ofis'te küçük "📈 reklamı ayarla" ipucu).
- **`try` para birimi için büyüklük ölçeği** (opsiyonel): TL seçilince ARPU/nakit'i ~×35
  bir görüntü-çarpanıyla göster ki ₺3.5 ARPU absürtlüğü gitsin (yalnızca görüntü katmanı).
