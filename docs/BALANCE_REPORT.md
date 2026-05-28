# Unicorn: Garajdan Zirveye — Ekonomi Denge Raporu

> Bu rapor `Tools/BalanceSim` SwiftPM aracının çıktısına dayanır. Araç,
> `GameModel.swift` idle-ekonomi formüllerini BİREBİR kopyalar ve "akıllı oyuncu"
> politikasıyla 0.1 sn tick (gerçek tick periyoduyla aynı) zaman-bazlı simüle eder.
> Zaman ölçeği: **1 oyun-ayı = 60 gerçek saniye**.
>
> Çalıştırma: `cd Tools/BalanceSim && swift run`

---

## 0. Model değişikliği (bu sürüm) — yeni ekonomi

Önceki sürümde burn tek bir `fixedMonthlyCost(stage)` tablosuydu ve büyüme tek
parçaydı. Yeni model gerçek-hayat SaaS ekonomisine yaklaştı:

- **Kalemlere ayrılmış OpEx.** `Balance.costItems` (6 kalem) sürücüye göre ölçeklenir:
  - `perSeat` (çalışan başına): Ofis Kirası, SaaS Lisans, Ekipman, Genel & İdari
  - `perThousandUsers` (1000 kullanıcı başına): Bulut & Sunucu
  - `perStage` (funding evresi büyüdükçe): Yasal & Muhasebe
  - İndirimler: modül 6 (`infraCostReduce` → bulut), modül 7 (`rentCostReduce` → kira id 0).
  - `burnPerMonth = payrollPerMonth + opexPerMonth + adSpendPerMonth`.
- **Pazarlama bütçesi + CAC.** Büyüme iki parçaya ayrıldı:
  - `organicUserGrowthPerMonth` (pazarlama ekibi + viral + itibar)
  - `paidUserGrowthPerMonth = adBudget / currentCAC`
  - `currentCAC = baseCAC · cacStageScaling^stage · (1 + adBudget/absorption) / qualityFactor`
    — harcama ölçeğiyle CAC artar (doygunluk), pazarlama ekibi absorption'ı büyütür,
    ürün/itibar (`qualityFactor`) CAC'i düşürür.
  - `LTV = arpu/churn`, sağlıklı eşik `LTV:CAC > 3`.
- **8 modül (id 0-7), 5 departman, 7 evre** (yapı değişmedi).

---

## 1. Akıllı oyuncu modeli (sim politikası)

Her tick, oyuncu parası yettikçe **en kısa geri-ödeme süreli** aksiyonu alır:

- **Geri-ödeme** = `maliyet / (aksiyonun aylık net nakit akışına marjinal katkısı)`.
- İşe alım artık hem maaş HEM kalemli OpEx (kira+lisans+ekipman+genel) yükü getirir;
  marjinal-net hesabı `netPerMonth = mrr − (payroll + opex + reklam)` üzerinden
  yapıldığı için bu otomatik dahildir. Modüller verim/gelir artırır ya da gider
  kalemini düşürür (genelde tek seferlik maliyet).
- **Reklam bütçesi kararı (YENİ):** Reklam, sürdürülebilir bir KÂR FAZLASINDAN
  finanse edilir. Birim ekonomi sağlıklıyken (LTV:CAC ≥ 3) oyuncu, reklamsız çekirdek
  net kârının bir oranını (oran yükseldikçe %40→%85) reklama ayırır ve bu hedefe
  kademeli yaklaşır. **İlk tur (Pre-seed) alınmadan ve kâr oluşmadan reklam AÇILMAZ**
  (erken/aşırı harcama cezalandırılır). Runway < 2 ay veya LTV:CAC < 2 olursa bütçe
  hızla kısılır/sıfırlanır.
- **Runway < 2 ay** olacaksa işe alım/harcama durur (nakit korunur) — disiplinli oyuncu.
- **Değerleme** bir sonraki tur hedefini aşınca tur **hemen** toplanır.
- Erken evre "bootstrap": kapasite/kalite (Mühendislik) ile büyüme (Pazarlama)
  dengelenir — dev pazarlamaya yetişemiyorsa önce dev alınır (yoksa kapasite dolar,
  churn patlar, kalite/CAC bozulur).

