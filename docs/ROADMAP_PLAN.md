All signatures verified. `DecisionResult(text:, speaker:, categoryRaw:, mechanic:)` confirmed — HZ-2 spec matches exactly. The new pricing LessonEntry slots correctly after `feature-vs-product` (line 141) in the Ürün block. The late-game DecisionCards match the `DecisionCard`/`DecisionChoice` init exactly.

I have enough verification. The content blocks conform to the actual struct signatures. Now I'll synthesize the roadmap.

---

# Unicorn — Kalan İşler: Tek Sıralı Uygulama Yol Haritası

> Doğrulama notu: Aşağıdaki tüm içerik blokları gerçek dosyalardan teyit edilen imzalara uyuyor — `LessonEntry(id/title/body/category:LessonCategory/mechanic)`, `DecisionCard(_ id, category:DecisionCategory, speaker:, icon:, prompt:, once:=false, trigger:=.always, choices:)`, `DecisionChoice(_ label, detail:nil, effects:[DecisionEffect], result:nil)`, `DecisionEffect.headcount(dept:Int, delta:Int)`, `DecisionResult(text:, speaker:, categoryRaw:, mechanic:)`. **Önemli düzeltme:** Spec'lerde geçen bazı dosya yolları yanlış — gerçekte `DecisionSystem.swift` ve `NotificationManager` `Sources/Systems/` altında olmalı, `Sources/Engine/` klasörü YOK. Aşağıda düzeltildi.

---

## 1. Özet

- **Toplam iş:** 16 (4 küme). Bunlardan **5 content** (yapıştırmaya hazır), **11 code** (diff-spec).
- **Kaba toplam effort:** ~3×S(content) + 2×S(code) + 5×M + 2×L ≈ **18-22 mühendislik-günü** (sole-builder, tek tek uygula+derle+doğrula).
- **Önerilen üst sıra:** ÖNCELİK 2 (ilk-oturum bağlanması) → 3 (değer kanıtı + IAP) → 4 (ekonomi derinliği) → 5 (cila). İçinde bağımlılıklar var (aşağıda).
- **En kritik 3 bağımlılık zinciri:**
  1. `mechanicTouchCounts` sayacı (B1) → Kurucu Karnesi (B2) + Refleks Kartı (B4)
  2. `FounderArchetype` enum + GameState alanı (A1) → CompanySetup arketip adımı (A2)
  3. salesPower/LTV tavanı (C4) → arketip tespiti `niche` eşiği kalibrasyonu (C3)

> İsim çakışması uyarısı: A kümesi (`FounderArchetype` = onboarding eğilimi, Int rawValue, GameState'te `founderArchetype`) ile C kümesi (`FounderArchetype` = runtime tespit, String rawValue, GameState'te `detectedArchetype`) **AYNI enum adını** kullanıyor ama farklı şeyler. **Bunlar derlenmez — çakışır.** Karar gerekiyor (Riskler bölümü). Önerim: A'yı `FounderLeaning` olarak yeniden adlandır, C'yi `FounderArchetype` bırak.

---

## 2. Uygulama Sırası (sole-builder, sıralı)

Her adımı uygula → `xcodegen` + `xcodebuild` ile derle → simülatörde doğrula → sonra bir sonrakine geç.

