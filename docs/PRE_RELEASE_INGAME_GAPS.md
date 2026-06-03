# Yayın Öncesi — Oyun-İçi Eksikler Raporu

> **Kapsam:** Yalnızca **oyunun kendi içinde kalan** (oynanış, içerik, his, akış) eksikler.
> Dış altyapı (analitik, reklam, iCloud, crash reporting, ASO) bu dokümanın **dışında** —
> en altta "Kapsam Dışı" başlığında sadece listelenir.
>
> **Bağlam:** GARAJ/Unicorn — SwiftUI startup simülasyonu. Çekirdek döngü, ekonomi,
> kalıcılık ve içerik olgun ve test edilmiş (77 birim testi). Bu rapor, çekirdek sağlamken
> yayına gitmeden önce oyun-içi deneyimi tamamlayan boşlukları önceliklendirir.
>
> _Son güncelleme: 2026-06-03_

---

## ✅ Sağlam — yapıldı ve test edildi

| Alan | Durum |
|---|---|
| Core loop (karar→sonuç + tick ekonomi) | ✅ Saf `step()`, deterministik |
| Karar gerilim döngüsü (70+ kart, gecikmeli/olasılıklı etkiler) | ✅ `DecisionSystem` + `PendingEffects` |
| Sistemler-arası ekonomi bağı (moral→churn/üretim, reklam→CAC, ekip→burn→runway, itibar→organik) | ✅ `GameModel.advanceEconomy` |
| Hedef/"sıradaki adım" (günlük + sprint + 7-katmanlı yönlendirme) | ✅ `DailyGoalSystem`, `SprintSystem`, `nextDirective` |
| Post-mortem + NG+ (iflas-izi, nedensel ölüm zinciri) | ✅ `PostMortemView` + Anlamlı İflas |
| **Öğrenme döngüsü — hata-tetikli dersler** (Faz 5) | ✅ `evaluateLessonTriggers`, kilitli Defter, 20 ders açılış yolu |
| **Post-mortem zirve metrikleri (Faz 4)** | ✅ `peakUsers/MRR/Valuation/Reputation` + "kaç ay dayandın" başlıkta |
| **Nedensellik akışı + rakip detayı (Faz 2 UX)** | ✅ fire çipi, proje-canlı büyüme/ARPU çipi, rakip baskı şiddeti%+CAC/churn etkisi |
| **Onboarding ilk-hedef splash (Faz 3)** | ✅ `FirstGoalSplash` — kuruluş sonrası bir kez, `nextDirective`'i gösterir |
| **Welcome-back ekranı (Faz 6)** | ✅ `OfflineReportView` bağlandı (1sa+ yoklukta), eşik `offlineReportMinSeconds` |
| **Defter "yeni ders" rozeti** | ✅ ControlDock Defter butonunda `newLessonIds` sayaç rozeti |
| Deterministik seed (replay/test/balans-sim) (Faz 0) | ✅ `SplitMix64RNG` + `state.seed` |
| Idle/offline ilerleme | ✅ `applyOfflineProgress` (8sa tavan) |
| Kalıcılık (migration-proof save) | ✅ `SaveManager` |
| Onboarding (kuruluş + tanıtım) | ✅ `OnboardingOverlay` + `CompanySetupOverlay` |
| Juice (haptik, çünkü-çipleri, nakit çipi, yaşayan ofis) | ✅ `Haptics`/`Feedback`, overlay'ler |

---

## 🟡 Oyun-İçi Eksikler — yapılacaklar (öncelikli)

### P1 — Hissi/anlamı doğrudan artıran, küçük-orta — ✅ TAMAMLANDI (2026-06-03)