> Not: Karar kartları (`DecisionSystem`) deterministik olmadığı için sim'e dahil
> edilmedi — temel ekonomi eğrisi ölçülüyor. Moral/itibar dinamiği dahildir.

---

## 2. Çekirdek eğri (retention ödülleri HARİÇ — saf ekonomi referansı)

> Aşağıdaki tablo **retention döngü ödülleri devre dışı** bırakılmış "saf çekirdek
> ekonomi" eğrisidir — birim ekonominin referans çizgisi. Retention ödüllerinin
> (moral/itibar/sezon çarpanı) bu eğriye etkisi **§9'da** ayrı ölçülür. Aktif
> retention oyuncusunun gerçek eğrisi ~76 dk'dır (§9).

### Funding turlarına ulaşma süreleri

| Evre        | Gerçek süre   | Oyun-ayı | Hedef değerleme | Önceki turdan aralık |
|-------------|---------------|----------|-----------------|----------------------|
| Garaj       | 0             | 0        | —               | —                    |
| Pre-seed    | **3d 27sn**   | 3.4      | $500K           | +3d 27sn             |
| Seed        | 15d 22sn      | 15.4     | $3M             | +11d 55sn            |
| Series A    | 36d 05sn      | 36.1     | $15M            | +20d 43sn            |
| Series B    | 1s 07d 31sn   | 67.5     | $75M            | +31d 26sn            |
| Series C    | 1s 23d 28sn   | 83.5     | $300M           | +15d 57sn            |
| **Unicorn** | **1s 35d 57sn** | **95.9** | **$1B**       | +12d 29sn            |

**Garaj → Unicorn toplam aktif oynama: ~96 dakika (~1.6 saat), 96 oyun-ayı.**

### İlk 5 dakika "hook"

| Kilometre taşı       | Süre   |
|----------------------|--------|
| İlk kullanıcı        | 0 sn   |
| İlk 1.000 kullanıcı  | 2d 15sn |
| İlk pozitif net/ay   | 7d 33sn |
| İlk reklam harcaması | 12d 20sn (= Pre-seed sonrası, kârlıyken) |
| **İlk tur (Pre-seed)** | **3d 27sn** (hedef ~3-5 dk ✅) |

### Unicorn anı snapshot

| Metrik          | Değer        |
|-----------------|--------------|
| Kullanıcı       | ~357K        |
| ARPU            | $35.6        |
| MRR             | $12.70M/ay   |
| Burn            | $7.21M/ay (MRR'ın %57'si) |
| devPower        | 104.2 (kapasite ~156K) |
| Churn           | %2.3/ay      |
| LTV / CAC       | $1.56K / $295 → LTV:CAC 5.3 |
| Reklam bütçesi  | $4.66M/ay (zirve $4.73M) |
| Morale / İtibar | 74 / 35      |
| Değerleme       | $1.08B       |
| Kurucu hisse    | %46.9        |
| Toplam işe alım | 186          |

---

## 3. OpEx dağılımı (burn'deki pay) — evre evre

Her evreye **ilk varışta** alınan anlık görüntü (reklam o anda kâr durumuna göre
açık/kapalı olabilir):

| Evre      | Maaş% | Kira% | Lisans% | Bulut% | Yasal% | Ekipm% | Genel% | Reklam% | Toplam burn |
|-----------|------:|------:|--------:|-------:|-------:|-------:|-------:|--------:|-------------|
| Garaj     | 54.7  | 8.5   | 3.0     | 0.0    | 30.4   | 1.9    | 1.3    | 0.0     | $1.64K/ay   |
| Pre-seed  | 77.1  | 10.1  | 2.9     | 0.1    | 6.5    | 2.0    | 1.4    | 0.0     | $15.47K/ay  |
| Seed      | 64.5  | 6.5   | 1.9     | 0.1    | 3.9    | 1.4    | 1.1    | 20.6    | $38.76K/ay  |
| Series A  | 87.1  | 7.3   | 1.8     | 0.1    | 1.4    | 1.3    | 1.1    | 0.0     | $144.21K/ay |
| Series B  | 48.4  | 3.0   | 0.7     | 0.0    | 0.4    | 0.5    | 0.5    | 46.5    | $712.53K/ay |
| Series C  | 42.7  | 2.1   | 0.5     | 0.0    | 0.1    | 0.4    | 0.4    | 53.9    | $2.58M/ay   |
| Unicorn   | 33.2  | 1.4   | 0.3     | 0.0    | 0.0    | 0.2    | 0.2    | 64.6    | $7.21M/ay   |

