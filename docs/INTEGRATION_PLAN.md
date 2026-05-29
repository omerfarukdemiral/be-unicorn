Key findings for the plan:
- C2 (ipo, dual-class) and C1 (pricing-captures-value) and D1 cards: the **already-done** Parti work has C1 + the 7 C2 cards. The D1 spec's DecisionContent edit adds delayed cards. The C2 cards are ALREADY present (851, 911) — so the D1 spec's anchor `price-bump-30` (839) is still valid, and the delayed cards will land between price-bump-30 and ipo-vs-stay-private. This means the D1 DecisionContent edit is additive and the anchor is unique.
- Series A is stage `id: 3`, valuationTarget 15M, raiseAmount 4M (B6 spec's "15M target" confirmed; spec said raiseAmount but uses next.raiseAmount which is correct).
- `schemes.Unicorn.run` has no `storeKitConfiguration` — B6 ascAction note is correct (manual or optional yml add).

I have verified everything. Producing the integration plan.

---

# Unicorn — 8 Özellik Tek Sıralı Entegrasyon Planı (sole-builder)

> Tüm anchor'lar gerçek dosyalara karşı doğrulandı (satır no'larıyla). Yeni dosyaların hepsi diskte mevcut: `Systems/FounderArchetype.swift`, `Systems/FounderScorecardData.swift`, `Systems/PendingEffects.swift`, `Systems/NotificationManager.swift`, `Systems/StoreManager.swift`, `UI/FounderScorecardView.swift`, `UI/PaywallView.swift`, `Unicorn.storekit`. `project.yml` `path: Sources` glob'u hepsini otomatik alır — yml'e dosya ekleme GEREKMEZ.

## 0. Genel Kural
Her özelliği uygula → `cd /Users/omerfaruk/Desktop/Dev/games/Unicorn && xcodegen && xcodebuild -scheme Unicorn -destination 'platform=iOS Simulator,name=iPhone 16' build` → simülatörde doğrula → sonraki özelliğe geç. **Tek istisna: B1+B2 (+FounderScorecardData/View) aynı build'de derlenmeli** (B2 view, B1'in sağladığı sembollere bağlı; tek başına derlenmez).

---

## 1. Entegrasyon Sırası (bağımlılık grafiğine göre)

### ADIM 1 — A (FounderLeaning + CompanySetup 4-adım + C3 runtime arketip) [order 1]
**Neden ilk:** İsim katmanı (`FounderLeaning` vs `FounderArchetype`) tüm sonraki referansların temeli; C3 arketip tespiti C4 ekonomi tavanlarına (`Balance.salesArpuCap`, `salesArpuPerUnit`) bağlı — bu sabitler kodda mevcut varsayıyoruz (Parti3'te eklendi, spec'te belirtilmiş).

**Zaten yazılı yeni dosya:** `Sources/Systems/FounderArchetype.swift` (String enum: unknown/bootstrap/vc-rocket/niche/platform).

**GameState alanları + decode:**
| Alan | Bildirim (anchor: `var hasSeenOnboarding: Bool = false` @127, insertAfter) | Decode (anchor: `hasSeenOnboarding = g(.hasSeenOnboarding, false)` @217, insertAfter) |
|---|---|---|
| founderLeaning | `var founderLeaning: Int = FounderLeaning.balanced.rawValue` | `founderLeaning = g(.founderLeaning, FounderLeaning.balanced.rawValue)` |
| detectedArchetype | `var detectedArchetype: String = FounderArchetype.unknown.rawValue` | `detectedArchetype = g(.detectedArchetype, FounderArchetype.unknown.rawValue)` |

**Wiring editleri (sırayla, hepsi anchor doğrulandı):**
1. `Company.swift` @29 (`var isLive: Bool = false ... }`) insertAfter → `FounderLeaning` enum.
2. `GameState.swift` @127 / @217 → yukarıdaki 2 alan + 2 decode satırı.
3. `CompanySetupOverlay.swift`:
   - @16-17 insertAfter → `@State private var leaning = FounderLeaning.balanced`
   - @25 (`case 2: return !projectName...`) replace → `case 3: return true` ekle (**KRİTİK** — yoksa "Şirketi Kur" disable).
   - @69 (`ForEach(0..<3`) replace → `0..<4`
   - @42 (`case 0: founderStep`) replace switch → `case 2: projectStep / default: leaningStep`
   - @92 stepIcon, @99 stepTitle, @106 stepSubtitle replace → 4-adım varyantları
   - @174 (`// MARK: Footer`) insertAfter → `leaningStep` view'i
   - @191 (`if step < 2`) replace → `step < 3`
   - @195-196 (`step < 2 ? "Devam"`) replace → `step < 3`
   - @209 (`model.completeCompanySetup(...)`) replace → `leaning: leaning` parametresi ekle
