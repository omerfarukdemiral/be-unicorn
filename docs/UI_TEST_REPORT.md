# UI Test Raporu — 2026-05-28

Oturum boyunca seed+screenshot ile görsel doğrulanan akışlar + #7 test turu bulguları.

## Doğrulanan akışlar
- ✅ **Onboarding** — 3 adım. **BUG bulundu+düzeltildi:** 1. adım hero ikonu görünmüyordu; sebep `Icons.Screen.onboard0 = "rocket.fill"` (SF Symbols'da roket YOK → boş render). `chart.line.uptrend.xyaxis` ile değiştirildi, artık görünüyor (`/tmp/u_onboard_fixed.png`).
- ✅ **Ofis / Kroki (yeni yerleşim)** — kroki hero, kompakt Hedefler şeridi (Sprint+Günlük), hız pill'i başlıkta, Mağaza. Temiz, taşma yok (`/tmp/unishots/04_office.png`).
- ✅ **Ekip** — koltuk kapasitesi kısıtı (masa yoksa işe alım engelli).
- ✅ **Mağaza / eşya** — kategori-renkli kroki dolması, m²/koltuk.
- ✅ **Büyüme** — reklam bütçesi + CAC/LTV/payback/oran.
- ✅ **İstatistik** — gider dağılımı çubukları + para birimi seçici (TL/€/$).
- ✅ **Çeyrek kapanışı + lig** — CycleReview scorecard + skor halkası; terfi/düşüş.
- ✅ **Kohort/leaderboard** — 9'luk sıralama, sıralamaya bağlı terfi (1.)/düşüş (9.).
- ✅ **Günlük hedef kapanışı** — 3 görev + streak + kutlama.
- ✅ **Haftalık sprint** — başarılı (103/100) + başarısız (%3/%80) kapanış.
- ✅ **Sezon finali** — ünvan/rozet + kalıcı çarpan + koleksiyon kartı.
- ✅ **Funding turu** — kutlama parıltısı.
- ✅ **İflasa-yakın** — negatif nakit (kırmızı), runway ⚠️ 0 ay, moral kırmızı, istifa bildirimi.
- ✅ **Üst-sağ toast bildirimi** — tıklanabilir çip, yukarıdan yaylı doğma.

## Genel UI sağlığı
Ana oyun UI'ı temiz ve tutarlı (HUD hiyerarşisi, SF Symbol ikonlar, Palette/Typography, tema). Tüm metrik/ikon/font render'ları sağlıklı; emoji kalıntısı yok.

## Not
#7 test ajanı watchdog zaman aşımıyla yarıda kaldı; kalan derin testi (win overlay'i canlı tetikleme vb.) ana ajan tamamladı/spot-check etti. Bulunan tek net görsel hata (onboarding ikonu) düzeltildi; build BUILD SUCCEEDED.

## Kalan öneriler (kritik değil)
- Win (Unicorn) overlay'i canlı raiseRound ile uçtan uca bir kez daha görülebilir.
- Bilgi yoğunluğu için onboarding'e (çeyrek/lig/günlük/sprint) kademeli ipuçları eklenebilir.