**Faz 1 — ÖNCELİK 2 (ilk oturum):**
1. **A1** FounderLeaning enum + GameState alanı *(önce isim kararını ver)*
2. **A2** CompanySetup arketip adımı *(A1'e bağlı)*
3. **A3** HZ-4 ilk oturum karşılaması *(bağımsız; pendingToast yolu)*
4. **A4** HZ-1 ilk karar tebriği *(bağımsız)*
5. **A5** HZ-2 kullanıcı milestone kutlaması *(bağımsız; pendingToast yoluyla başla)*

**Faz 2 — ÖNCELİK 3 (değer kanıtı + teslimat):**
6. **B1** mechanicTouchCounts sayacı *(B2+B4 ön koşulu)*
7. **B3** Strateji Kimliği metinleri *(content; B2'den önce hazırla)*
8. **B5-content** Refleks Kartı 9-soru sabiti *(content)*
9. **B2** Kurucu Karnesi view *(B1+B3+B5-content'e bağlı)*
10. **B6** StoreKit 2 IAP + paywall *(L; bağımsız ama en riskli — IAP fiyat kararı gerek)*

**Faz 3 — ÖNCELİK 4 (ekonomi):**
11. **C1** Fiyatlandırma dersi *(content; bağımsız)*
12. **C2** 7 geç-oyun DecisionCard *(content; bağımsız)*
13. **C4** salesPower/LTV tavanı *(C3 niche eşiği ön koşulu — önce bunu yap)*
14. **C3** Arketip tespiti *(C4'e bağlı; A1 isim kararı netleşmiş olmalı)*

**Faz 4 — ÖNCELİK 5 (cila):**
15. **D1** pendingEffects gecikmeli etki motoru *(L; bağımsız)*
16. **D2** Yerel bildirimler *(M; bağımsız)*
17. **D3** Dynamic Type *(M; bağımsız)*
18. **D4** Ölü kod temizliği *(M; bağımsız — en son, regresyon yüzeyini küçük tut)*

---

## 3. İş Listesi

### ÖNCELİK 2 — İlk Oturum Bağlanması

| # | Başlık | Type | Effort | Dosyalar | Hazır? | Özet | Doğrulama |
|---|--------|------|--------|----------|--------|------|-----------|
| A1 | FounderLeaning enum + GameState alanı | code | S | `Company.swift`, `GameState.swift` | spec | Onboarding "eğilim" damlası için kalıcı alan (mekanik etki yok, Kural-0). **Enum adını `FounderLeaning` yap** (C3 ile çakışmasın). | Derle. Yeni oyun → save JSON'da `founderArchetype`/`founderLeaning` anahtarı. Eski save → .balanced ile çökmeden açılır. |
| A2 | CompanySetup arketip adımı + felsefe damlası | code | M | `CompanySetupOverlay.swift`, `GameModel.swift` | spec | 3→4 adım. `completeCompanySetup`'a `archetype:` parametresi. **KRİTİK: `canAdvance`'e `case 3: return true` eklenmezse "Şirketi Kur" disable kalır.** | 4 capsule göstergesi; adım 3'te 3 kart + değişen felsefe metni; "Şirketi Kur" aktif; save'de seçim yazılı. |
| A3 | HZ-4 ilk oturum karşılaması | code | S | `NarrativeContent.swift`, `GameModel.swift` | spec + içerik hazır | Kuruluş biter bitmez `pendingToast = firstSessionWelcome` (mevcut tek-atışlık altyapı). | Yeni oyun → "Şirketi Kur" sonrası karşılama toast'ı. Eski oyun → çıkmaz. |
| A4 | HZ-1 ilk karar tebriği | code | S | `GameModel.swift` | spec + içerik hazır | `resolve()` içinde `totalDecisions==0` yakala, `pendingToast` ile suçlamasız tebrik + Defter köprü metni. **Kural-0: "ders kilidi açıldı" deme — kilit yok.** | İlk karar → sonuç kartı + tebrik toast; ikinci kararda toast yok. |
| A5 | HZ-2 100/1000 kullanıcı kutlaması | code | M | `GameModel.swift`, `GameState.swift` | spec + içerik hazır | `celebratedUserMilestones:[Int]` kalıcı flag + tick'te `maybeCelebrateUserMilestone()`. **pendingToast yoluyla başla** (overlay yarışı yok); köprü zenginliği gerekirse sonra pendingResult'a yükselt. | 100 ve 1000'i ilk geçişte birer kutlama; kapat-aç → tekrar kutlanmaz; save'de `[100,1000]`. |

### ÖNCELİK 3 — Değer Kanıtı & Nihai Teslimat

| # | Başlık | Type | Effort | Dosyalar | Hazır? | Özet | Doğrulama |
|---|--------|------|--------|----------|--------|------|-----------|
| B1 | mechanicTouchCounts sayacı | code | S | `GameState.swift`, `GameModel.swift` | spec | `[String:Int]` frekans (additive Codable). `resolve()`'da `card.category.lessonMechanic` ile artır. `topTouchedMechanics` computed (top 3). **mentor-tip kartını hariç tut.** | 3-4 farklı kategori kararı → save'de sayaçlar artmış; eski save fresh-start olmadan açılır; topTouchedMechanics 3 anahtar. |
| B3 | Strateji Kimliği metinleri | content | S | `FounderScorecardView.swift` | **içerik HAZIR** | 5 kimlik (Bağımsız/Hızlı Ölçekleyen/Organik/İnsan-Önce/Dengeli) türetme kuralı + blurb + paylaşım kopyası. | Her dalı tetikleyen seed save; paylaşım metninde skor/iflas GÖRÜNMEZ. |
| B5c | Refleks Kartı 9-soru sabiti | content | S | `LessonsContent.swift`, `FounderScorecardView.swift` | **içerik HAZIR** | `FounderReflexCard.questions` statik dizi; topTouchedMechanics'tekiler vurgulu. | 9 soru sırayla; en çok dokunulan 2'si accent+rozet. |
| B2 | Kurucu Karnesi view (WinView+SeasonFinale) | code | M | `FounderScorecardView.swift`(yeni), `EventOverlays.swift`, `SeasonFinaleView.swift` | spec | "En Pahalı 3 Ders" (B1'den) + Strateji Kimliği + Refleks Kartı. **WinView'i ScrollView'a sar** (taşma). inspectedMechanic köprüsü. | Win/Finale seed → karne görünür; derse dokun → LessonPopup; boş save'de "Henüz yeterli karar" fallback. |
| B6 | StoreKit 2 IAP + Series A paywall | code | L | `StoreManager.swift`(yeni), `PaywallView.swift`(yeni), `GameModel.swift`, `ContentView.swift`, `APPSTORE.md` | spec | Tek non-consumable `fullversion`; Stage 2→3 doğal kesme. **Gating'i ContentView overlay seviyesinde yap** (GameModel StoreKit'ten bağımsız kalır). Entitlement Apple'da (GameState'e koyma). | .storekit config ile sandbox; Stage 3 funding → paywall; satın al → devam; sil-kur → restore. |

### ÖNCELİK 4 — Ekonomi & İçerik Derinliği

| # | Başlık | Type | Effort | Dosyalar | Hazır? | Özet | Doğrulama |
|---|--------|------|--------|----------|--------|------|-----------|
| C1 | Fiyatlandırma dersi | content | S | `LessonsContent.swift` | **içerik HAZIR** | `mechanic:"pricing"`, `category:.product`. `feature-vs-product`'tan (sat.141) sonra. lessonMechanic mapping'e DOKUNMA. | Defter "Ürün" chip'inde yeni kart; `lesson(for:"pricing")` nil değil. |
| C2 | 7 geç-oyun DecisionCard (#16) | content | M | `DecisionContent.swift` | **içerik HAZIR** | IPO/secondary/antitrust/M&A/CEO-transition/mega-offer/dual-class, minStage 4-5. `price-bump-30`'dan (sat.839) sonra. Denge: pozitif cashPercent yok. | minStage 4+ seed → kartlar akışta; build temiz; placeholder çökmez. |
| C4 | salesPower/LTV tavanı (#17) | code | M | `GameModel.swift`, `BalanceSim/main.swift`, `Balance.swift` | spec | `salesArpuPerUnit=0.04`, `salesArpuCap=0.80`, `ltvMonthsCap=40`. **GameModel + BalanceSim AYNI anda** değişmeli. C3'ten ÖNCE. | BalanceSim LTV:CAC 14-73 → ~3-9; erken oyun ARPU/runway değişmez. |
| C3 | Arketip tespiti (runtime) | code | M | `GameState.swift`, `GameModel.swift` | spec | `FounderArchetype` (String) enum + `detectedArchetype` + `currentArchetype` computed. C4'le birlikte kalibre. **A1 isim kararına bağlı.** | 4 persona BalanceSim koşusu beklenen arketip; agresif vs reklamsız oyun farklı sonuç. |

### ÖNCELİK 5 — Derinlik & Cila

| # | Başlık | Type | Effort | Dosyalar | Hazır? | Özet | Doğrulama |
|---|--------|------|--------|----------|--------|------|-----------|
| D1 | pendingEffects gecikmeli etki motoru (#6) | code | L | `GameState.swift`, `GameModel.swift`, `DecisionSystem.swift`, `DecisionContent.swift` | spec + 3 pilot kart HAZIR | `DelayedEffect`/`PendingEffect` Codable kardeş enum (DecisionEffect'e DOKUNMA). Zaman-damgalı kuyruk, tick'te vade. | Gecikmeli seçim → ~3 ay sonra toast+HUD; kill+relaunch kuyruk geri yüklenir; eski save çökmez. |
| D2 | Yerel bildirimler (#5) | code | M | `Systems/NotificationManager.swift`(yeni — **Engine değil**), `GameModel.swift`, `ContentView.swift`, `OnboardingOverlay.swift` | spec + içerik HAZIR | Baskısız streak-risk + D1 dönüş; foreground'da iptal. Plist anahtarı gerekmez. | Onboarding → izin; arka plan → planlanır; foreground → iptal; reddedilince planlanmaz. |
| D3 | Dynamic Type (#13) | code | M | `Typography.swift` (+ ContentView 1 satır) | spec | `appNumber/appText`'e `relativeTo:` + named ölçek text-style bağı + `accessibility1` tavan. | Larger Text → ölçeklenir, layout kırılmaz; default'ta regresyon yok. |
| D4 | Ölü kod temizliği (#21) | code | M | `FloatingNav.swift`, `ContentView.swift`, `FloorPlanView.swift`, `SprintView.swift`, `GameModel.swift`, `TeamPanel.swift` | spec | SideRail SİL; EmployeeCardView CANLANDIR (TeamPanel tap); SprintCloseView+startNextSprint SİL; occupant koltuk sistemi SİL. **Her silmeden önce grep doğrula.** | Build temiz; ekip kartı tap → EmployeeCardView; sprint sadece toast; dead-code uyarısı azalır. |

---

## 4. İçerik Bohçası (yapıştırmaya hazır)

> Hepsi gerçek imzalara göre teyit edildi. `category:` değerleri: LessonEntry için `LessonCategory` (.product vb.), DecisionCard için `DecisionCategory` (.investor vb.) — karıştırma.

### B3 — Strateji Kimliği (FounderScorecardView `identity` computed içeriği)

```
// Türetme: yukarıdan aşağı ilk tutan dal. Hepsi GameState'ten okunur (yeni mekanik yok).
// 1) founderEquity >= 0.55 && bankruptcies == 0
title:  "Bağımsız Kurucu"
blurb:  "Hisseni korudun, kendi paranla büyüdün. Yavaş ama senin olan bir yol — bağımsızlık bir strateji, bir eksiklik değil."
// 2) stageReached >= 3 && founderEquity < 0.45
title:  "Hızlı Ölçekleyen"
blurb:  "Yakıt için hisse verdin, gaza bastın. Dilution'ı büyümeye çevirmeyi seçtin — risk senin imzandı."
// 3) reputation >= 60 && adBudgetPerMonth <= 0
title:  "Organik Büyütücü"
blurb:  "Reklam yerine itibarla büyüdün. En ucuz CAC ağızdan ağıza geçendir — sabrın senin kanalın oldu."
// 4) morale >= 65
title:  "İnsan-Önce Kurucu"
blurb:  "Ekibin moralini öncelik yaptın. Moral bileşik getiridir; sen faizini topladın."
// 5) varsayılan
title:  "Dengeli Kurucu"
blurb:  "Tek bir uca savrulmadın — nakit, ekip ve büyüme arasında ip cambazlığı yaptın. Denge de bir karardır."

// Strateji Kimliği başlığının altında (sabit):
"Bu senin bu oyundaki eğilimin — sonraki denemende bambaşka bir kurucu olabilirsin."

// Gizlilik notu (paylaş butonunun üstünde):
"Bu karne yalnızca sende kalır. İstersen içgörünü paylaş — sayıların değil, öğrendiğin paylaşılır."

// ShareLink düz metni (skor/iflas PAYLAŞILMAZ):
"Unicorn'da bu oyunda öğrendiğim en pahalı 3 ders: 1) {ders1} 2) {ders2} 3) {ders3}. Strateji kimliğim: {kimlik}. — Garajdan Zirveye"
```

### B5c — Refleks Kartı 9 Soru (LessonsContent.swift'e yeni sabit)

```swift
/// Refleks Kartı (#8.2): 9 çekirdek beceriden türetilmiş öz-sorgu listesi.
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
```

### A3 — HZ-4 Karşılama (NarrativeContent.swift)

```swift
/// İlk oturum karşılaması (HZ-4) — kuruluş biter bitmez gösterilir.
static let firstSessionWelcome =
    "İlk işin para kazanmak değil — birinin senin ürününü gerçekten istediğini bulmak. Geri kalan her şey bunun üstüne kurulur."
```

### A4 — HZ-1 İlk Karar Tebriği (toast metni, GameModel.resolve içine)

```
"İlk kararını verdin — tek doğru cevap yoktu, sen kendi bahsini koydun. Kararlarının dersleri artık Defter'de birikiyor."
```

### A5 — HZ-2 Milestone Metinleri (GameModel.maybeCelebrateUserMilestone)

```
100:  "İlk 100 kullanıcı! Bunlar en değerli kullanıcıların — her birini tanı, elle onboard et. Ölçeklenmeyen işler şimdi en kıymetli içgörüyü verir."
1000: "1.000 kullanıcı! Artık motor dönüyor. Şimdi soru değişiyor: kaç tanesi geri geliyor? Churn sessizce büyümeni yiyebilir."
```

### C1 — Fiyatlandırma Dersi (LessonsContent.all'a, `feature-vs-product`'tan sonra, sat.141)

```swift
        LessonEntry(
            id: "pricing-captures-value",
            title: "Fiyat, Yarattığın Değeri Yakalamaktır",
            body: "Fiyatlandırma maliyetin üstüne kâr koymak değil; kullanıcıya kattığın değerin bir kısmını geri almaktır. Çoğu kurucu çok düşük fiyatlar — \"ucuz olursak çok satarız\" sezgisi yanıltıcıdır: düşük fiyat hem geliri hem de algılanan değeri birlikte düşürür. Patrick Campbell'ın verisi nettir: startup'ların ezici çoğunluğu fiyatlandırmaya ürününe harcadığının çok altında zaman ayırır. Önce \"kim için, hangi değer\" sorusunu netleştir; fiyat o cevabın etiketidir.",
            category: .product,
            mechanic: "pricing"
        ),
```

### C2 — 7 Geç-Oyun DecisionCard (DecisionContent.all sonuna, `price-bump-30`'dan sonra)

```swift
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
```

### D1 — pendingEffects pilot kartları (DecisionContent.swift; `delayed:` parametresi D1 code işiyle eklenir)

> Bu kartlar yalnızca D1'in `DecisionChoice`'a `delayed:` alanı eklemesinden SONRA derlenir. C2'den ayrı tut.

```swift
        DecisionCard("delayed-fasthire", category: .team, speaker: "Operasyon", icon: "⚡️",
            prompt: "{{company}} hızlı büyüyor. Bu ay 3 kişiyi hızlıca, eleme yapmadan işe alabilirsin — boşlukları hemen kapatır.",
            trigger: .minStage(1),
            choices: [
                .init("Hızlı al, sonra düşün", detail: "+anlık hız / 2 ay sonra uyum sancısı",
                      effects: [.morale(3), .usersPercent(0.02)],
                      delayed: [DelayedEffect(delayMonths: 2,
                          effects: [.morale(-6), .moraleTargetBonus(-1)],
                          note: "Hatırlıyor musun — 2 ay önce eleme yapmadan hızlı işe almıştın. Uyum sorunları morali yordu. (Hızlı işe alım, yavaş pişmanlık.)")],
                      result: "Boşluklar doldu. (Yanlış işe alımın faturası genelde aylar sonra gelir.)"),
                .init("Yavaş ve seçici al", detail: "−anlık hız / +kalıcı uyum",
                      effects: [.moraleTargetBonus(1), .reputation(2), .usersPercent(-0.01)],
                      result: "Daha yavaş ama daha sağlam ekip. (İşe almada acele, çıkarmada pişmanlık.)")
            ]),

        DecisionCard("delayed-techdebt", category: .product, speaker: "CTO", icon: "🧱",
            prompt: "Teslim tarihine yetişmek için kısa yoldan, test yazmadan gönderebiliriz. Şimdi hızlı; ama kod borcu birikir.",
            trigger: .minUsers(500),
            choices: [
                .init("Kısa yoldan gönder", detail: "+anlık büyüme / 3 ay sonra kırılganlık",
                      effects: [.usersPercent(0.05)],
                      delayed: [DelayedEffect(delayMonths: 3,
                          effects: [.reputation(-5), .usersPercent(-0.04)],
                          note: "3 ay önce test yazmadan gönderdiğin sürüm patladı — bazı kullanıcılar küstü. (Teknik borç faizini hep öder.)")],
                      result: "Zamanında çıktı. (Borç bedava değil; faizi sonra kesilir.)"),
                .init("Sağlam yap, geç çık", detail: "−anlık hız / +dayanıklılık",
                      effects: [.reputation(3), .moraleTargetBonus(1)],
                      result: "Yavaş ama sağlam. (Erken hız her zaman erken kazanç değildir.)")
            ]),

        DecisionCard("delayed-discount", category: .market, speaker: "Satış", icon: "🏷️",
            prompt: "Büyük indirimle bu ay kullanıcı sayısını şişirebiliriz. Rakamlar parlar — ama gelen kullanıcı fiyat-hassas olur.",
            trigger: .minStage(2),
            choices: [
                .init("Agresif indirim ver", detail: "+anlık kullanıcı / 2 ay sonra churn dalgası",
                      effects: [.usersPercent(0.08)],
                      delayed: [DelayedEffect(delayMonths: 2,
                          effects: [.usersPercent(-0.06), .reputation(-2)],
                          note: "İndirimle gelen kullanıcılar 2 ay sonra ayrıldı — fiyat artınca kaldılar mı? Hayır. (İndirim sadakat satın almaz.)")],
                      result: "Sayılar fırladı. (Yanlış kullanıcıyı çekmek, hiç çekmemekten pahalı olabilir.)"),
                .init("Tam fiyat, doğru müşteri", detail: "−anlık sayı / +kaliteli taban",
                      effects: [.reputation(3), .moraleTargetBonus(1)],
                      result: "Daha az ama doğru müşteri. (Vanity metrik değil, kalıcı gelir.)")
            ]),
```

### A1 — FounderLeaning enum (Company.swift sonuna; **`FounderArchetype` değil — C3 ile çakışmasın**)

```swift
/// Oyuncunun kuruluşta seçtiği kurucu eğilimi (HZ-3). Mekanik etki YOK —
/// yalnızca onboarding felsefe çerçevesi. Kural-0: ekonomiye bağlanmadığı için
/// pazarlamada "arketip mekaniği" vaadi verilmez. (Runtime tespit için ayrı enum
/// FounderArchetype kullanılır — bunu onunla karıştırma.)
enum FounderLeaning: Int, Codable, CaseIterable {
    case cautious = 0
    case balanced = 1
    case bold = 2

    var title: String {
        switch self {
        case .cautious: return "Temkinli"
        case .balanced: return "Dengeli"
        case .bold:     return "Cesur"
        }
    }
    var icon: String {
        switch self {
        case .cautious: return "shield.lefthalf.filled"
        case .balanced: return "scalemass.fill"
        case .bold:     return "flame.fill"
        }
    }
    var blurb: String {
        switch self {
        case .cautious: return "Önce hayatta kal. Runway'i korur, bağımsızlığı seçer, yavaş ama sağlam büyürsün."
        case .balanced: return "Fırsatı ve riski tartarsın. Bağlama göre bazen frene, bazen gaza basarsın."
        case .bold:     return "Büyümeye oynarsın. Riski kucaklar, hızlı hamle yapar, sınırları zorlarsın."
        }
    }
    var philosophyDrop: String {
        switch self {
        case .cautious: return "Temkinli kurucular da Unicorn olur — sadece patikaları farklıdır. Hatırla: tek doğru yol yoktur, sadece senin yolun vardır."
        case .balanced: return "Dengeli olmak kararsızlık değil, bağlamı okumaktır. İki seçenek de duruma göre doğru olabilir."
        case .bold:     return "Cesaret iyidir ama runway'i unutturmaz. En hızlı kurucular bile sayacı okur. Tek doğru yol yoktur — riskini bilinçli al."
        }
    }
}
```

> Not: A1/A2/A3 spec'lerindeki `founderArchetype` alan adı ve `archetype:` parametre adı, isim değişikliği yapılırsa `founderLeaning` / `leaning:` olarak güncellenir. PaywallView kopyası "4 farklı strateji" derken bu FounderLeaning'in 3 seçimine değil, DESIGN_PRINCIPLES'taki 4 gerçek arketibe atıf yapar — Kural-0 açısından sorun yok çünkü C3 runtime arketip tespiti 4'ü kapsıyor.

---

## 5. Riskler & Açık Kararlar (sahibi karar vermeli)

1. **[BLOKER] Enum isim çakışması — `FounderArchetype`.** A kümesi (onboarding eğilim, Int) ve C kümesi (runtime tespit, String) aynı adı kullanıyor; ikisini birlikte uygularsan **derlenmez**. Karar: A1'i `FounderLeaning` yap (yukarıda öyle hazırlandı), C3 `FounderArchetype` kalsın. Onaylaman gerek.

2. **IAP fiyat kesinleşmesi (B6).** Spec ₺149 (lansman ₺99) / $6.99 (lansman $4.99) öneriyor. App Store Connect'te non-consumable "lansman fiyatı" promosyon değil ayrı tier — yani kalıcı fiyatı tek seçip sonra elle artırman gerekir. %40 öğrenci Offer Code ayrı kurulum. **Karar: kalıcı fiyat tier'ı + lansman stratejisi (elle artırım mı, hep ₺99 mu).** Ayrıca ürün id `co.omerfarukdemiral.unicorn.fullversion` — bundle id ile tutarlı mı doğrula.

3. **Paywall "Daha sonra" davranışı (B6).** Spec: Stage 2'de oynamaya devam, Stage 3 funding bloke. Bu yumuşak duvar mı yoksa Stage 3 tamamen kilitli mi olmalı? Retention vs. dönüşüm dengesi senin kararın. Kural-0: paywall kopyasında yalnızca BUGÜN sevk edilmiş içerik vaat edilmeli (pendingEffects/D1 sevk edilene dek "gecikmeli sonuçlar" yazılamaz).

4. **HZ-2 milestone: pendingToast vs pendingResult (A5).** pendingToast güvenli (overlay yarışı yok) ama Defter köprüsü taşımaz; pendingResult zengin köprü taşır ama overlay kuyruğu riski. **Öneri: pendingToast ile sevk et, köprü zenginliği istenirse sonra yükselt.** Senin tercihin.

5. **Kurucu Karnesi paylaşımı varsayılan ÖZEL (B2/B3).** Otomatik paylaşım yok, skor/iflas paylaşılmaz — yalnızca içgörü. Bu ürün felsefesi kararı; onaylıyor musun yoksa sosyal-yayılım için skor da eklenmesini ister misin (Kural-0 ve "statü değil içgörü" ilkesiyle çelişir, önermem).

6. **LTV tavanı kalibrasyon değerleri (C4).** `ltvMonthsCap=40`, `salesArpuCap=0.80` ilk tahmin. BalanceSim hâlâ 10+ gösterirse cap'leri (30 / 0.6) düşür. **GameModel + BalanceSim AYNI commit'te değişmeli** yoksa sim yalan söyler. C3 niche eşiği (`arpu ≥ baseArpu*1.6`) bu tavandan sonra hâlâ tetiklenebilir olmalı — birlikte test et.

7. **Dosya yolu düzeltmeleri.** Spec'lerde `Sources/Engine/NotificationManager.swift` ve `Sources/Engine/DecisionSystem.swift` geçiyor; **gerçekte `Sources/Systems/`** (Engine klasörü yok). NotificationManager'ı `Sources/Systems/` altına koy. project.yml glob'u Systems'i kapsıyorsa xcodegen otomatik alır.

8. **D4 ölü kod: silmeden önce grep şart.** Spec "EmployeeCardView CANLANDIR" diyor (sil değil) — TeamPanel'in gerçek döngü değişkeni/`dept.id` alanı dosyadan teyit edilmeli. `sideMenuTrailing`, `MemberAssignPopover`, `SprintCelebrationRing`, `startNextSprint` için ayrı ayrı grep yapıp dış okuyucu yoksa sil; varsa bırak. Bu işi en sona koy (regresyon yüzeyini izole et).