| # | Eksik | Durum |
|---|-------|---|
| ~~1~~ | ~~Nedensellik akışı (Faz 2 UX)~~ | ✅ Keşifte görüldü: reklam→CAC ve ekip→burn→runway (hire) ZATEN vardı. Eklenenler: **fire çipi** (hire simetriği) + **proje-canlı çipi** (organik büyüme +%X · ARPU +%Y) |
| ~~2~~ | ~~Rakip-baskı detayı~~ | ✅ Anlatı+isim+sektör zaten vardı; eklenen: **baskı şiddeti %** + **CAC ~+%X / churn ~+%Y** etkisi (feed + `rivalMoveLabel`) |
| ~~3~~ | ~~Post-mortem zirve metrikleri (Faz 4)~~ | ✅ peakUsers/MRR/Valuation/Reputation + "kaç ay dayandın" + zirve bölümü |

### P2 — Onboarding & geri-dönüş cilası — ✅ TAMAMLANDI (2026-06-03)

| # | Eksik | Durum |
|---|-------|---|
| ~~4~~ | ~~Onboarding ilk-hedef splash (Faz 3)~~ | ✅ `FirstGoalSplash` overlay: kuruluş sonrası bir kez `nextDirective`'i "İlk Hedefin" olarak gösterir; `hasSeenFirstGoalSplash` bayrağı |
| ~~5~~ | ~~Welcome-back ekranı (Faz 6)~~ | ✅ Keşif: `OfflineReportView`+struct+`pendingOfflineReport` ZATEN kuruluydu — sadece bağlandı (1sa+ eşik `offlineReportMinSeconds`) |
| ~~6~~ | ~~Defter "yeni ders" rozeti~~ | ✅ ControlDock Defter butonunda `newLessonIds` sayaç rozeti; Defter açılınca `markLessonsSeen` temizler |

### P3 — İçerik/ses derinliği — ✅ TAMAMLANDI (2026-06-03)

| # | Eksik | Durum |
|---|-------|---|
| ~~7~~ | ~~Müzik & SFX zenginliği~~ | ✅ Keşif: `AudioManager`+8 SFX+müzik+`Feedback` ZATEN production-ready, yeni asset gerekmez. Eklenen: **sessiz olaylara ses kapsamı** (fire→warning, modül→tap, senaryo sonucu→success/warning) — mevcut SFX'leri yeniden kullanır |
| ~~8~~ | ~~Öğrenme döngüsü derinleştirme~~ | ✅ Counterfactual **"Yansıma"** — `DecisionSystem.reflection`: "Bu seçim X tarafına yaslandı, Y ödün vererek. Diğer yol Z odağındaydı. İkisi de geçerli — şirketin o an neye ihtiyacı vardı?" (verdict DEĞİL; DNA "tek doğru cevap yok"a uygun). Feed detayında `reflectionBlock` |

---

## ⚠️ Karar Bekleyen — yapalım mı?

| Konu | Durum | Not |
|---|---|---|
| **Soft/Hard currency** | Tek para birimi (dolar) | Premium/soft currency ayrımı yok. Bu tür için **kasıtlı sadelik** olabilir; eklenirse ekonomi yeniden dengelenmeli. Karar gerekli. |
| **Push notification tetikleyicileri** | Altyapı (`NotificationManager`) var | Anlamlı tetikler (runway kritik, sprint bitti, offline-dönüş) kurulmamış. Sınırda "oyun-içi/engagement". |

---

## Kapsam Dışı (bu doküman oyun-içine odaklı — sadece hatırlatma)

Yayın için gereken ama **oyunun içinde olmayan** kalemler ayrı ele alınmalı:
`❌ Analitik (event tracking)` · `❌ Crash reporting` · `❌ Rewarded reklam` · `❌ iCloud sync` · `❌ A/B test` · `❓ ASO varlıkları` · `❓ Gerçek-cihaz test akışı`

---

## Önerilen Sıra

1. **#3 Zirve metrikleri** (en küçük, en görünür kazanç)
2. **#1 + #2 Nedensellik akışı + rakip detayı** (brief'in ruhu; simülasyonu duyusal yapar)
3. **#4 + #5 + #6 Onboarding/welcome-back/Defter rozeti** (retention cilası, hepsi küçük — tek turda)
4. **#7 Ses** + **#8 öğrenme derinleştirme** (his/cila)
5. Karar: soft/hard currency + push tetikleyicileri
