# Retention & Oyun-Matematiği Yol Haritası — "Tamamlanan Döngüler"

## İlke (kaynak: kullanıcı paylaşımı)
**Retention sonsuz bir merdiven değil, TAMAMLANAN DÖNGÜLERDİR.**
- Klasik gamification (puan/seviye/rozet, sonsuz tırmanış) 3. ayda ölür: bitiş çizgisi yok, "burada ne kazanıyorum?" → churn.
- Duolingo çözümü: **haftalık lig döngüsü** (Bronz→Gümüş→Altın→Elmas). Her hafta kapanır → sonuç görürsün → terfi/düşüş (gerçek bahis) → taze hafta başlar. Tekrarlanabilir, tamamlanan döngüler. Lige katılan kullanıcı **%20 daha fazla** vakit geçiriyor.
- Sorulacak soru: oyunda bir "hafta sonu / zirve / kapanış anı" var mı, yoksa sadece sonsuza yükselen bir sayı mı?

## Bu oyundaki durum
Unicorn ($1B) bir bitiş çizgisi VAR ama uzun ve tek yönlü. Eksik olan: **kısa, tekrarlayan, kapanan döngüler + gerçek bahisli sıralama.** Funding turları kilometre taşı ama düşüş/rekabet yok.

## Ajan kuralları (HER İTERASYON)
1. Bu listeden **SIRADAKİ tek maddeyi** uygula (yukarıdan aşağı). Birden fazla alma.
2. Koda gerçekten ENTEGRE et (model + UI + gerekiyorsa Balance). Sadece öneri yazma.
3. `xcodebuild ... BUILD SUCCEEDED` olana dek doğrula; mevcut özellikleri BOZMA. Simülatörde seed save + screenshot ile gör.
4. Bu dosyada maddeyi `[x]` işaretle + altına "ne yapıldı/hangi dosyalar" notu ekle. Build kırıksa madde `[ ]` kalır.
5. Tema/font (Space Grotesk sayı, Inter metin) ve mevcut akışa uy. Türkçe.

## Backlog (öncelik sırası)

- [x] **1. Startup Ligleri + Çeyrek Değerlendirmesi (completed-cycle çekirdeği).**
  Her "çeyrek" (≈3 oyun-ayı) kapanır → **Board Review scorecard** (o çeyreğin kullanıcı büyümesi %, gelir, değerleme artışı, moral, karar sayısı → performans skoru) → simüle rakip kohortla kıyas → **terfi/düşüş** (Garaj Ligi → Tohum → Melek → Seri → Elmas → Unicorn Ligi; Bronz/Gümüş/Altın/Elmas eşleniği) → **taze çeyrek** yeni hedeflerle başlar. Kapanış overlay'i (zirve+sonuç+"Yeni Çeyrek" butonu) + HUD'da/Yol'da lig rozeti. GameState'e lig+çeyrek alanları, GameModel'e çeyrek zamanlayıcı/skor/terfi mantığı, `LeagueSystem.swift`, `CycleReviewView.swift`.

- [x] **2. Günlük hedef + kapanış + streak.** Her oyun-günü/oturum küçük tamamlanabilir hedef ("bugün 1 işe alım / 1 karar / +X kullanıcı") → tamamlanınca kapanış+ödül; streak haftalık lige puan besler. Geri-dönüş kancası.

- [x] **3. Haftalık sprint (tamamlanabilir hedef + ödül).** Çeyrek içinde haftalık net amaç (ör. "bu hafta +%10 MRR"); tamamlanınca belirgin zirve+kutlama, başarısızsa kapanış yine olur (sonuç görürsün).

- [x] **4. Rakip kohort / canlı leaderboard (gerçek bahis).** Lig içinde 8-10 simüle rakip startup (isim+ilerleme), haftalık sıralama; terfi/düşüş gerçek hisset. İsteğe bağlı isim havuzu.

- [x] **5. Sezon finali + kalıcı ödül.** Birkaç çeyrekte bir "sezon" kapanışı: rozet/ünvan/kalıcı küçük çarpan (founderXP benzeri) — tamamlanma hissi + uzun vade.

