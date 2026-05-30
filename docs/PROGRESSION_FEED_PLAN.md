All assumptions verified. Max officeItem id = 42 (new items start at 43 ✓), all 8 ModuleEffect cases exist and match Track B's content exactly, `state.moduleLevels[m.id]` confirms the id==index invariant. The plan is fully grounded. Here is the synthesis.

---

# UNICORN — TEK SIRALI UYGULAMA PLANI
## 4 Track Sentezi · Sole-Builder (tek tek uygula → derle → doğrula)

Kod doğrulandı: officeItems max id=**42** (yeni eşyalar 43'ten başlar ✓), 8 ModuleEffect türü Track B içeriğiyle birebir uyuyor ✓, `state.moduleLevels[m.id]` id==indeks değişmezi geçerli ✓, tüm `pending*` kancaları (cycleReview 779, startNextQuarter 796/809, hasBlockingOverlay 1177, pendingResult 1234/1476, scenario 1153, daily 958, offline 1737) mevcut ✓.

> **Track çıktılarındaki satır numaraları güvenilir DEĞİL** (dosyalar o günden beri değişmiş: officeItems 388'de başlıyor, 444'te değil; modules 285'te). **İmzalar ve `id` değerleri doğru.** Uygularken satır no'ya değil, `grep` ile anchor'a (örn. `id: 42` kaydı, `pendingCycleReview =`) göre konumlan.

---

## 1. ÖZET & ÖNCELİK SIRASI

Kullanıcının **en ısrarlı isteği POPUP→FEED** (Track C) → en yüksek öncelik. Sonra **oyun büyüsün** (Track A mağaza + Track B modüller), en son **panel cila** (Track D).

**Bağımlılık zinciri (neden bu sıra):**
- **Track C (Feed) önce** çünkü en çok acı veren şey bu, VE feed altyapısı (`GameState.feed`, `pushFeed`) sonraki içeriğin (yeni evre açılımı, sezon özeti) doğal yuvası. Önce kurarsan, sonraki track'ler feed'e bağlanabilir.
- **Track A & B sonra** — saf içerik enjeksiyonu (yeni eşya/modül literalleri), düşük risk, derleme-garantili. Oyunu "büyütür".
- **Track D en son** — saf kozmetik (renk/boşluk/font). Feed OfficePanel'e girdiği için (Track C), D'deki OfficePanel header dokunuşu C'den SONRA gelmeli ki çakışmasın.

**Çakışma haritası (sole-builder kritik):**
| Dosya | Hangi track'ler dokunuyor | Sıra zorunluluğu |
|---|---|---|
| `Balance.swift` | A (officeItems, stageUnlocks), B (modules, ModuleDef) | A→B veya B→A, ama **ayrı bölümler** — çakışmaz, tek tek yap |
| `GameModel.swift` | C (pushFeed, pending→feed) | C tek başına |
| `GameState.swift` | C (FeedEntry, feed alanı), A-opsiyonel (seenUnlockStages) | C önce |
| `OfficePanel.swift` | C (ActivityFeedView ekler), D (header cila) | **C→D zorunlu** |
| `ItemShopView.swift` | A (sıralama) | A tek başına |
| `EventOverlays.swift` | A (FundingRound "bu turda açıldı") | A tek başına |
| `ModulesPanel.swift` | B (gruplama), D (cila) | **B→D zorunlu** |
| `Icons.swift` | B (yeni modül ikonları) | B tek başına |
| `TeamPanel/GrowthPanel/StatsPanel` | D | bağımsız |

---

## 2. FAZ FAZ UYGULAMA PLANI

### FAZ 0 — Feed altyapısı (Track C çekirdek) · en yüksek öncelik

| # | İş | type | efor | dosya | hazır mı | açıklama | doğrulama |
|---|---|---|---|---|---|---|---|
| 0.1 | `FeedEntry`/`FeedKind`/`FeedDetailKind` modelleri | content | M | `GameState.swift` | **HAZIR** (Bohça B1) | Codable, decodeIfPresent-korumalı feed girdi tipleri. | Derlenir; yeni tip çakışması yok |
| 0.2 | `GameState`'e `feed`/`feedUnread` alanları + decode + normalize budama | content | S | `GameState.swift` | **HAZIR** (Bohça B2) | `feed: [FeedEntry] = []`, `init(from:)`'e `g(.feed, …)`, `normalize()`'a `prefix(30)`. | Eski save yüklenir, decode patlamaz |
| 0.3 | `pushFeed`/`markFeedRead`/`feedEntries`/`feedUnread`/`companyMonths` API | content | S | `GameModel.swift` | **HAZIR** (Bohça B3) | Feed append yardımcısı (en yeni başta, 30 budar). | Derlenir |
| 0.4 | `lastCycleReview`/`lastSeasonSummary` cache alanları | code | S | `GameModel.swift` | spec | Zengin detay-sheet için son scorecard payload'unu sakla (`@Published var lastCycleReview: CycleReview? = nil`). | Derlenir |

**Doğrulama Faz 0:** `xcodegen && xcodebuild` derler; eski save simctl ile yüklenince çökmez (feed boş gelir).

---

### FAZ 1 — Pending → Feed dönüşümleri (Track C asıl iş)

Her biri **tek tek** uygula+derle. Sırası önemli: önce kolay/izole olanlar, en son çeyrek (otomatik ilerleme riski).

| # | İş | type | efor | dosya | hazır mı | açıklama | doğrulama |
|---|---|---|---|---|---|---|---|
| 1.1 | ScenarioResult → feed | code | S | `GameModel.swift` (`maybeSettleScenarios` ~1153) | spec | `pendingScenarioResult = …` yerine `pushFeed(.scenario,…)` + `state.scenarios.removeAll{$0.id==s.id}`. Guard'lardan `pendingScenarioResult==nil` kalkar. | Senaryo deadline'ı geçince feed satırı, modal yok |
| 1.2 | DailyClose → feed | code | S | `GameModel.swift` (`checkDailyCompletion` ~958) | spec | `pendingDailyClose=…` → `pushFeed(.daily,…)`; `Feedback.success()` KORU. | Günlük hedef dolunca feed satırı |
| 1.3 | SprintClose → feed (toast'a EK) | code | S | `GameModel.swift` (`closeSprint` ~1024+) | spec | Mevcut toast'a ek `pushFeed(.sprint,…)`. | Sprint kapanışı feed'e düşer |
| 1.4 | ResultCard (#26) → feed, ders köprüsü korunur | code | M | `GameModel.swift` (~1234) | spec | `pendingResult=…` → `pushFeed(.decision,…, mechanic: card.category.lessonMechanic)`. İlk-karar tebriği `pendingToast`'ta kalır. | Karar sonucu feed satırı, "detay>" ders açar |
| 1.5 | Gecikmeli etki → feed | code | S | `GameModel.swift` (`resolvePendingEffects` ~1475) | spec | `pendingResult/pendingToast` dallanması → her zaman `pushFeed(.delayed,…)`. | Geçmiş karar sonucu feed'e akar |
| 1.6 | Offline → feed | code | S | `GameModel.swift` (~1737) | spec | `pendingOfflineReport=…` → `pushFeed(.offline,…)`. (İstenirse ilk açılışta modal opsiyonel kalır.) | Geri dönüşte feed satırı |
| 1.7 | Milestone/küçük toast → feed | code | S | `GameModel.swift` (`celebratedUserMilestones`) | spec | Düşük öncelikli kutlamalar `pushFeed(.milestone)`. **Acil runway uyarısı toast KALIR.** | Kilometre taşları feed'de birikir |
| 1.8 | **Çeyrek → feed + OTOMATİK ilerleme** (en riskli) | code | M | `GameModel.swift` (`closeQuarter` ~779, `startNextQuarter` 796/809) | spec | `pendingCycleReview=…` → `lastCycleReview` cache + `pushFeed(.quarter,…, detail:.quarter)` + **`closeQuarter` sonunda `startNextQuarter()` çağır**. `startNextQuarter`'daki `pendingCycleReview=nil` (809) kaldırılır. SeasonFinale modal KALIR + feed özet. | Çeyrek modalsız döner, scorecard "detay>"te |
| 1.9 | `hasBlockingOverlay` temizliği (~1177) | code | S | `GameModel.swift` | spec | Feed'e inen pending*'leri SAYMA; sadece gerçek modal'lar (event/funding/win/bankruptcy/seriesGate/seasonFinale/inspected*). `canShowDecision` doğru kalır. | DecisionCard hâlâ tek modal, üst üste binmez |

**Doğrulama Faz 1:** Her adımdan sonra derle. Faz sonunda simctl'de oyna: çeyrek/sprint/günlük/senaryo/karar — hiçbiri TAMAM-modalı açmamalı, hepsi feed'e düşmeli. Çeyrek otomatik ilerlemeli. Bankruptcy/Win/Funding/SeasonFinale/Onboarding/Paywall/DecisionCard hâlâ modal.

---

### FAZ 2 — Feed UI (Track C görünür kısım)

| # | İş | type | efor | dosya | hazır mı | açıklama | doğrulama |
|---|---|---|---|---|---|---|---|
| 2.1 | `ActivityFeedView` + satır kartları | content | M | **YENİ** `Sources/UI/ActivityFeedView.swift` | **HAZIR** (Bohça C1) | Sade satır kart, kind-tint sol şerit, relatif zaman, `mechanic`→#19 köprü, `detail`→sheet. `AnyButtonStyle` yoksa `allowsHitTesting(hasDetail)` ile çöz. | Feed render olur |
| 2.2 | `FeedDetailSheet` (zengin çeyrek/sezon) | code | M | `ActivityFeedView.swift` veya yeni | spec | `lastCycleReview`/`lastSeasonSummary` cache'inden mevcut `CycleReviewView`/`SeasonFinaleView` gövdesini "Yeni Çeyrek" butonu OLMADAN sheet'te göster. | "detay>" scorecard açar |
| 2.3 | OfficePanel'e feed ekle | code | S | `OfficePanel.swift` | spec | `actionStrip` altına `ActivityFeedView(model,theme)`; kroki hero `maxHeight:.infinity` paylaşır, feed `maxHeight:168`. | Ofis/kroki'de feed görünür |
| 2.4 | `ContentView.overlays`'ten taşınanları kaldır | code | S | `ContentView.swift` | spec | ResultCard/CycleReview/DailyClose/SprintClose/ScenarioResult/OfflineReport overlay satırlarını kaldır. | Modal'lar artık tetiklenmez |
| 2.5 | (Opsiyonel) HUD okunmamış rozeti | code | S | `HUDView.swift` | spec | Defter butonu yanına `feedUnread` rozeti; Ofis'e dönünce `markFeedRead()`. | **Açık karar #1'e bağlı** |

**Doğrulama Faz 2:** Ofis ekranında feed dolu; satıra dokun → ders/scorecard açılır; çeyrek geçince yeni satır en üstte animasyonla belirir.

---

### FAZ 3 — Mağaza evrimi (Track A)

| # | İş | type | efor | dosya | hazır mı | açıklama | doğrulama |
|---|---|---|---|---|---|---|---|
| 3.1 | 27 yeni officeItem (id 43-69) | content | M | `Balance.swift` (`officeItems` dizisi sonu, `id:42` kaydından sonra) | **HAZIR** (Bohça A1) | s2:3, s3:6, s4:7, s5:6, s6:5. Eski id'ler dokunulmaz → save uyumlu. | Mağazada yeni eşyalar gate'li görünür |
| 3.2 | `stageUnlocks(_:)` metin fonksiyonu | content | S | `Balance.swift` (`Balance` enum) | **HAZIR** (Bohça A2) | Evre-açılım vurgu metinleri. | Derlenir |
| 3.3 | FundingRound "BU TURDA AÇILDI" bloğu | content | S | `EventOverlays.swift` (`FundingRoundView` body) | **HAZIR** (Bohça A3) | Mevcut tur kutlamasına unlock listesi — yeni modal YOK. | Funding sonrası açılanlar görünür |
| 3.4 | ItemShop sıralaması (yeni eşya üstte) | content | S | `ItemShopView.swift` (`items` computed) | **HAZIR** (Bohça A4) | `.sorted { $0.unlockStage > $1.unlockStage }` — eskimişlik önlemi. | Geç-evre eşyalar kategoride üstte |

**Doğrulama Faz 3:** Save'i geç evreye tohumla (build_unicorn akışı), mağazada her kategoride yeni prestij eşyalar üstte; kilitliler "Series B" rozetli.

---

### FAZ 4 — Modül derinliği (Track B)

| # | İş | type | efor | dosya | hazır mı | açıklama | doğrulama |
|---|---|---|---|---|---|---|---|
| 4.1 | `modules` literali komple değiştir (8→14) | content | M | `Balance.swift` (`static let modules`) | **HAZIR** (Bohça D1) | İlk 8'in id/effect korunur, unlockStage yeniden yayılır; id 8-13 yeni (her evre +2 modül). | `moduleLevels` resize otomatik, save uyumlu |
| 4.2 | `Icons.Module` 6 yeni id case (ZORUNLU) | content | S | `Icons.swift` (Module enum) | **HAZIR** (Bohça D2) | Yoksa yeni modüller fallback ikon alır. iOS16 SF Symbol notu var. | Yeni modüller doğru ikonla |
| 4.3 | ModulesPanel evre-grup gruplaması | code | M | `ModulesPanel.swift` | spec | `unlockStage` grupla, `stage<=state.stage+1` render, ileri evreler katlı özet. `StageGroupHeader` ince ayraç. | Kademeli ağaç hissi, ferah |
| 4.4 | (Opsiyonel) `ModuleDef.parentID` + `valuationMult` | spec | M | `Balance.swift`, `GameModel.swift` | spec | **İterasyon 1'de EKLEME.** Hikaye rozeti/değerleme kaldıracı isterse İt.2. | — |

**Doğrulama Faz 4:** Derle (Icons ZORUNLU). Her evrede ModulesPanel'de tam 2 yeni modül açılır; geç-evre baseCost'lar (120K-500K) ulaşılabilir. Eski save modül seviyeleri korunur.

---

### FAZ 5 — Panel cila (Track D) · en son

Hepsi kozmetik (foregroundStyle/background/spacing/font + header VStack). Bağımsız uygulanabilir; **OfficePanel D yok** (Track C'de zaten dokunuldu). Sıra serbest.

| # | İş | type | efor | dosya | hazır mı | açıklama | doğrulama |
|---|---|---|---|---|---|---|---|
| 5.1 | TeamPanel cila | spec | M | `TeamPanel.swift` | spec | Dept avatar nötr yüzey+renkli ikon; "İşe Al"→accent; outputBar→accent; sağ ofis-chip kaldır, eyebrow header. | Renk yarışı biter |
| 5.2 | GrowthPanel cila | spec | M | `GrowthPanel.swift` | spec | 4 stepButton dolu→tint+stroke; metric değerleri nötr (renk yalnız LTV:CAC+Net); spacing s3; eyebrow header. | En gürültülü panel sakinleşir |
| 5.3 | ModulesPanel cila | spec | S | `ModulesPanel.swift` | spec | İkon 40px nötr çerçeve; "Lv x/y" accent→nötr pill; eyebrow header. **4.3'ten SONRA.** | Tek accent kaynağı |
| 5.4 | StatsPanel cila | spec | S | `StatsPanel.swift` | spec | grid spacing s3; "Net/Ay" ikon koşullu renk (`metric` tint param); eyebrow header. | Ritim + anlamlı sapma |

**Doğrulama Faz 5:** Görsel — 4 panel + kroki aynı eyebrow+başlık dili; tek accent; ferah. Tüm `model.*` çağrıları/popover/segment davranışı değişmez.

---

## 3. İÇERİK BOHÇASI (yapıştırmaya hazır)

> Tüm bloklar gerçek imzalara uygun. **A1** dizinin `id:42` kaydından sonra, dizinin `]`'inden önce; **D1** mevcut `modules` literalinin TAMAMEN yerine.

### B1 — FeedEntry/FeedKind/FeedDetailKind (`GameState.swift`)
Track C Bölüm 3'teki `struct FeedEntry` + `enum FeedKind` + `enum FeedDetailKind` blokları **olduğu gibi**. (Kod doğrulandı: dosyadaki mevcut `g(...)`+`decodeIfPresent` deseniyle aynı → migration-proof.)

### B2 — GameState alanları (`GameState.swift`)
```swift
// Aktivite Akışı (Track C) — modal yerine ekranda kalıcı biriken olaylar.
var feed: [FeedEntry] = []
var feedUnread: Int = 0
```
`init(from:)`'e: `feed = g(.feed, [FeedEntry]())` / `feedUnread = g(.feedUnread, 0)`
`normalize()` sonuna: `if feed.count > 30 { feed = Array(feed.prefix(30)) }` / `feedUnread = max(0, min(feedUnread, feed.count))`

### B3 — pushFeed API (`GameModel.swift`)
Track C Bölüm 4a'daki `pushFeed`/`feedEntries`/`feedUnread`/`markFeedRead` blokları **olduğu gibi** + `var companyMonths: Double { state.months }`.

### A1 — 27 yeni officeItem (id 43-69)
Track A Bölüm 2'deki `.init(id: 43 …)` → `.init(id: 69 …)` bloğu **olduğu gibi** (max id=42 doğrulandı, çakışma yok).

### A2 — stageUnlocks (`Balance` enum)
Track A Bölüm 3.1 Adım 1'deki `static func stageUnlocks(_ stage: Int) -> [String]` **olduğu gibi**.

### A3 — FundingRound açılım bloğu (`EventOverlays.swift`)
Track A Bölüm 3.1 Adım 2'deki `let unlocks = Balance.stageUnlocks(stageIndex) …` VStack bloğu. (Not: `FundingRoundView`'da `stageIndex`/`theme` değişken adlarını dosyadan grep ile doğrula — Track gerçek imzaya göre yazılmış.)

### A4 — ItemShop sıralama (`ItemShopView.swift`)
```swift
private var items: [OfficeItemDef] {
    Balance.officeItems
        .filter { $0.category == category }
        .sorted { $0.unlockStage > $1.unlockStage }
}
```

### D1 — modules literali (8→14) (`Balance.swift`)
Track B Bölüm 1'deki tüm `static let modules: [ModuleDef] = [ … ]` bloğu **olduğu gibi** (mevcut literalin yerine). 8 ModuleEffect türü ve id==indeks doğrulandı.

### D2 — Icons.Module (`Icons.swift`)
Track B Bölüm 2'deki 6 sabit + 6 switch case **olduğu gibi**. SF Symbol fallback notu geçerli (iOS16: `person.badge.shield.checkmark.fill`/`creditcard.viewfinder` yoksa `checkmark.shield.fill`/`dollarsign.arrow.circlepath`).

### C1 — ActivityFeedView (`Sources/UI/ActivityFeedView.swift`)
Track C Bölüm 5'teki `struct ActivityFeedView` **olduğu gibi**. Yapıştırma sonrası 2 nokta DOĞRULA: (a) `AnyButtonStyle` projede var mı — yoksa satırı `.buttonStyle(.pressable)` + `.allowsHitTesting(hasDetail)`; (b) `Haptics.selection()`/`Palette.success`/`theme.textQuaternary`/`Radius.m` adları projede mevcut mu (grep).

---

## 4. AÇIK KARARLAR (sahip onayı gerekli)

1. **Feed yeri kesinleşsin mi?** Track C önerisi: **yeni sekme YOK** → Ofis ekranında (kroki sub-tab) kalıcı "Akış" bölümü + opsiyonel HUD rozeti. Kroki biraz kısalır (feed ~168px). *Onay: bu mu, yoksa feed ayrı bir 6. sekme/Ofis alt-tab mı?* (Öneri: kalabalık istemediğin için Ofis-içi.)

2. **HUD okunmamış rozeti (2.5) yapılsın mı?** Opsiyonel. Sade-premium için feed-içi vurgu yeterli olabilir; rozet "bildirim noktası" hissi katar ama minik gürültü. *Onay: rozet evet/hayır.*

3. **Offline raporu (1.6): ilk açılışta hâlâ kısa modal mı, tamamen feed mi?** Spam-azaltma → tamamen feed önerilir. *Onay.*

4. **SprintClose toast'ı (1.3): feed gelince toast KALSIN mı kalksın mı?** Feed kalıcı olduğu için toast opsiyonel. *Onay: çift bildirim (toast+feed) mı, sadece feed mi?*

5. **Modal kalacaklar listesi onayı (8 modal):** Onboarding, CompanySetup, Bankruptcy, Win, Paywall/SeriesGate, FundingRound, SeasonFinale, DecisionCard (+ kullanıcının açtığı LessonPopup/EmployeeCard). *Bu liste onaylanıyor mu — özellikle SeasonFinale modal mı feed mi (Track önerisi: modal + feed özet)?*

6. **Track A "açıldı rozeti" (`seenUnlockStages`, opsiyonel 3.4) İt.1'de mi?** Öneri: HAYIR — 3.1 tek-modal vurgu + 3.2 sıralama yeterli. *Onay.*

7. **Track B `parentID`/`valuationMult` (4.4) İt.1'de mi?** Öneri: HAYIR, İt.2. Mevcut 8 efekt yeterli, denge riski yok. *Onay.*

8. **SF Symbol iOS sürümü:** `creditcard.viewfinder` vb. minimum deployment target'ında var mı? *xcodebuild target'ından doğrula; yoksa Bohça D2'deki güvenli alternatifleri kullan.*

---

**İlk komut:** Faz 0.1-0.2'yi (`GameState.swift` feed modeli + alanları) uygula → `xcodegen && xcodebuild` → eski save ile çökme yok mu kontrol et → Faz 0.3'e geç.