4. `GameModel.swift`:
   - @1422 (`func completeCompanySetup`) replace imza → `leaning: FounderLeaning = .balanced` ekle
   - @1430 (`state.profile.setupComplete = true`) insertAfter → `state.founderLeaning = leaning.rawValue`
   - @1417 (`var founderTitle...`) insertAfter → `founderLeaning` accessor + `currentArchetype` computed + `maybeDetectArchetype()`
   - @1318 (`maybeCelebrateUserMilestone()    // HZ-2`) insertAfter → `maybeDetectArchetype()`

**Doğrulama:** Yeni oyun → 4 capsule, adım 3'te 3 kart + değişen felsefe metni, "Şirketi Kur" AKTİF. Save JSON'da `founderLeaning` (0/1/2) + `detectedArchetype="unknown"`. Eski save → çökmeden açılır. BalanceSim seed: equity<0.45+stage≥3 → vcRocket; ad=0+equity≥0.55 → bootstrap; users≥20000 → platform; erken oyun → unknown.

---

### ADIM 2 — D3 (Dynamic Type) [order 3]
**Neden burada:** Tamamen izole (Typography + 1 ContentView satırı), erken yapılırsa sonraki UI özellikleri otomatik ölçeklenir. Default boyutta sıfır regresyon.

**Yeni dosya:** yok. **GameState alanı:** yok.

