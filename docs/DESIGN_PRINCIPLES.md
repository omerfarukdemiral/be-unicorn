# Unicorn — Tasarım Prensipleri (Çekirdek DNA)

## Çekirdek Hissiyat
Oyuncuya verilmesi gereken duygu **"Ben daha akıllıyım, ben yaparım"**: agency, meydan okuma, kendi stratejisini kanıtlama arzusu. Başarısızlıkta **"slip atayım"** değil, **"neyi yanlış yaptım, sonra ne deneyeceğim"** psikolojisi.

## Üç Yasak
1. **Tek doğru cevap yok.** Hiçbir kararın "açıkça en iyi" seçeneği olamaz. İki seçenek de farklı durumda DOĞRU olabilir.
2. **Basit formül yok.** "+50 moral / +%5 üretim" gibi yüzeysel deltalar değil; gerçek hayat zincirleme/gecikmeli sonuçlar (bu çeyrek hire → 2 çeyrek sonra burn patlar → moral kırılır).
3. **Rastgele ceza yok.** İflas/kriz adil olmalı — oyuncu nedenini görmeli, "şanssızdı" diyemesin.

## Üç İlke
1. **Gerçek-hayat öğretici.** Her mekanik bir startup gerçeğini öğretir (default-alive, LTV:CAC, churn'ün sessiz katil olması, equity dilution, "premature scaling"...). Oyun, anekdot ve veri zenginliğiyle dolu.
2. **Çoklu geçerli strateji.** Aşağıdaki arketipler en az birer tane meşru ve kazanan oluşmalı:
   - **Bootstrap-Frugal** — yatırım yok / az, yüksek marj, yavaş ama bağımsız büyüme.
   - **VC-Roket** — agresif tur, büyük burn, "growth at all costs", hızlı pivot.
   - **Niş Uzman** — tek segment, yüksek ARPU, düşük churn, derin ürün.
   - **Platform Geniş** — çoklu ürün/segment, düşük ARPU, ölçek + ağ etkisi.
   Hiçbiri diğerine kesin baskın olmamalı; oyuncu farklı denemelerde farklı kazansın.
3. **Post-mortem coaching.** Her büyük kapanışta (iflas, çeyrek kötü skor, win, sezon) oyuncu **ne yanlış / ne doğru gitti**'yi somut görür. Diagnostic, suçlayıcı değil — strateji notu.

## Uygulanabilir Backlog (öncelik sırası)

- [ ] **A. İflas Post-Mortem ekranı.** Mevcut basit BankruptcyView yerine **"Burada Ne Oldu?"** scorecard'ı: son N çeyreğin grafiği (cash/runway/morale/users), kritik kararlar (en kötü/en iyi 2-3), zincirleme nedensellik ("Ay 18'de 3 işe alım burn'i %40 artırdı; runway 6 → 2 aya düştü; moral kriz kartında reddedilince istifa zinciri başladı") + "Sonraki Deneme İçin Strateji" (somut 3 öneri). Coaching dili, suçlama yok.

- [ ] **B. Karar kartları — derinlik turu.** Mevcut ~58 kartı denetle + yeniden yaz:
   - Her kartta **iki seçenek de "duruma göre" geçerli olabilsin** (state-dependent best choice).
   - **Gecikmeli sonuçlar**: anında küçük etki + 1-2 çeyrek sonra büyük etki (state'e bir `pendingDecisionEffect` listesi ekle).
   - **Edu satırı**: kartın arkasındaki gerçek startup ilkesi (1 cümle, opsiyonel "ℹ daha fazla" tap → kısa kutu).
   - Kategori çeşitliliği zaten iyi; nuans + zincirleme katmak şart.

- [ ] **C. Strateji arketip dengesi.** BalanceSim'e 4 farklı oyuncu politikası (yukarıdaki arketipler) ekle; her birinin Garaj→Unicorn'da kazanabildiğini DOĞRULA (süre/yol farklı, hedef aynı). Dengesiz arketip varsa parametre kalibre et. Rapor: `docs/BALANCE_REPORT.md`.

- [ ] **D. Eğitici "Defter" + tooltip katmanı.** Her büyük mekaniğin (runway, CAC/LTV, churn, equity, burn, ürün-pazar uyumu, kapasite/seat, prestij/sezon) yanında küçük "ℹ" ikonu → kısa **gerçek-startup ilkesi** kutusu (Türkçe, 2-3 cümle). Toplanan ilkeler ayrı bir "Defter" sekmesinde / overlay'de oyuncu için arşivlenir. Erteleme: edu içerik içeriği büyük; düzen iskeletini önce kur, içeriği iteratif doldur.

- [ ] **E. Krizlerin gerçekçi sıklığı + zincirleme.** Crisis kartları/olayları SUI-jenerik değil, durum-tetikli (state'e bağlı). Aynı kötü gidişat sürerse zincirleme kriz (ör. moral düşükse istifa → yeni proje bekler → revenue düşer → yatırımcı sertleşir). State machine net: "Sağlıklı → Sıkıntılı → Kriz → Toparlanma" geçişleri görünür.

- [ ] **F. Çeyrek post-mortem detayı.** CycleReview zaten skor/sıralama gösteriyor; "Bu çeyrekte iyi/kötü yaptığın 1-2 şey" yorumunu ekle (basit kural-tabanlı: en büyük delta'lar üzerinden). Yarı-coaching, yarı kutlama.

- [ ] **G. "Tek yolu yok" sertifikası.** Karar kartları + büyüme stratejileri için **tıklamasız da kazanma yolu** sağlayan içerik audit. Ör. reklam bütçesi olmadan da büyüyebilen organik patika (yüksek itibar + pazarlama dept'i + viral). Her ana parametre için en az 2 farklı dengesi olan kazanma yolu olmalı.

- [ ] **H. Onboarding'e felsefe damlası.** İlk akışta tek bir cümleyle: "Bu oyunda tek doğru yol yoktur. Başarısızlık öğrenmektir." Kullanıcıya çerçeve ver. Mevcut 7 adıma tek satır eklenebilir.

## Test/Doğrulama Kuralı
- Her yeni karar kartı/mekanik için: "İki seçeneği de SAVUNULABİLİR olarak yazabiliyor muyum?" — değilse yeniden yaz.
- Her büyük başarısızlık (iflas/düşük skor): "Oyuncu post-mortem'i okuduğunda bir sonraki stratejisi belli oluyor mu?" — değilse coaching satırını güçlendir.
- BalanceSim 4 arketip için: "Hepsi Unicorn'a varabiliyor mu?" — değilse parametre + içerik ayarı.