**Okuma:**
- **Maaş baskın** her evrede (en küçük payı bile %33). Reklam açıkken pay ona göre paylaşılır.
- **Kira ikinci** OpEx kalemi (perSeat × stage 1.40 ölçeği → ofis evreyle pahalanır).
- **Yasal & Muhasebe** Garaj'da yüksek görünür (%30) çünkü orada henüz ekip 1 kişi,
  ama mutlak tutar küçük ($500 taban); ölçek büyüdükçe payı erir — gerçekçi.
- **Bulut** ölçekle çalışan (perThousandUsers) ama mutlak olarak küçük kalem —
  `Sunucu Optimizasyonu` modülüyle %75'e kadar indirilebildiği için ileri evrede
  burn'ün ~%0.0'ına iner. (Modül ölü değil: oyuncu 5/5 alıyor; erken-orta evrede
  görünür bir tasarruf kalemi.)
- **Reklam**, açıldıktan sonra ölçeğin baskın kalemi olur (Unicorn'da %64.6) —
  pazarlama bütçesi gerçek bir motor.

---

## 4. Reklam bütçesinin etkisi (bütçeli vs bütçesiz)

| Senaryo | Garaj→Unicorn | Not |
|---------|---------------|-----|
| **Bütçeli oyuncu** | **1s 35d 57sn** (95.9 dk) | Reklam politikası aktif |
| Bütçesiz oyuncu (reklam KAPALI) | 1s 43d 08sn (103.1 dk) | Sadece organik büyüme |

- **Reklam bütçesi Unicorn'u %7 hızlandırdı** (103.1 → 95.9 dk).
- Toplam edinilen kullanıcının **%54'ü ücretli** kanaldan (287K ücretli / 245K organik).
- Toplam reklam harcaması $57.98M; zirve aylık bütçe $4.73M.
- Zirve LTV:CAC 38 (geç-oyun ARPU $35 + düşük churn = çok yüksek LTV); final 5.3 —
  sağlıklı SaaS bandında. CAC `cacStageScaling 1.25^stage` ile büyüdüğü için ileri
  evrede reklam "bedava para basma" değil; politika hedef bütçeyi kârla sınırlıyor.

**Kaldıraç dengesi:** Sağlıklı birim ekonomide gaza basmak ölçülebilir bir hız
kazandırıyor (+%7); **erken/kârsız gazlama yapılamıyor** (stage<1 ve kâr<0'da bütçe
kapalı). Aşağıdaki acemi testi, disiplinsiz harcamanın iflasla cezalandığını gösterir.

---

## 5. İflas adaleti

| Oyuncu | Sonuç |
|--------|-------|
| **Disiplinli (2 ay runway tamponu, reklam kârla sınırlı)** | İflas YOK; ekonomi sürdürülebilir, final nakit $9.41M, runway ∞. |
| **Acemi (tampon yok, runway umursamaz, erken reklam gazlamaya çalışır)** | **İFLAS @ 2d 09sn** (Garaj). Aşırı erken işe alım = ölüm. İflas GERÇEK bir risk ✅ |

- En riskli pencere: ilk ~7.5 dk (ilk pozitif net/ay'a kadar). Burn, gelirden önce gelir.
- Cash<0 olunca moral hedefi −40 düşer; istifa/üretim sarmalı gerilimi pekiştirir.
- Acemi, Garaj'da iflas ettiği için reklamı hiç açamadan ölür — model, "önce
  sürdürülebilir ekonomi, sonra reklam" disiplinini yapısal olarak dayatır.

---

## 6. Ölü / baskın kalem-modül kontrolü

- **Ölü içerik YOK.** Akıllı oyuncu 5 departmanın tümünü (25-53 kişi) ve 8 modülün
  hepsini (4-5 / max) kullanıyor.
- **Pazarlama** en yüksek ham çıktı (~245) — büyüme motoru olarak beklenen baskınlık;
  ama tek başına değil: `qualityFactor` ve `userCapacity` Mühendislik'e (devPower)
  bağlı olduğu için dev/pazarlama dengesi zorunlu (bootstrap bunu sağlıyor).
- **Yeni gider-azaltma modülleri** (6 Sunucu Optimizasyonu, 7 Hibrit Ofis) ölü değil:
  ikisi de max'a çıkıyor; bulut/kira kalemlerini kıstıkları için orta evrede ROI verirler.
- **Satış** (ARPU) ve **Operasyon** (churn) geç-oyun değerleme/sürdürülebilirlik için
  yoğun alınıyor (53/25 kişi) — geç-oyunda baskın hale gelirler.

---

## 7. Tespit edilen sorunlar ve yapılan ayarlar

### Sorun: yeni OpEx + CAC modeli eski sayılarla TAM ÇÖKÜŞ
Eski sabitlerle (özellikle `baseArpu 2.5`) yeni kalemli OpEx altında oyuncu Garaj'da
~3 dk'da iflas ediyordu: per-seat giderler her işe alımı net-negatife çekiyor, küçük
MRR burn'ü karşılayamıyor, Pre-seed değerlemesine ($500K) varılamıyordu. Ayrıca reklam
politikası başlangıçta ya hiç ramp etmiyor ya da kâr fazlası yerine nakitle yarışıp
büyümeyi YAVAŞLATIYORDU (negatif kaldıraç).

### Yapılan sayısal ayarlar (yalnızca `Balance.swift` sabitleri)

| Sabit | Eski | Yeni | Gerekçe |
|-------|------|------|---------|
| `baseArpu` | 2.5 | **3.8** | Yeni kalemli OpEx (per-seat) altında birim ekonomiyi pozitif marja taşı; Pre-seed erişilebilir, eğri sürdürülebilir olsun. Cliff ~3.6 olduğu için 3.8 güvenli tampon bırakır. |
| `cacStageScaling` | 1.18 | **1.25** | CAC'in evreyle daha gerçekçi artması; ileri evrede reklam "bedava" olmasın, bütçe kararı gerçek bir tradeoff kalsın. |
| Ofis Kirası `rate` | 200 | **140** | OpEx kalemlerini gelirin makul %'sine indir; kira ikinci kalem ama maaşı boğmasın. |
| SaaS Lisans `rate` | 70 | **50** | Per-seat yükünü gerçekçi orana çek. |
| Bulut `rate` | 13 | **10** | perThousandUsers; ölçekte görünür ama burn'ü patlatmayan değer (yüksek değerler erken iflasa yol açtı). |
| Yasal `rate` | 700 | **500** | perStage; Garaj'da orantısız ağır gelmesin. |
| Ekipman `rate` | 45 | **32** | Per-seat yük dengesi. |
| Genel & İdari `rate` | 30 | **22** | Per-seat yük dengesi. |

> `baseChurn 0.05`, `viralFactor 0.045`, `startCash 40K`, `baseCAC 7`,
> `marketingAbsorption 5000`, `revenueMultiple 7`, `perUserValue 6` ve tüm
> departman/modül/stage tanımları (id-rol-sıralama) **DEĞİŞTİRİLMEDİ**.

### BalanceSim aracında yapılanlar
- Yeni model birebir koplandı: kalemli OpEx (`opexItemCost` + indirimler),
  organik+ücretli büyüme, `currentCAC`/`qualityFactor`/`ltvCacRatio`, 8 modül
  (infra/rent indirimi dahil).
- "Akıllı oyuncu"ya **reklam bütçesi politikası** eklendi (kârı büyümeye geri
  yatırma; stage<1 / kârsızken kapalı; LTV:CAC ve runway eşiğine duyarlı).
- İşe alım marjinal-net'i artık per-seat OpEx artışını otomatik içeriyor.
- Rapora **OpEx dağılımı (evre evre)**, **reklam bütçesi karşılaştırması** ve
  **gider dökümü** çıktıları eklendi.

**Etki:** İflas-3dk → tam çalışan eğri. Pre-seed 3.4 dk (hook ✅), Unicorn ~96 dk
(emek + ulaşılabilir ✅), reklam anlamlı kaldıraç (+%7, kullanıcının %54'ü ücretli ✅),
OpEx gerçekçi (maaş baskın, kira ikinci, burn MRR'ın %57'si ✅), acemi hâlâ iflas
edebiliyor (gerilim ✅).

---

## 8. Retention için öneriler (kod değişikliği gerektirenler — uygulanmadı)

Aşağıdakiler sahip olunan dosyaların dışında (GameModel/UI/Content) olduğu için
sadece öneri:

1. **Reklam bütçesi onboarding'i.** Yeni mekanik güçlü ama görünür değilse keşfedilmez;
   ilk Pre-seed sonrası "Artık reklam bütçesi açabilirsin, LTV:CAC'ine dikkat et"
   ipucu/tutorial kancası, kaldıracın kullanılmasını sağlar.
2. **LTV:CAC göstergesi HUD'da.** `ltvCacRatio` ve `paybackMonths` zaten hesaplanıyor;
   bunları canlı göstermek bütçe kararını öğretici/tatmin edici yapar (yeşil/kırmızı).
3. **OpEx panosu.** `costBreakdown` mevcut; evre evre maaş/kira/bulut dağılımını grafiklemek
   "şirketim büyüyor" hissini ve gider-azaltma modüllerinin (6/7) değerini görünür kılar.
4. **Düşük-runway acil kararı.** Acemi ilk ~7.5 dk'da ölüyor; `forceDecisionIfAvailable`
   ile tetiklenen "köprü kredisi/melek yatırımcı" kartı hem öğretici hem retention artırıcı.
5. **Prestij/NG+ döngüsü.** `founderXP`/`bankruptcies` mevcut; iflası "ceza" değil
   "daha güçlü yeniden başla" meta-ilerlemesi olarak çerçevelemek döngüyü besler.

---

## 9. Retention döngü ödüllerinin ekonomiye etkisi (math-denge turu — madde 6)

Roadmap maddeleri 1-5 ile eklenen "tamamlanan döngü" sistemleri (Lig/Çeyrek, Günlük
Hedef/Streak, Sprint, Kohort, Sezon Finali) **nakit ödül vermez** — ekonomiye
yalnızca üç dolaylı kanaldan akarlar. BalanceSim bu kanalları modelleyecek şekilde
genişletildi (`seasonMultiplier` deptOutput'a, `streakMoraleBonus` moraleTarget'a,
itibar dokunuşları + küçük itibar tabanı) ve **"tipik aktif retention oyuncusu"**
varsayımıyla zaman-tabanlı tetiklenir (sprint her 0.5 ay, çeyrek her 3 ay, sezon her
4 çeyrek; anlık moral/itibar dokunuşları gerçekçi `onlineFactor = 0.35` ile ölçeklenir
— oyuncu kesintisiz online değil).

### Üç etki kanalı

| Kanal | Mekanizma | Kaynak ödüller |
|-------|-----------|----------------|
| **Moral → üretim** | `moraleFactor = 0.5 + morale/100`, tüm departman çıktısını çarpar | streak'in `moraleTarget`'a kalıcı katkısı (en güçlü) + sprint/terfi/sezon anlık dokunuşları |
| **İtibar → büyüme/CAC** | organik `(0.5+rep/100)`, viral `(rep/50)`, qualityFactor (CAC↓) | terfi +4, sprint +2, günlük +2, sezon +6 (anlık; tabana küçük kalıcı katkı) |
| **Sezon çarpanı → üretim** | `seasonMultiplier` deptOutput'a doğrudan çarpan | +%2/sezon, **+%15 tavan** (kalibrasyon sonrası) |

### Net etki (gerçek `swift run` çıktısı)

| Senaryo | Garaj→Unicorn | Final moral / itibar | Sezon çarpanı |
|---------|---------------|----------------------|----------------|
| **Ödülsüz** (saf çekirdek ekonomi) | 1s 35d 57sn (**95.9 dk**) | 74 / 35 | ×1.00 |
| **Ödüllü** (aktif retention oyuncusu) | 1s 16d 20sn (**76.3 dk**) | 89 / 49 | ×1.12 (6 sezon) |

- **Üst-sınır hızlanma: ~%20** (95.9 → 76.3 dk). Bu, **HER sprinti kazanan, streak'ini
  hiç kırmayan, 6 sezon bitiren ideal/sürekli-aktif oyuncu** için tavan değeridir.
  Tipik oyuncu (sprintlerin bir kısmını kaçıran, streak'i ara sıra kıran) ~%10-12
  görür. Karşılaştırma: reklam bütçesi kaldıracı %7 (§4) — retention emek-karşılığı
  ve daha büyük, ama "bedava" değil: oyuncu bunu sürekli döngü kazanarak hak eder.
- En güçlü tek kanal **moral** (streak `moraleTarget`'a +4 kalıcı, moraleFactor üzerinden
  ~+%10 üretim). İkinci **itibar** (büyüme/CAC). **Sezon çarpanı** doğrudan ama küçük
  (tek koşuda ×1.12, tavan ×1.15).
- **Eğri tatmin edici kaldı:** hook (Pre-seed 3.1 dk ✅), tur trendi hâlâ kademeli
  yavaşlıyor, birim ekonomi sağlıklı (LTV:CAC 7.9, churn %1.7), final değerleme $1.06B.
- **İflas hâlâ adil risk:** retention ödülleri Garaj'da (ödül toplanmadan önce)
  oluşmadığı için acemi oyuncu @ 2d 09sn iflas etmeye devam ediyor (§5 korunur).

### Yapılan kalibrasyonlar (yalnızca sayısal sabitler)

| Sabit | Eski | Yeni | Gerekçe |
|-------|------|------|---------|
| `streakMoraleCap` | 8 | **4** | Streak, moraleFactor üzerinden en güçlü tek üretim kaldıracıydı. Kalibrasyonsuz toplam etki ~%47'ye çıkıyordu (ezici). Tavanı yarıya çekmek ödülü "hoş ama ezici değil" banda taşıdı. |
| `streakMoralePerDay` | 0.8 | **0.5** | Tavanla orantılı; streak'in günlük katkısını yumuşat (kalıcı moral kaldıracını azalt). |
| `seasonOutputBonusCap` | 0.20 | **0.15** | Doğrudan üretim çarpanı en doğrudan kaldıraç. Tek Garaj→Unicorn koşusunda ~6 sezon birikir (×1.12); tavanı +%15'e çekmek uzun-vade prestij değerini korurken eğriyi bozmayan bir üst sınır verir. |

> Anlık ödül dokunuşları (sprint +4 moral, terfi +8 moral/+5 itibar, sezon +10 moral/
> +8 itibar, günlük +5 moral/+2 itibar) ve `monthsPerSprint/Quarter`, `quartersPerSeason`,
> `seasonOutputBonusPerSeason (+%2)` **DEĞİŞTİRİLMEDİ** — bunlar zaten küçük ve geçici
> (moral `moraleAdjustRate` ile hedefe, itibar 0.002/tick ile tabana erir). Kalibrasyon
> sadece KALICI kanalları (streak moraleTarget + sezon çarpan tavanı) hafifçe kıstı.

### BalanceSim'de yapılanlar (madde 6)
- `deptOutput`'a `seasonMultiplier` çarpanı eklendi (GameModel ile birebir).
- `moraleTarget`'a `streakMoraleBonus` (aktif oyuncu steady-state) eklendi.
- `advanceEconomy` itibar tabanı sabit-20 yerine `reputationFloor` (ödüllerle hafifçe
  yükselen) kullanır.
- `Runner.advanceRetention()`: sprint/çeyrek/sezon kapanışlarını oyun-zamanına bağlı
  tetikler; aktif-oyuncu varsayımları (`sprintWinRate 0.70`, `quartersPerPromotion 2`,
  `onlineFactor 0.35`) ile moral/itibar dokunuşu + kalıcı sezon çarpanı uygular.
- `RETENTION_REWARDS_ENABLED` anahtarı ile ödüllü/ödülsüz koşu karşılaştırması (§9 tablosu),
  reklam karşılaştırması (§4/g) artık retention KAPALI koşar ki reklam kaldıracı izole kalsın.
