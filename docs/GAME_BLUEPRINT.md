Tüm doğrulamalar tamam. Net bir gerçeklik tablom var. Şimdi nihai blueprint'i yazabilirim. Kritiğin önemli bir kısmı yanlış çıktı (metrikler hesaplanıyor ve görünüyor, post-mortem nedensellik motoru çalışıyor) — bu blueprint'in monetizasyon iddiasını kritikten DAHA güçlü kılıyor. Ama kritiğin doğru çıkan kusurları (result toast'ta uçuyor, mechanic→ders köprüsü yok, pendingEffects yok, cashPercent exploit, sahte istatistik, pitch-deck/mentor kıyası/statü-paylaşımı) tamamen giderilecek.

Nihai blueprint'i üretiyorum.

---

# UNICORN — Garajdan Zirveye: NİHAİ ÜRÜN BLUEPRINT'İ

*Aday kurucular için bir startup'ı yaşatan, öğreten ve "ödemeye değer" kılan mobil simülasyon. Mevcut oyunun üstüne inşa edilmiş tek belge.*

**Etiket sözlüğü (kritiğe göre revize — koda karşı doğrulandı):**
- **[VAR]** = bugün kodda çalışıyor (doğrulandı).
- **[GÖRÜNÜR DEĞİL]** = mekanik var, hesaplanıyor, ama oyuncu kararın anında tek bakışta göremiyor.
- **[YOK]** = ne mekanik ne görünür; üretilmesi gerek.
- Her pazarlama iddiasının yanında **Vaat-Borç** sütunu var: "bunu hangi kod karşılıyor?" Karşılığı **[YOK]** olan iddia App Store metnine ve paywall'a GİREMEZ (Kural-0, aşağıda).

> **KURAL-0 (kritikten doğan ana kural):** Bu blueprint'in satış iddiası, *bugün kodda karşılığı olan* özelliklerle sınırlıdır. "Zincirleme sonucu yaşa" gibi gelecekteki bir motora (pendingEffects) dayanan hiçbir cümle, o motor sevk edilene kadar pazarlamada kullanılmaz. Aksi halde oyuncu ilk oturumda farkı görür, iade ister, rating düşer.

---

## 0. Kritik Düzeltmesi: Gerçeklik Kontrolü (kodu kendim okudum)

Kritik haklı olduğu yerlerde acımasızca uygulandı; **yanlış olduğu yerlerde düzeltildi** — çünkü yanlış bir özür blueprint'i gereksiz zayıflatır. Koda karşı doğruladığım gerçek durum:

| Kritiğin iddiası | Kodda gerçek | Sonuç |
|---|---|---|
| "Balance.swift runway/LTV/CAC hesaplamıyor bile" | **YANLIŞ.** Hesaplamalar `GameModel.swift`'te computed property: `runwayMonths` (s.396), `ltv` (s.324), `ltvCacRatio` (s.326), `paybackMonths` (s.328), `burnPerMonth` (s.363). | Metrikler **VAR ve doğru**. |
| "Görünür sayı = kurgu, HUD'da yok" | **KISMEN YANLIŞ.** Runway HUD orta satırında renkli (HUDView s.171, <3 ay kırmızı/<6 amber). LTV, LTV:CAC, Payback **GrowthPanel'de** görünür + sağlık yorumu (GrowthPanel s.104-157). Founder equity EventOverlays'de. | Görünürlük **kısmen VAR**. Eksik: bunların **karar kartının üstünde**, kararın anında görünmesi + Cap Table ÖZETİ + PMF metresi. |
| "Post-mortem nedensellik zinciri YOK" | **YANLIŞ.** PostMortemView'de **6 kurallı diagnostic motor çalışıyor** (s.200-280): "Ay X'e kadar Y işe alım burn'i şişirdi; maaşlar giderin %Z'i oldu — runway erken zayıfladı" + state-bağlı 3 strateji önerisi. | Zincir **VAR** (iflas anında). Eksik: **Perde/çeyrek geçişlerinde** aynı motorun pozitif versiyonu. |
| "result kartı 3.5sn toast'ta uçuyor" | **DOĞRU.** `choice.resultLine → pendingToast` (GameModel s.1161); kalıcı görünmüyor. | **[YOK]** — gerçek kusur. |
| "mechanic→ders köprüsü YOK" | **DOĞRU.** Ders sadece `category` ile filtreleniyor (LessonsContent s.225); `mechanic` alanı (20 derste etiketli) hiçbir koda bağlı değil. | **[YOK]** — gerçek kusur, en yüksek ROI. |
| "pendingEffects gecikmeli motor YOK" | **DOĞRU.** Grep sonucu sıfır. Etkiler anında uygulanıyor; gecikme sadece result metninde anlatılıyor. | **[YOK]** — gerçek kusur. |
| "cashPercent istismarı" | **DOĞRU.** `pricing-change` kartı tekrarlanabilir + `cashPercent(0.25)` tavansız (AUDIT #2). | **[YOK→FIX]** — gerçek kusur. |

**Sonuç:** Kritiğin "bugün hiç değer yok, satılamaz" tezi fazla sert. Doğrusu: **değer zincirinin 4/5 halkası bugün VAR** (gerçek ekonomi + görünür runway/LTV + çalışan post-mortem nedensellik + 20 pratik ders). Eksik olan 2 halka, değeri **kalıcı ve bağlamsal** kılan ciladır: (a) result/dersin uçup gitmemesi (#26 + #19), (b) gecikmeli sonuç motoru (#6). Bu yüzden Kural-0 hâlâ geçerli ama hedefi daralır: **satışa hazır olmak için TÜM oyunu değil, ÖNCELİK 1'i (görünürlük köprüsü + kalıcı kart) sevk etmek yeterli.**

---

## 1. Vizyon & Vaat

Unicorn, **üniversite öğrencileri, yeni mezunlar ve startup kurmak isteyenlere** kurucu sezgisini — *kararı sen verirsin, sonucunu güvenli ortamda yaşarsın* döngüsüyle — bir kahve fiyatına (tek seferlik, reklamsız, Türkçe) prova ettiren mobil simülasyondur.

**Vaat tek cümle (dürüst, abartısız):** *"Bir startup'ı kurmayı öğretmez — kurucu gibi DÜŞÜNMEYİ prova ettirir. Oyna, batır, nedenini gör, gerçekte daha az hata yap."*

Konumlama bilinçli olarak **"startup kurmayı öğretir" değil, "kurucu sezgisini ucuza prova ettirir."** Bu hem daha dürüst hem daha güçlü: kimse bir oyunun gerçek term-sheet pazarlığını öğreteceğine inanmaz, ama "kararı 50 kez prova ettim, refleksim oturdu" inandırıcıdır.

Çekirdek fark (rakiplerde olmayan): kararının sonucu **kendi batışının açıklaması olarak** geri döner. Bir idle oyunu seni eğlendirir ama öğretmez; bir YC kursu öğretir ama pasif izletir. Unicorn ikisinin arasındaki boşlukta: **karar → sonuç → kendi hatanın teşhisi → o anın dersi.**

---

## 2. Hedef Personalar

| Persona | "Aha" anı (bugün üretilebilir mi?) | Ödeme yatkınlığı |
|---|---|---|
| **Üniversite öğrencisi** (2.-3. sınıf, merak var) | İlk iflasın post-mortem'inde "Ay 18'e kadar 5 işe alım burn'i şişirdi; maaşlar giderin %60'ı oldu — runway erken zayıfladı" satırını görüp **"AAA, runway bu yüzden önemliymiş"** demesi. ✅ **Bu satır bugün PostMortemView'de üretiliyor.** | En dar bütçe, en yüksek ROI hassasiyeti. Çapa: ₺49–99 (kahve/sinema). Abonelik İSTEMEZ. Ücretsiz başla → değeri hissedince tek seferlik küçük ödeme. Öğrenci indirimi çok çeker. |
| **Yeni mezun** (corporate vs. kendi işi kararsızlığı) | İki ayrı oyunda iki ayrı stratejiyle (temkinli bootstrap vs. agresif VC) **farklı yollardan Unicorn'a varması** → "tek doğru yol yokmuş." ⚠️ **Felsefe VAR (4 arketip prensibi), kanıt KISMİ** (arketip tespiti GameState'te yok; BALANCE_REPORT denge iddiası audit #3'e göre temkinli okunmalı). | En net ROI gerekçesi. Çapa: bir startup kitabının (₺250–400) yarısı. Tek seferlik ₺149–299 kabul edilebilir. |
| **Startup kurmak isteyen** (fikri var, yürütmeyi bilmiyor) | Fikrine âşık, PMF olmadan ölçekleyip batması; post-mortem'in "burn gelirin önündeyken frene basılmadı" demesi → **"bunu gerçekte yapsaydım her şeyi kaybederdim."** ✅ **Kural 6 bu satırı bugün üretiyor.** | En yüksek yatkınlık, en şüpheci. Çerçeve: "bir kitabın yarısı fiyatına, kitabın anlatamadığını yaparak." Gerçekçilik + derinlik fiyatı haklı çıkarır. |

**Ortak çekirdek:** Üçü de pasif içerik değil **deneyimsel prova** istiyor; üçü de "ders gibi"den nefret ediyor ama "gerçekten öğrendim" kanıtı bekliyor. Bu gerilimin çözümü oyunun zaten yaptığı: koçluk tonlu, suçlamasız post-mortem + bağlamsal "Defter" dersleri.

---

## 3. Pazar Konumu

**Rakipler ve boşluk:**
- **Oyunlar** (Startup Company, Game Dev Tycoon, idle tycoon'lar): Eğlendiriyor, gerçek startup ekonomisini (LTV:CAC, runway, dilution) **açık öğretmiyor**; çoğu PC, İngilizce; idle'lar sıfır öğrenme.
- **Kurslar/eğitim** (YC Startup School, Reforge, Maven, kitaplar): Öğretiyor ama **pasif**, pahalı/kurumsal, "kararı sen ver, sonucunu yaşa" döngüsü yok.

**4 net boşluk:** (1) eğlence + gerçek öğrenme kesişimi boş; (2) ödenebilir premium (tek seferlik, IAP'siz, gerçek ders veren) boş; (3) Türkçe + suçlamayan koçluk tonu boş; (4) risksiz deneme + **kendi hatanın teşhisi** ("burn frene basılmadı" diye geri dönen) hiçbir rakipte yok.

**Konum:** *"Bir startup'ı kurmadan önce kurucu gibi düşünmeyi, eğlenerek ve yaparak, bir kahve fiyatına, Türkçe prova ettiren tek mobil simülasyon."*

> **Not (kritikten):** Fiyat kıyaslarında *mentor seansı / bootcamp* kullanılmayacak — kategori hatası ("bir oyun mentor yerini mi tutar?" ters tepkisi). Tek dürüst çapa: **bir startup kitabı** (aynı içeriği okumak yerine yaparak).

---

## 4. Bedelini Ödediğin An Öğrendiğin 9 Şey

*(Eski "Müfredat" başlığı kaldırıldı — persona "müfredat" görünce kaçar. CB Insights yüzdeleri metinden çıkarıldı, yalnızca aşağıdaki tasarımcı notunda kalır.)*

İlke: **bir beceri, oyuncunun onu ihmal etmesinin BEDELİNİ ödediği evrede karşına çıkar** — öğrenme anlatımdan değil, kendi kararının sonucundan gelir. Persona-yüzü dille:

1. **Ürün-Pazar Uyumu** (Garaj) — "İnsanların istediğini yapmadan büyümeye para yakarsan, delik kovaya su taşırsın."
2. **Runway & Nakit** (Garaj) — "Kasa ÷ aylık yakış = kaç ayın kaldı. Bunu okumazsan batarsın; oyun sana bunu 1. iflasında gösterir."
3. **Birim Ekonomisi (CAC/LTV)** (Pre-seed/Seed) — "Her kullanıcı kâr mı zarar mı? LTV:CAC 3'ün altındaysa büyüdükçe batarsın."
4. **Fundraising & Dilution** (Pre-seed/Seed) — "Kaç para aldığın değil, sende ne kaldığı."
5. **İşe Alım** (Pre-seed/Seed) — "Yavaş al, hızlı çıkar; ilk hire'lar kültürü dondurur."
6. **Fiyatlandırma** (Series A) — "Ucuz fiyat = düşük değer algısı; değer yakala."
7. **Dağıtım Kanalı** (Series A) — "Kanalı kapatırsan büyüme durur mu? O zaman senin değil, kiralık."
8. **Pivot Kararı** (Series A) — "Veriyi takip et, inada değil."
9. **Odak (Hayır demek)** (Series B–C → Unicorn) — "Strateji, neyi YAPMAYACAĞINdır."

**Yatay katman:** Her büyük kapanışta post-mortem coaching + bağlamsal Defter dersi (o beceriyle yüzleştiğin AN'da).

> **Tasarımcı notu (oyuncu görmez):** Bu 9, gerçek başarısızlık nedenleriyle (pazar ihtiyacı yok, nakit/timing, yanlış ekip, rekabet, fiyat) örtüşecek şekilde seçildi. İstatistikler ürün içinde gösterilmez, pazarlamada kullanılmaz.

---

## 5. Modül/Bölüm Şeması ("Kurucu Yolculuğu" 5 Perde)

7 funding evresi öğrenme açısından çok ince; **5 Perde'ye** gruplanır. Her Perde başında 1 cümle **niyet kartı**, sonunda **Perde Karnesi** (post-mortem'in pozitif, ilerlemeli versiyonu — DESIGN_PRINCIPLES F).

### PERDE 0 — "Hayatta Kal ve Dinle" (Garaj, Stage 0)
- **Hedef:** Runway somut bir sayıdır; PMF'siz büyüme delik kovadır.
- **Mekanik:** [VAR] startCash erimesi + 6 kalemli OpEx + maaş burn → iflas; `early-focus/early-channel/early-feedback/early-burnout/early-equity-split`; Günlük Hedef + Streak.
- **Kapanış:** İlk Pre-seed VEYA ilk iflas → **çalışan** İflas Post-Mortem.
- **Durum:** **GÜÇLÜ.** Runway HUD'da [VAR]. Eksik: [YOK] PMF metresi; [GÖRÜNÜR DEĞİL] onboarding felsefe damlası (H).

### PERDE 1 — "İlk Para, İlk Ekip, İlk Matematik" (Pre-seed + Seed, Stage 1–2)
- **Hedef:** "$500K aldım" değil "bende ne kaldı?"; LTV:CAC ≥ 3; ilk hire kültürü belirler.
- **Mekanik:** [VAR] equity kalıcı düşüşü; `angel-1/seed-termsheet/vc-board-seat/accelerator-invite/advisor-equity`; `key-hire/ctO-vs-contract/star-resign`; cacStageScaling.
- **Kapanış:** Seed kapanışı + ilk Cap Table fotoğrafı.
- **Durum:** **MEKANİK GÜÇLÜ.** LTV:CAC GrowthPanel'de [VAR]. Eksik: [YOK] Cap Table ÖZETİ tek ekranda; [GÖRÜNÜR DEĞİL] LTV:CAC rozetinin karar kartının üstünde anlık gösterimi.

### PERDE 2 — "Büyü Ama Doğru Büyü" (Series A, Stage 3)
- **Hedef:** Fiyat = değer yakalama; kanal sahip mi kiralık mı; premature scaling burada en cazip/tehlikeli.
- **Mekanik:** [VAR] ARPU + Premium Paket; `pricing-change/freemium-paywall-decision/pricing-experiment`; `partnership-offer/ad-spend-temptation`; `pivot/d7-retention-drop`; `international-launch/blitzscale-pressure`.
- **Kapanış:** Series A + "Strateji Kimliği" ilanı.
- **Durum:** **KARTLAR ZENGİN.** Eksik: [YOK] cashPercent fix (#2); [GÖRÜNÜR DEĞİL] kanal-bazlı CAC.

### PERDE 3 — "Çelişkileri Yönet" (Series B + C, Stage 4–5)
- **Hedef:** Concentration risk; board çatışmasında veriyle ikna; erken regülasyon uyumu = avantaj.
- **Mekanik:** [VAR] `whale-churn/custom-feature-trap`; `board-pressure/strategic-investor`; `gdpr-audit/scaling-crisis/cloud-bill-shock/market-downturn`.
- **Kapanış:** Series C + "Kriz Sicili" karnesi.
- **Durum:** **ORTA — seyrelme riski.** Eksik: [YOK] geç-oyun ileri-strateji kartları (#16, 6-8 kart — ücretli katmanın derinliği).

### PERDE 4 — "Unicorn ve Sonrası" (Unicorn, Stage 6)
- **Hedef:** Tek doğru yol yok; aynı hedefe farklı arketiplerle varılır.
- **Mekanik:** [VAR] unicornValuation hedefi; Sezon Finali + ünvan koleksiyonu; `acquisition-offer`.
- **Kapanış:** Unicorn kutlaması + Yolculuk Sicili + yeni-arketip daveti.
- **Durum:** **ZAYIF — ince.** Eksik: [YOK] arketip tespiti (GameState alanı) + yansıma.

### YATAY KATMAN — "Defter + Koçluk"
- **Durum:** **EN BÜYÜK KALDIRAÇ.** [VAR] 20 pratik ders (mechanic etiketli) + çalışan post-mortem motoru. [YOK] **mechanic→ℹ→bağlamsal ders köprüsü (#19)** + **kalıcı result kartı (#26)** — en zengin içerik 3.5sn toast'ta uçuyor.

---

## 6. Hızlı Zaferler & Bonuslar

**İlk 10 dakika (mikro-zaferler):**
- **HZ-1 İlk Karar Tebriği:** "Tek doğru cevap yoktu — sen kendi bahsini koydun" + ilk Defter dersi kilidi.
- **HZ-2 İlk 100 Kullanıcı** eşik kutlaması + `do-things-that-dont-scale` dersi.
- **HZ-3 "Senin Tarzın?"** (onboarding sonu): Temkinli/Dengeli/Cesur seçimi + felsefe damlası (H). Agency verir.
- **HZ-4 Mentor İlk İpucu** (dead-air sigortası): "İlk işin para değil, birinin istediğini bulmak."

**Bonus katmanlar (opsiyonel, yeni döngü AÇMAZ):**
- **B-1 Gerçek Vaka Mini-Senaryoları** (anonim, uydurma istatistik YOK): "Bir mobilite şirketi 8 şehre aynı anda açıldı. Sen olsan?" → karar → "Gerçekte ne oldu."
- **B-2 Mentor Meydan Okumaları:** "Bu hafta reklamsız +%10 büyü."
- **B-3 Rakip Kıyas ("Komşu Garaj"):** Kohort verisini nedensellik kıyasına çevir: "Rakibin 3x büyük ama runway 2 ay; sen default-alive'sın."
- **B-4 Sezgi Rozetleri** (KARAR KALİTESİNE bağlı, aktiviteye değil): "Disiplinli Hayır", "Soğukkanlı", "Veri İnsanı".
- **B-5 "Kurucu Kartım"** (paylaşılabilir, ama **öğrenme-merkezli** — bkz. Bölüm 8 düzeltmesi).
- **B-6 "Aha Yakalama"** (pendingEffects ÜZERİNE — Kural-0: bu motor sevk edilene kadar pazarlanmaz): "Hatırlıyor musun? Ay 12'de hızlı işe aldın. İşte faturası."

---

## 7. Beceri-Transfer Haritası (kritikten: "simüle ediyor" vs "farkındalık veriyor" ayrımı)

Kritiğin haklı noktası: oyun bazı şeyleri **simüle eder** (güçlü iddia), bazılarını sadece **farkındalık verir** (dürüst, daha zayıf iddia). İkisini karıştırmak boş vaattir. Ayrım satışı GÜÇLENDİRİR:

| Oyunda oynadığın | Gerçek beceri | Tür | Vaat-Borç (hangi kod?) |
|---|---|---|---|
| Runway erimesi + 6 kalemli OpEx + iflas | Default-alive refleksi | **SİMÜLE** | runwayMonths [VAR], HUD'da renkli [VAR] |
| CAC + ARPU + churn → LTV | Birim ekonomisi okuma | **SİMÜLE** | ltv/ltvCacRatio/paybackMonths [VAR], GrowthPanel [VAR]. Eksik: karar anında rozet [GÖRÜNÜR DEĞİL] |
| Funding turları + equity düşüşü | Dilution okuma | **SİMÜLE** | equity [VAR]. Eksik: Cap Table özeti [YOK] |
| `vc-board-seat` SAFE seçeneği | "Sonraki turda kaç %?" | **FARKINDALIK** | SADECE result metninde; pendingEffects [YOK] → "simüle eder" denemez |
| Term sheet hakları (pro-rata, liq pref, veto) | Term sheet okuma | **FARKINDALIK** | sadece kart metni; mekanik DEĞİL → "okumayı öğretir" YASAK iddia |
| Headcount → burn; `key-hire/star-resign` | Yavaş al hızlı çıkar | **SİMÜLE** | payroll burn [VAR]. Eksik: gecikmeli etki [YOK] |
| Moral → çıktı | Moralin etkisi | **SİMÜLE (lineer)** | [VAR]. Bileşik eğri [YOK] |
| PMF kartları | Ürün-Pazar Uyumu | **FARKINDALIK** | kartlar [VAR]; görünür PMF metresi [YOK] |
| `pivot/d7-retention-drop` | Veriye dayalı pivot | **FARKINDALIK** | kart [VAR]; state-dependent pivot [YOK] |
| `pricing-change` + ARPU | Değer yakalama | **SİMÜLE** | ARPU [VAR]. Eksik: cashPercent fix [YOK]; **fiyatlandırma Defter dersi yok** (9 çekirdekten 1'i boşta) |
| Reklam + viralFactor | Sahip vs kiralık kanal | **FARKINDALIK** | [VAR] tek-kanal; çok-kanallı CAC [YOK] |
| 4 arketip + `focus-says-no` | Strateji = neyi yapmayacağın | **FARKINDALIK** | felsefe [VAR]; arketip tespiti [YOK] |
| İflas/Çeyrek post-mortem | "Başarısızlık veridir" refleksi | **SİMÜLE** | 6-kurallı diagnostic motor [VAR] |

**Dürüstlük cümlesi (App Store'a girer):** *"Unicorn gerçek hukuki detayı, yatırımcı pazarlığının insani dinamiğini veya kod/ürün inşasını öğretmez. Sayıların birbirini nasıl etkilediğine dair SEZGİ ve trade-off REFLEKSİ kazandırır — yaparak."*

---

## 8. Monetizasyon & Nihai Teslimat

**Model:** Ücretsiz başla → "aha" anında **tek seferlik kalıcı kilit açma** (non-consumable IAP). **Abonelik YOK, reklam YOK, para/elmas YOK** — pay-to-win, "kararının sonucunu yaşa" çekirdeğini öldürür.

**Ücretsiz katman (cömert ama TAMAMLANMA hissi vermez — kritikten çözüm):** Garaj + Pre-seed/Seed (Stage 0–2) tam oynanır + **en az 1 tam iflas + çalışan PostMortem coaching** + erken Defter dersleri. Aha BEDAVA verilir — ama döngü değil. Kişiselleştirilmiş tetik aha'dan sonra:
> *"İlk şirketin Ay 18'de battı çünkü runway'i okuyamadın. Tam Sürüm'de bunu düzeltmenin 4 farklı yolunu oyna."*

Değer = tek aha değil, **tekrar deneyip farklı strateji ile düzeltme döngüsü.** Bu, "asıl aha bedava, neden ödeyeyim?" çelişkisini çözer: aha = problem teşhisi (bedava); Tam Sürüm = çözümü deneme alanı (ücretli).

**Ücretli katman ("Kurucu Tam Sürüm"), doğal kesme Series A (Stage 3):** Series A → Unicorn tüm evreler + ileri kriz/strateji içeriği (#16) + Nihai Teslimat + sınırsız sezon + 4 arketip yolculuğu + tüm ünvan koleksiyonu.

| Pazar | Fiyat | Gerekçe |
|---|---|---|
| TR | **₺149** (lansman ₺99) | Öğrenci çapası 49–99 (kahve); mezun "kitabın yarısı" |
| Global | **$6.99** (lansman $4.99) | IAP'siz tatlı nokta; Game Dev Tycoon üstü |

Kalıcı **%40 öğrenci indirimi** (promo kodu).

**Fiyat-performans çapası (kritikten: mentor/bootcamp kıyası ÇIKARILDI):**
> Bir startup kitabı ~₺300 (ve hâlâ yaparak öğrenmedin) · **Unicorn Tam Sürüm: ₺149 — tek seferlik, reklamsız, ömür boyu senin, ve kararı sen veriyorsun.**

**Nihai Teslimat — "Kurucu Karnesi" (kritikten köklü revize):**
1. **Sonuç Kartı (öğrenme-merkezli, statü değil):** "3 kez battım" YOK. Yerine: **"Bu oyunda öğrendiğim en pahalı 3 ders"** + Strateji Kimliği. Paylaşılabilir çünkü bir oyun skoru değil, bir içgörü — persona'nın merak/öğrenme kimliğini güçlendirir, statüsünü riske atmaz. **Varsayılan: ÖZEL** (paylaşım opsiyonel).
2. **Refleks Kartı (pitch-deck'in YERİNE — kritikten):** Sahte pitch-deck silindi (işe yaramaz çıktı). Yerine gerçekten taşınabilir tek şey: **"Gerçek hayatta startup kurarken kendine soracağın 9 soru"** (9 beceriden türetilmiş, oyuncunun en çok battığı 3'ü vurgulu). CV'ye değil, **kurucunun telefonuna** gider — gerçek fayda, "kariyer sigortası" çerçevesiyle tutarlı.
3. **Kurucu Karnesi (değer kanıtı):** Yetkinlik haritası — AMA bunun için **beceri-dokunuş etiketleme** gerekir (her kararın hangi beceriye dokunduğu). Bu veri bugün **toplanmıyor** [YOK]; Kural-0: karne "ustalaştığın beceriler" iddiasıyla **ancak bu etiketleme eklendikten sonra** satılır. O zamana kadar karne = "en çok yüzleştiğin 3 ders" (toast/post-mortem verisinden türetilebilir, dürüst).

İflas eden de **özel** Post-Mortem kartı alır ("İlk şirketim battı — işte gördüğüm neden"); `failure-is-data` normalleştirilir, statü riski yok.

---

## 9. Değer Psikolojisi & "YouTube'da Bedava Bulurum" Cevabı

**Kritiğin en önemli noktası:** Defter dersleri tek başına bir YouTube/blog özeti değerinde. Oyuncu bir **ders listesi** görürse "Notion'da derlerim" der — **ve haklıdır.** Değer içerikte değil, **doğru anda tetiklenmesindedir** (kendi batışının nedeni olarak).

**Sahte istatistik temizliği (kritikten):** "Deneyimsel öğrenme %70 vs ders %5" rakamı **tamamen çıkarıldı** — öğrenme piramidi/Dale's Cone bilimsel olarak çürütülmüştür, persona 30 saniyede Google'lar ve TÜM değer iddiasına güveni sarsılır. Yerine kanıt gerektirmeyen sezgisel doğru: *"Bir kararı kendin verip sonucunu yaşamak, birinin sana anlatmasından farklıdır — bunu herkes bilir."*

**YouTube savunması = iki özellik (monetizasyonun ÖN KOŞULU, cila değil):**
1. **#19 mechanic→ders köprüsü:** Değer "20 ders" değil, "**senin batışının nedeni olarak gösterilen ders.**" Köprü yoksa ürün gerçekten "bedava YouTube + güzel UI" olur. Kod hazır: `mechanic` alanı 20 derste etiketli (runway, ltv-cac, churn, equity, hiring, pricing yok...), sadece bağlanmıyor.
2. **A. post-mortem nedensellik zinciri:** Bu **zaten çalışıyor** (kritiğin tersine). Bu, YouTube'un asla yapamayacağı şey: senin oyununun verisinden senin hatanı teşhis etmek.

**Kanıt zinciri (her personayı tatmin eden) ve bugünkü durumu:**
mekanik (oynadın ✅VAR) → görünür sayı (gördün ⚠️runway/LTV VAR ama karar anında değil) → post-mortem nedensellik (anladın ✅VAR) → bağlamsal Defter dersi (adını koydun ❌#19 YOK) → ikinci oyunda farklı strateji (uyguladın ⚠️arketip tespiti YOK).

**En zayıf halka kritiğin dediği gibi 2 yer DEĞİL — tek yer: 4. halka (#19 köprüsü).** Çünkü 2. halka kısmen var (runway HUD'da, LTV GrowthPanel'de) ve 3. halka tam çalışıyor. Bu, ÖNCELİK 1'i daha ucuza tamamlanabilir kılar.

---

## 10. Uygulama Önceliği (kritikten: satışa-hazırlık eşiği netleştirildi)

> **SATIŞ EŞİĞİ (Kural-0 operasyonel hali):** Aşağıdaki ÖNCELİK 1 sevk edilmeden monetizasyon AÇILMAZ. Çünkü satılan şey ekonomi değil, ekonominin **kalıcı + bağlamsal görünür** halidir. İyi haber: ÖNCELİK 1 büyük ölçüde **mevcut içeriği bağlamak** — yeni içerik üretimi değil, düşük efor/yüksek getiri.

**ÖNCELİK 1 — Görünürlük & ders köprüsü (SATIŞ EŞİĞİ, içerik zaten VAR):**
- **#19 mechanic→ℹ→ders köprüsü:** HUD rozetlerine + karar kartına "ℹ"; tıklanınca `mechanic` etiketli LessonEntry açılır. *Tek başına "öğrendim" hissini ve YouTube farkını kurar.*
- **#26 kalıcı result kartı:** `choice.resultLine` toast yerine kararın hemen ardından **kalıcı bir kartta** gösterilsin (en zengin edu içerik 3.5sn'de uçmasın).
- **Karar anında metrik rozeti:** Runway + LTV:CAC, karar kartının üstünde anlık görünsün (veriler GameModel'de [VAR], sadece GrowthPanel dışına taşınacak).

**ÖNCELİK 2 — İlk oturum bağlanması (S efor):**
- HZ-3 ("Senin Tarzın" + felsefe damlası H) + HZ-4 (mentor ipucu); HZ-1/HZ-2 mikro-kutlamalar.

**ÖNCELİK 3 — Değer kanıtı + monetizasyon altyapısı:**
- **Sonuç Kartı (öğrenme-merkezli) + Refleks Kartı (9 soru)** WinView/SeasonFinale'ye (EventOverlays) bağlanır.
- **Beceri-dokunuş etiketleme** (Kurucu Karnesi'nin ön koşulu): her DecisionCard'a hangi beceriye dokunduğu etiketi → karne verisi toplanmaya başlar.
- StoreKit non-consumable IAP + persona-bazlı paywall; APPSTORE.md güncelle (₺149/$6.99, "IAP içerir").

**ÖNCELİK 4 — Ekonomi düzeltmeleri (paywall değerini korur):**
- **cashPercent fix (#2):** `pricing-change` once:true VEYA tavan `min(cash*0.25, mrr*3)`.
- **Fiyatlandırma Defter dersi ekle** (9 çekirdekten 1'i boşta — `mechanic: "pricing"`).
- Geç-oyun ileri-strateji kartları (#16, ücretli derinlik).
- Arketip tespiti (GameState alanı) — mezun "tek doğru yol yok" aha'sının ön koşulu.

**ÖNCELİK 5 — Lansman sonrası derinlik (L efor — pazarlanmadan önce sevk):**
- **pendingEffects gecikmeli motor (#6, B-6).** *Bu sevk edilene kadar "zincirleme sonucu yaşa" hiçbir pazarlamada KULLANILMAZ (Kural-0).* Bu motor, oyunu rakip idle'lardan mekanik olarak ayıran şey; bugün eksik olduğu için fark "daha iyi yazılmış toast" düzeyinde kalıyor — ama ÖNCELİK 1 (kalıcı kart + köprü) bu açığı kısmen kapatır.
- Bileşik moral eğrisi + state-dependent pivot + çok-kanallı CAC (transfer haritasının "FARKINDALIK→SİMÜLE" terfisi).

**Retention çerçevesi düzeltmesi (kritikten):** Eğitici araçta **günlük streak baskısı manipülatif hisseder** ve "ciddi araç" algısını bozar. Retention mekanikleri "geri gel" baskısından **"kaldığın yerden devam + yeni arketip dene"** çerçevesine kaydırılır. Streak öne çıkarılmaz.

**Tek cümlelik karar:** Önce **#19 ders köprüsü + #26 kalıcı kart + karar-anı metrik rozeti** — içerik zaten var (gerçek ekonomi, görünür runway/LTV, çalışan post-mortem motoru, 20 ders), sadece bağlanmıyor ve uçuyor. Bu üçü SATIŞ EŞİĞİ; sevk edilince oyun "gerçekten öğretti" iddiasını dürüstçe kurar ve üç personanın ödeme gerekçesini aynı anda güçlendirir.

**İlgili dosyalar (doğrulandı):** `Sources/Model/GameModel.swift` (runwayMonths s.396, ltv s.324, ltvCacRatio s.326, paybackMonths s.328, resultLine→pendingToast s.1161), `Sources/Content/LessonsContent.swift` (mechanic etiketleri s.64+ hazır, filtered() s.225 sadece category), `Sources/Content/DecisionContent.swift` (cashPercent s.291/321 fix; pricing dersi/etiket eksik), `Sources/UI/HUDView.swift` (runway s.171; LTV:CAC rozeti eklenecek), `Sources/UI/GrowthPanel.swift` (LTV/CAC/payback s.104-157 zaten görünür), `Sources/UI/DecisionCardView.swift` (kalıcı result kartı — #26), `Sources/UI/PostMortemView.swift` (6-kurallı nedensellik motoru s.200-280 ÇALIŞIYOR), `Sources/UI/OnboardingOverlay.swift` (HZ-3/4 + H), `Sources/UI/EventOverlays.swift` (Kurucu Karnesi/Sonuç/Refleks Kartı), `Sources/Model/GameState.swift` (arketip alanı + beceri-dokunuş verisi), `docs/PRODUCT_AUDIT.md` (#2/#6/#16/#19/#26), `docs/DESIGN_PRINCIPLES.md` (A-VAR/B/D/F/H).