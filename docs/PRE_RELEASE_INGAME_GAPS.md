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

### P2 — Onboarding & geri-dönüş cilası, küçük

| # | Eksik | Neden önemli | Tahmini iş | Dokunulacak |
|---|-------|--------------|:---:|---|
| 4 | **Onboarding ilk-hedef splash (Faz 3)** — kuruluş sonrası "şimdi şunu yap: ilk çalışanı al" yönlendirmesi yok | İlk 60 sn kritik; yön duygusu | Küçük | `GameModel.pendingToast` + ContentView |
| 5 | **Welcome-back ekranı (Faz 6)** — offline dönüş sadece feed'de; belirgin "yokken neler oldu" kartı yok | Geri-dönüş anına anlatısal kapanış | Küçük (~30 dk) | Yeni overlay + foreground tetikleyici |
| 6 | **Defter "yeni ders" rozeti** — açılan ders feed'e düşüyor ama Defter butonunda sayaç/rozet yok | Oyuncu yeni dersi kaçırmasın | Küçük | `ControlDockView` + `newLessonIds.count` |

### P3 — İçerik/ses derinliği

| # | Eksik | Neden önemli | Tahmini iş | Dokunulacak |
|---|-------|--------------|:---:|---|
| 7 | **Müzik & SFX zenginliği** — `AudioManager` var ama içerik kapsamı gözden geçirilmeli | His/cila; sessiz oyun retention'ı düşürür | Orta | `AudioManager`, asset'ler |
| 8 | **Öğrenme döngüsü derinleştirme (Faz 5 stretch)** — "bu seçim optimal miydi?" yansıtma kartı; karar-sonrası ders köprüsü zenginleştirme | "Önce hata, sonra ders" tam kapanış | Orta | `LessonBridgeViews`, `resolve()` |

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