- [x] **6. Math-denge turu:** yeni döngü ödülleri ekonomiyi bozmasın; BalanceSim ile çeyrek skorları ve ödülleri kalibre et, raporla.

## Değişiklik günlüğü
(Her iterasyon sonunda ajan buraya tarihli kısa not ekler.)

- **2026-05-28 — Madde 1: Startup Ligleri + Çeyrek Değerlendirmesi.**
  Her ≈3 oyun-ayı (Balance.monthsPerQuarter) bir çeyrek kapanır → performans skoru
  (kullanıcı büyümesi %, değerleme/MRR artışı, karar sayısı, ortalama moral; 0-100 ağırlıklı)
  → sabit eşik + küçük rastgele rakip bar'ına göre terfi/kaldı/düşüş → taze çeyrek.
  Ligler: Garaj → Tohum → Melek → Seri → Elmas → Unicorn. Terfi ödülü sadece küçük
  moral/itibar (nakit enjeksiyonu YOK — ekonomi korunur).
  Dosyalar: yeni `Sources/Systems/LeagueSystem.swift` (saf skor/terfi mantığı + lig tanımları),
  yeni `Sources/UI/CycleReviewView.swift` (kapanış scorecard overlay + LeagueBadge + LeaguePill rozeti);
  `GameState.swift` (leagueTier/quarterIndex/snapshot alanları, Codable + normalize varsayılan),
  `GameModel.swift` (tick çeyrek zamanlayıcı, closeQuarter/startNextQuarter, pendingCycleReview),
  `Balance.swift` (monthsPerQuarter + terfi bonusları), `ContentView.swift` (overlay zinciri),
  `HUDView.swift` (lig rozeti). Build SUCCEEDED; simülatörde terfi + düşüş overlay'i ve
  HUD rozeti ekran görüntüsüyle doğrulandı.