**Wiring (anchor'lar @21/@25/@33/@42 doğrulandı):**
1. `Typography.swift` @21-25 replace → `appNumber`/`appText`'e `relativeTo style: Font.TextStyle = .body` parametresi.
2. `Typography.swift` @33 (sayı ölçekleri bloğu) replace → her named scale'e `relativeTo:` text-style.
3. `Typography.swift` @42 (metin ölçekleri bloğu) replace → her named scale'e `relativeTo:`.
4. `ContentView.swift` @153-154 (`.onAppear {\n            let args = ProcessInfo...`) replace → önüne `.dynamicTypeSize(...DynamicTypeSize.accessibility1)` ekle.
   - **NOT:** `let args = ProcessInfo` ContentView'de İKİ yerde geçer (@31 tab init, @155 onAppear). Anchor'ı 2-satırlık `.onAppear {\n            let args...` formuyla ver — @153-154'e benzersiz eşleşir, @31'e değil.

**Doğrulama:** Default boyutta HUD/kart birebir aynı. Larger Text → ölçeklenir. AX5 → accessibility1'de durur, taşma yok.

---

### ADIM 3 — B1 (mechanicTouchCounts veri katmanı) [order 6]
**Zaten yazılı yeni dosya:** `Sources/Systems/FounderScorecardData.swift` (FounderReflexCard + FounderIdentity + FounderScorecardData).

**GameState alanı + decode:**
- Bildirim (anchor `var totalDecisions: Int = 0` @57, insertAfter): `var mechanicTouchCounts: [String: Int] = [:]`
- Decode (anchor `totalDecisions = g(.totalDecisions, 0)` @174, insertAfter): `mechanicTouchCounts = g(.mechanicTouchCounts, [String: Int]())`

**Wiring (anchor'lar doğrulandı):**
1. `GameState.swift` @57 / @174 → alan + decode.
2. `GameModel.swift` @1161 (`state.totalDecisions += 1`) insertAfter → mentor-tip hariç `mechanicTouchCounts[m] += 1` (kullanır: `card.category.lessonMechanic` — `LessonsContent.swift:250` `var lessonMechanic` mevcut, doğrulandı).
3. `GameModel.swift` @22 (`@Published var inspectedMechanic...`) insertAfter → `topTouchedMechanics` computed.

**Doğrulama:** 4 farklı kategoride karar → save'de sayaçlar artmış. Mentor-tip kararı sayaç artırmaz. Eski save fresh-start olmadan açılır.

---

### ADIM 4 — B2 (Kurucu Karnesi VIEW + Win/Finale geçişi) [order 10]
**Zaten yazılı yeni dosya:** `Sources/UI/FounderScorecardView.swift`. **B1 ile AYNI build'de derle** (model.topTouchedMechanics, FounderScorecardData.identity, FounderReflexCard sembollerine bağlı).

**GameState alanı:** yok.

**Wiring:**
1. `EventOverlays.swift` @134-135 (`private var league... seasonTitle`) insertAfter → `@State private var showScorecard = false`
2. `EventOverlays.swift` @144 (`if appeared { ConfettiBurst()... }` + `VStack` + `// Zafer ikonu`) replace → `ScrollView { VStack...` (WinView'i ScrollView'a sar).
3. `EventOverlays.swift` — **dismiss buton bloğu replace** (büyük blok, anchor `Button { Haptics.tap(); model.dismissWin() }` → `}` zincir sonu). Bu edit: (a) "Kurucu Karnesini Gör" butonu ekler, (b) ScrollView'ı kapatır (ekstra `}`), (c) ZStack içinde `showScorecard` ise FounderScorecardView sunar.
   - **DİKKAT:** Spec'teki "PLACEHOLDER insertAfter" edit'i **UYGULAMA** (label gövdesini böler). Yalnızca büyük replace edit'ini uygula.
4. `SeasonFinaleView.swift` @10-11 (`let finale: SeasonFinale` + `@State private var appeared`) replace → `showScorecard` ekle.
5. `SeasonFinaleView.swift` @34 ("Yeni Sezon" buton bloğu) replace → ardına "Kurucu Karnesini Gör" butonu.
6. `SeasonFinaleView.swift` @52 (`.onAppear { Haptics.success()...` + `// MARK: Hero`) replace → önüne `.overlay { if showScorecard { FounderScorecardView... } }`.

**Doğrulama:** Win seed → "Kurucu Karnesini Gör" → karne; ders satırına dokun → LessonPopupView (model.inspectedMechanic köprüsü, ContentView en-üst LessonPopup zaten var); kapat → Win'e döner. Az kararlı save → "Henüz yeterli karar" fallback. Finale seed → aynı. ShareLink metninde skor/iflas YOK. iPhone SE → ScrollView taşma yok.

---

### ADIM 5 — D1 (pendingEffects gecikmeli etki motoru) [order 15]
**Zaten yazılı yeni dosya:** `Sources/Systems/PendingEffects.swift` (DelayedEffect + PendingEffect + CodableEffect). `DecisionSystem.swift`'te `delayed` alanı ZATEN mevcut (@51/@54/@59/@141 doğrulandı) — DecisionSystem'e dokunma.

**GameState alanı + decode:**
- Bildirim (anchor `var crisisChainCount: Int = 0` @52, insertAfter): `var pendingEffects: [PendingEffect] = []`
- Decode (anchor `crisisChainCount = g(.crisisChainCount, 0)` @171, insertAfter): `pendingEffects = g(.pendingEffects, [PendingEffect]())`

**Wiring:**
1. `GameState.swift` @52 / @171 → alan + decode.
2. `GameModel.swift` @1157-1159 (`if card.once || !state.seenEventIDs.contains(card.id) { ... }`) insertAfter → `choice.delayed` kuyruğa ekle (zaman damgası `state.months + d.delayMonths`).
3. `GameModel.swift` @1319 (`advanceProjects(monthFraction)`) insertAfter → `resolvePendingEffects()`.
4. `GameModel.swift` @1374 (`/// HZ-2: kullanıcı eşiklerini...`) insertAfter → `resolvePendingEffects()` metodu (vade kontrolü + apply + clamp + pendingResult/pendingToast).
5. `DecisionContent.swift` @846 (`result: "Genel artış. (Fiyat değişimi..."` + `]),`) insertAfter → 3 pilot kart (delayed-fasthire/techdebt/discount). Anchor benzersiz, price-bump-30 @839 ile ipo-vs-stay-private @851 arasına girer (mevcut C2 kartlarını etkilemez).

**Doğrulama:** stage≥2 seed → agresif seçim → anlık etki + ~2-3 ay sonra "Geçmiş Kararın" kartı/toast + gecikmeli düşüş. Kill+relaunch → kuyruk geri yüklenir, vade hâlâ tetiklenir. Eski save → çökmez. Çift-uygulama yok (removeAll predicate = filter predicate).

---

### ADIM 6 — D2 (Yerel bildirimler) [order 16]
**Zaten yazılı yeni dosya:** `Sources/Systems/NotificationManager.swift`. **GameState alanı:** yok.

**Wiring:**
1. `GameModel.swift` @1555 (`func saveOnBackground() { save() }`) replace → save + `NotificationManager.scheduleReminders(streak:dailyCompleted:)`.
2. `GameModel.swift` @1557 (`func refreshOnForeground() {\n        applyOfflineProgress()`) replace → başına `NotificationManager.cancelAll()`.
3. `ContentView.swift` @189 (`.onChange(of: model.pendingToast) { ... }`) insertAfter → `.onChange(of: model.companySetupComplete)` ile izin iste (`companySetupComplete` @1413 doğrulandı).

**Doğrulama:** Şirket kur → izin diyalogu. Arka plan → planlanır. Foreground → cancelAll. İzin reddi → no-op, çökme yok.

---

### ADIM 7 — B6 (StoreKit 2 IAP + Series A paywall) [order 10] — EN SON kod-içi
**Neden son:** En riskli, kod-dışı ASC aksiyonu gerektirir; izole gating.

**Zaten yazılı yeni dosyalar:** `Sources/Systems/StoreManager.swift`, `Sources/UI/PaywallView.swift`, `Unicorn.storekit`. **GameState alanı:** yok (entitlement Apple'da).

**Wiring:**
1. `GameModel.swift` @11 (`@Published var pendingFundingStage...`) insertAfter → `@Published var pendingSeriesAGate: Bool = false`.
2. `GameModel.swift` @569-588 (`func raiseRound()` tam gövde + `func dismissFunding()`) replace → gate'li raiseRound + `confirmSeriesARaise()` + `performRaise(_:)` + `dismissSeriesAGate()`. (Series A = stage id 3, valuationTarget 15M @321-322 doğrulandı; `next.raiseAmount`/`next.equityGiven` mevcut imza.)
3. `ContentView.swift` @28 (`@StateObject private var model: GameModel`) insertAfter → `@StateObject private var store = StoreManager()`.
4. `ContentView.swift` @351-352 (`} else if let s = model.pendingFundingStage {\n            FundingRoundView(...)`) → **insertAfter DEĞİL, dikkatli yerleştirme:** yeni `else if model.pendingSeriesAGate { ... }` bloğu, `FundingRoundView` satırının ait olduğu `else if` bloğunun KAPANIŞ `}`'sından SONRA gelmeli. Gerçek dosyada @353 `} else if let finale = model.pendingSeasonFinale` zinciri var. **Doğru hedef:** `pendingSeriesAGate` bloğunu `pendingFundingStage` bloğu ile `pendingSeasonFinale` bloğu ARASINA (yani `FundingRoundView`'in kapanışından sonra, `} else if let finale`'den önce) yerleştir. (Bkz. Çakışma Uyarısı #4.)

**Doğrulama:** valuation≥15M + stage=2 seed → "Series A Topla" → state DEĞİŞMEDEN PaywallView. "Şimdilik Seed'de devam" → Stage 2 oynanır. Satın al → isFullVersion → confirmSeriesARaise → FundingRoundView, stage=3. Entitlement varken paywall gelmez. Sil-kur → restore. Eski save → çökmez.

---

## 2. Çakışma Uyarıları (paylaşılan dosyalar — sıralı uygula)

**`GameState.swift` init(from:) — 3 özellik decode satırı ekliyor:**
- A: @127/@217 (`hasSeenOnboarding`), B1: @57/@174 (`totalDecisions`), D1: @52/@171 (`crisisChainCount`).
- Üçü FARKLI anchor → çakışmaz. Ama her birinde **alan bildirimi + decode satırı İKİSİNİ birlikte** ekle (yalnız biri eklenirse: decode eksik = eski save reddedilir; alan eksik = derlenmez).

**`GameState.swift` field declarations:** A @127, B1 @57, D1 @52 — farklı satırlar, sıralı uygula, sorun yok.

**`GameModel.swift` tick() bölgesi (@1315-1320):** A (`maybeDetectArchetype()` @1318 insertAfter) ve D1 (`resolvePendingEffects()` @1319 insertAfter). İki ayrı anchor satırı — A ÖNCE uygulanırsa @1318'den sonra yeni satır girer, D1'in @1319 anchor'ı (`advanceProjects`) hâlâ benzersiz kalır. **Sıra önemsiz ama A'yı önce uygula (ADIM 1 < ADIM 5).**

**`GameModel.swift` resolve() bölgesi:** B1 (@1161 `totalDecisions += 1` insertAfter) ve D1 (@1157-1159 `card.once...` block insertAfter). Farklı anchor, çakışmaz. B1 (ADIM 3) D1'den (ADIM 5) önce → uygula sırası güvenli.

**`GameModel.swift` accessor bölgesi (@1417):** A `founderTitle` insertAfter'a `currentArchetype` ekler — tek özellik, çakışma yok.

**`ContentView.swift` overlay chain (@345-377):** B2 (LessonPopup zaten var, edit yok), B6 (@351 sonrası pendingSeriesAGate bloğu), D2 (@189 onChange). B6'nın overlay yerleşimi **en hassas nokta** — `pendingFundingStage` bloğunun kapanışından sonra, `pendingSeasonFinale`'den önce. insertAfter'ı 2-satırlık anchor'a uygularsan blok ORTASINA düşer ve derlenmez; elle `FundingRoundView` satırının kapanış `}`'sından sonraki satıra yerleştir.

**`ContentView.swift` @28/@153/@189:** B6 (@28 store), D3 (@153 dynamicTypeSize), D2 (@189 onChange) — 3 farklı bölge, çakışmaz.

---

## 3. Özellik Başına Build + Simülatör Doğrulama (özet)

Build (her adım): `cd /Users/omerfaruk/Desktop/Dev/games/Unicorn && xcodegen && xcodebuild -scheme Unicorn -destination 'platform=iOS Simulator,name=iPhone 16' build`

| Adım | Seed/Arg | Beklenen |
|---|---|---|
| A | yeni oyun; eski save | 4 capsule, adım3 aktif, save'de founderLeaning+detectedArchetype; eski save çökmez; BalanceSim 4 persona → bootstrap/vcRocket/niche/platform |
| D3 | normal + Larger Text + AX5 | default birebir; ölçeklenir; accessibility1'de durur |
| B1 | 4 kategori karar; mentor-tip; eski save | sayaçlar artar; mentor-tip artmaz; eski save açılır |
| B2 | Win seed (~$1B); az-karar save; Finale seed; iPhone SE | karne + LessonPopup köprü; fallback; ShareLink skorsuz; taşma yok |
| D1 | stage≥2, users≥600 seed; kill+relaunch | gecikmeli kart ~2-3 ay sonra; kuyruk persist; çift-uygulama yok |
| D2 | şirket kur; arka plan; foreground; izin reddi | izin diyalogu; planla; cancelAll; no-op |
| B6 | stage=2 + valuation≥15M seed; .storekit şema | "Series A Topla" → paywall (state sabit); satın al → stage=3; restore |

---

## 4. ascAction Özeti (kod-dışı — B6 App Store Connect)

1. **Ürün oluştur:** App Store Connect → Unicorn app → In-App Purchases → Non-Consumable, Product ID `co.omerfarukdemiral.unicorn.fullversion`. **Bundle id ile namespace tutarlılığını doğrula** (bundle `co.omerfarukdemiral.unicorn` olmalı).
2. **Fiyat tier:** Kalıcı tier seç (`.storekit` displayPrice 4.99 yalnız sandbox; ASC'de gerçek tier ayrı). Lansman fiyatı promosyon değil — kalıcı tier'ı seç, sonra elle artır.
3. **Lokalizasyon:** TR + EN display name/description gir (Kural-0: yalnız sevk edilmiş içerik — Series A→Unicorn turları, geç-oyun kartları, Defter dersleri, çoklu-strateji ekonomisi; "arketip rozeti" VAAT ETME).
4. **Sandbox test hesabı:** Users and Access → Sandbox → test Apple ID oluştur; simülatörde StoreKit test satın alımı + restore akışını doğrula.
5. **Xcode şema (manuel, opsiyonel kalıcılık):** Edit Scheme → Run → Options → StoreKit Configuration → `Unicorn.storekit`. xcodegen şemayı regenerate edince sıfırlar; kalıcı istenirse `project.yml` `schemes.Unicorn.run` altına `storeKitConfiguration: Unicorn.storekit` ekle (paylaşılan dosya — ana döngü tercihi; @42-52 `schemes.Unicorn.run` mevcut, `storeKitConfiguration` anahtarı YOK).
6. **Privacy:** `PrivacyInfo.xcprivacy` mevcut — IAP veri toplama beyanını ASC App Privacy bölümünde işaretle.

---

## 5. Açık Kararlar (ana döngü onaylasın)
- **FounderLeaning vs FounderArchetype isim ayrımı:** A=`FounderLeaning` (Int, Company.swift), C3=`FounderArchetype` (String, Systems/) — ikisi ayrı dosyada, çakışmaz, derlenir. (Eski ROADMAP'taki "BLOKER" çözülmüş: spec'ler zaten `FounderLeaning` kullanıyor.)
- **C4 ekonomi sabitleri (`salesArpuCap`, `salesArpuPerUnit`, `ltvMonthsCap`) Balance.swift'te mevcut olmalı** (Parti3'te eklendiği belirtildi) — C3'ün `currentArchetype` bunları kullanır. Build hatası verirse C4 sabitlerinin gerçekten eklendiğini doğrula (bu plan kapsamı dışı, önkoşul).
- **B6 fiyat tier + lansman stratejisi** (ascAction #2) ürün sahibi kararı.