- **2026-05-28 — Madde 2: Günlük Hedef + Streak (geri-dönüş kancası).**
  Gerçek-takvim gününe bağlı küçük, tamamlanabilir 3 alt görev (1 işe alım + 1 karar +
  ölçeğe göre +X kullanıcı) → hepsi tamamlanınca KAPANIŞ kutlaması + küçük ödül
  (moral +5 / itibar +2; streak'in tavanlı moral hedefi katkısı — nakit YOK, ekonomi korunur)
  + streak +1. Streak ardışık günlerle büyür, gün kaçırılınca sıfırlanır; çeyrek lig skoruna
  tavanlı küçük katkı verir (completed-cycle zinciri: günlük → çeyrek). Önceki ajan yarıda
  kalmıştı; tamamlanan eksikler: `DailyClose` payload tipi + `ScoreBreakdown.streakBonus`
  alanı (tutarsızlık düzeltmesi). Dosyalar: yeni `Sources/UI/DailyGoalView.swift`
  (Ofis ekranı Günlük Hedef kartı — alt görev listesi + ilerleme barları + flame.fill streak
  rozeti; ve CycleReview dilinde DailyCloseView kapanış overlay'i, success haptik);
  `GameModel.swift` (DailyClose struct), `LeagueSystem.swift` (streakBonus alanı),
  `OfficePanel.swift` (kart bağlandı), `ContentView.swift` (overlay zincirine eklendi).
  Mevcut sistem (DailyGoalSystem, GameModel günlük mantığı, GameState alanları) korundu.
  Build SUCCEEDED; simülatörde kart, ilerleme (1/1, 30/30), kapanış kutlaması (streak 2→3,
  ödül satırları) ve restart sonrası "Bugün tamamlandı" durumu ekran görüntüleriyle doğrulandı.

- **2026-05-28 — Madde 3: Haftalık Sprint (çeyrek içi tamamlanan döngü).**
  Çeyrek (3 oyun-ayı) içinde tekrarlayan kısa "hafta" dilimi (Balance.monthsPerSprint = 0.5 →
  çeyrekte ~6 sprint). Her sprint başında ölçeğe göre seçilen, net + TAMAMLANABİLİR tek hedef
  (rotasyon: +%X MRR / +X kullanıcı / N karar; SprintSystem.goal). Süre dolunca HER ZAMAN
  kapanış (completed-cycle ilkesi): başarılıysa belirgin zirve — gold trophy + parıltı halkası +
  success haptik + küçük ödül (moral +4 / itibar +2, nakit YOK — ekonomi korunur); başarısızsa
  yine kapanış (sonucu görürsün, ödül yok, rigid haptik). Lige bağ: bu çeyrekte kazanılan
  sprint'ler çeyrek lig skoruna tavanlı küçük katkı verir (SprintSystem.leagueScoreBonus,
  streakBonus zincirine eklendi; completed-cycle: sprint → çeyrek). Günlük hedefle çakışmaz,
  tamamlayıcıdır (sprint çeyrek-ölçekli kısa amaç, günlük gün-ölçekli alışkanlık).
  Dosyalar: yeni `Sources/Systems/SprintSystem.swift` (saf hedef seçimi/ilerleme/lig bonusu),
  yeni `Sources/UI/SprintView.swift` (Ofis ekranı Sprint kartı — hedef + ilerleme barı +
  kalan süre şeridi + zafer rozeti; ve CycleReview dilinde SprintCloseView kapanış overlay'i);
  `GameState.swift` (sprintIndex/sprintStartMonth/sprintGoalKind/Target/snapshot/sprintsWon
  alanları, Codable + normalize güvenli varsayılan — eski kayıt çökmez), `GameModel.swift`
  (startNewSprint/maybeCloseSprint/closeSprint/startNextSprint, tick kancası, SprintClose struct,
  çeyrek skor beslemesi + çeyrek başı sayaç sıfırlama), `Balance.swift` (monthsPerSprint +
  sprint ödül/lig sabitleri), `OfficePanel.swift` (kart Günlük Hedef üstüne bağlandı),
  `ContentView.swift` (overlay zincirine CycleReview ile DailyClose arasına eklendi).
  Build SUCCEEDED; simülatörde aktif kart (MRR ve kullanıcı hedef varyantları, ilerleme barı,
  süre şeridi, zafer rozeti), başarılı kapanış (Sprint 2 Başarılı, 103/100, ödül satırları) ve
  başarısız kapanış (Sprint 3 Kapandı, %3/%80, ödülsüz) ekran görüntüleriyle doğrulandı.
  Mevcut sistemler (Ligler/Çeyrek, Günlük Hedef/Streak, ofis, funding) korundu.

- **2026-05-28 — Madde 4: Rakip Kohort + Canlı Leaderboard (gerçek bahis).**
  Önceki sabit-eşik + tek rastgele bar yerine, her çeyrek başında oyuncunun ligine uygun
  "güç"te taze 8 simüle rakip startup'lık kohort (oyuncu dahil 9'luk). Rakipler isim havuzundan
  (Nimbus/Vexel/Quanta... 36 isim) seçilir; çeyrek skorları oyun temposuyla (her tick) banttaki
  hedeflerine doğru yumuşakça ilerler + küçük titreşim → CANLI standings. Çeyrek kapanışında
  oyuncu + rakipler çeyrek skoruna göre SIRALANIR; terfi/düşüş artık SIRALAMAYA bağlı (Duolingo
  ligi gibi): ilk 3 terfi, son 3 düşer (en üst ligde terfi yok, en alt ligde düşüş yok). Üst
  ligler daha rekabetçi (rakip güç bandı tier ile yükselir). Lig değişince taze kohort yeniden
  üretilir. CycleReview kapanışına "KOHORT SIRALAMASI" bölümü + headline'a oyuncunun yeri
  ("9 startup içinde 1. oldun") eklendi; içerik uzadığı için overlay ScrollView'a sarıldı.
  Canlı leaderboard kartı Yol Haritası sekmesinde + HUD lig rozetine tıkla açılan sheet'te.
  Ödül/ekonomi sabitlerine DOKUNULMADI (terfi prestij ödülü madde 1'den aynı; nakit yok).
  Dosyalar: yeni `Sources/Systems/CohortSystem.swift` (isim havuzu, lig-güç bandı, taze kohort,
  skor ilerlemesi, sıralama, sıraya göre terfi/düşüş — saf fonksiyonlar);
  yeni `Sources/UI/LeaderboardView.swift` (LeaderboardCard + LeaderboardList/Row + LeaderboardSheet,
  oyuncu vurgulu, terfi=yeşil↑ / düşüş=kırmızı↓ bölgeleri, skor barları);
  `GameState.swift` (cohortNames/cohortScores/cohortTier alanları, Codable + normalize güvenli —
  dizi uzunluk eşitleme + skor clamp; eski kayıt çökmez); `GameModel.swift` (liveQuarterScore,
  liveStandings, seedCohortIfNeeded/regenerateCohort/advanceCohort, tick kancası, closeQuarter
  sıralamaya bağlandı, CycleReview payload'una standings+playerRank, startNextQuarter + restart
  taze kohort); `CycleReviewView.swift` (ScrollView + cohortStandings bölümü + sıralı headline,
  LeaguePill opsiyonel onTap); `RoadmapPanel.swift` (LeaderboardCard bölümü); `HUDView.swift`
  (lig rozetine tıkla → LeaderboardSheet). Build SUCCEEDED; simülatörde TERFİ senaryosu
  (skor 81, "9 içinde 1.", oyuncu üstte yeşil↑) ve DÜŞÜŞ senaryosu (skor 4, "9 içinde 9.",
  oyuncu altta kırmızı↓) çeyrek kapanış ekran görüntüleriyle doğrulandı.
  Mevcut sistemler (Ligler/Çeyrek akışı, Günlük/Streak, Sprint, funding, ofis) korundu.

- **2026-05-28 — Madde 5: Sezon Finali + Kalıcı Ödül (uzun-vade tamamlanma).**
  Birkaç çeyrek = 1 sezon (Balance.quartersPerSeason = 4). Her "Yeni Çeyrek" basışında
  bu sezonda kapanan çeyrek sayılır (quartersThisSeason); sezon dolunca (startNextQuarter
  içinde) GÖRKEMLİ sezon finali tetiklenir. Finale: kahraman ünvan/rozet (sezon sayısıyla
  yükselen koleksiyon — Yükselen Kurucu → ... → Unicorn Lordu, sonu roma rakamıyla döngüsel)
  + sezon özeti satırları (kapanan çeyrek, kazanılan terfi, en yüksek lig, toplam sprint/günlük,
  ortalama çeyrek skoru). KALICI ödül: küçük üretim çarpanı (+%2/sezon, +%20 tavan — founderBonus
  mantığında, deptOutput'a çarpan; ekonomiyi bozmaz) + ünvan koleksiyonu; ikisi de GameState'te
  saklanır ve sonraki sezonlara taşınır. "Yeni Sezon"a basınca ödül uygulanır (seasonsCompleted +1),
  küçük moral/itibar dokunuşu (nakit YOK), sezon özeti sayaçları sıfırlanır (çarpan/ünvan kalıcı).
  Dosyalar: yeni `Sources/Systems/SeasonSystem.swift` (ünvan koleksiyonu, kalıcı çarpan hesabı,
  Summary tipi — saf fonksiyonlar); yeni `Sources/UI/SeasonFinaleView.swift` (Funding/Win + CycleReview
  dilinde görkemli finale overlay — çift parıltı halkalı ünvan rozeti hero, ünvan/özet/kalıcı ödül
  kartları, gold "Yeni Sezon" butonu, success haptik; ve Yol Haritası SeasonCollectionCard —
  ünvan rozet grid + çeyrek ilerleme halkası + kalıcı çarpan satırı); `GameState.swift`
  (seasonIndex/quartersThisSeason/seasonsCompleted + sezon-içi birikim alanları, Codable +
  normalize güvenli varsayılan — eski kayıt çökmez); `GameModel.swift` (seasonMultiplier deptOutput'a
  eklendi, closeQuarter sezon birikimi besler, startNextQuarter sezon sayar + closeSeason tetikler,
  startNextSeason kalıcı ödülü uygular, SeasonFinale payload + erişimciler); `Balance.swift`
  (quartersPerSeason + sezon çarpan/ödül sabitleri); `ContentView.swift` (overlay zincirine
  CycleReview ÜSTÜNE — çeyrek "Yeni Çeyrek"e basınca sezon doluysa finale gelir);
  `RoadmapPanel.swift` (SeasonCollectionCard bölümü). Build SUCCEEDED; simülatörde çeyrek kapanışı
  (skor 100, terfi), sezon finali overlay'i (Sezon 3, Vizyoner ünvanı, özet satırları, +%2/+%6 kalıcı
  ödül) ve Yol koleksiyon kartı (2 ünvan rozeti, +%4 kalıcı çarpan, 3/4 çeyrek halkası) ekran
  görüntüleriyle doğrulandı. Dengeye etki: kalıcı çarpan küçük + tavanlı (maks +%20), nakit ödül yok —
  ekonomi sabitleri korundu. Korunan sistemler: Ligler/Çeyrek, kohort/leaderboard, Sprint,
  Günlük Hedef, ofis, funding/iflas/kararlar, para birimi/hız/toast/SF Symbol/fontlar.

- **2026-05-28 — Madde 6: Math-denge turu (yeni döngü ödüllerinin ekonomi kalibrasyonu).**
  Madde 1-5 ile eklenen completed-cycle ödülleri (Lig/Çeyrek, Günlük/Streak, Sprint,
  Kohort, Sezon) nakit vermez; ekonomiye 3 dolaylı kanaldan akar: moral→moraleFactor→üretim,
  itibar→organik/viral büyüme + CAC, sezon çarpanı→doğrudan üretim. BalanceSim bu kanalları
  modelleyecek şekilde GÜNCELLENDİ (deptOutput'a seasonMultiplier, moraleTarget'a
  streakMoraleBonus, advanceEconomy'de reputationFloor, Runner.advanceRetention() ile
  sprint/çeyrek/sezon kapanışlarını oyun-zamanına bağlı tetikleme + aktif-oyuncu varsayımları
  sprintWinRate 0.70 / quartersPerPromotion 2 / onlineFactor 0.35; RETENTION_REWARDS_ENABLED
  anahtarı). "Akıllı oyuncu" koşuldu. BULGU: kalibrasyonsuz haliyle ödüller ideal-aktif
  oyuncuyu ~%47 hızlandırıyordu (ezici) — en güçlü kanal streak'in moraleTarget'a kalıcı
  katkısı. KALİBRASYON (yalnızca sayısal sabit, Balance.swift): streakMoraleCap 8→4,
  streakMoralePerDay 0.8→0.5, seasonOutputBonusCap +%20→+%15. Anlık dokunuşlar + tur
  ödülleri + +%2/sezon DEĞİŞMEDİ (zaten küçük/geçici). NİHAİ: ödüllü Garaj→Unicorn 76.3 dk
  (üst sınır; tipik oyuncu ~%10-12), ödülsüz çekirdek 95.9 dk → ödül kaldıracı ~%20
  (emek-karşılığı, reklamın %7'sinden büyük ama "bedava değil"). Eğri tatmin edici (hook
  3.1 dk, tur trendi kademeli yavaşlıyor, LTV:CAC 7.9, churn %1.7), iflas hâlâ adil
  (acemi @ 2d 09sn — ödül toplanmadan ölüyor), sezon tavanı ×1.15 makul. Dosyalar:
  `Tools/BalanceSim/Sources/BalanceSim/main.swift` (retention modeli + §g2 raporu),
  `Sources/Model/Balance.swift` (3 sabit kalibrasyonu), `docs/BALANCE_REPORT.md` (§2 not + §9
  yeni bölüm). App derlendi: BUILD SUCCEEDED (yalnızca sabit değişti, davranış bozulmadı).
  Korunan tüm sistemler: Ligler/Çeyrek, kohort/leaderboard, Sprint, Günlük/Streak, Sezon,
  ofis, funding/iflas/kararlar, reklam politikası, OpEx/CAC modeli.
