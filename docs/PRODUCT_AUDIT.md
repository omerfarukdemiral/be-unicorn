# Unicorn — Uçtan Uca Ürün Denetimi (2026-05-28)

> 7 boyutta çok-ajanlı workflow denetimi + çelişkili doğrulama. Genel skor: 71/100.
> İLK 5 + birkaç hızlı kazanım bu turda KAPATILDI (aşağıda ✅). Kalanlar yol haritası.

# Unicorn — Garajdan Zirveye: Ürün Değerlendirme Sentezi

## Genel Karar

**Ürün Skoru: 71/100**

**App Store'a hazır mı? HAYIR — henüz değil.** İçerik, ekonomi ve oyun döngüsü güçlü ve gerçekten çalışıyor; ancak **submit'i bloke eden** somut eksikler var: ekran görüntüsü yokluğu (zorunlu), placeholder ikon, gizlilik manifesti yokluğu ve listede vaat edilen İngilizce ile uygulamanın TR-only olması arasındaki çelişki. Bunlar büyük ölçüde "tasarım dışı" lansman işleri (S/M efor) — ürünün kendisi sağlam, paketleme eksik. Buna ek olarak iki gerçek mekanik hata (cashPercent istismarı, denge raporunun yanıltıcı olması) lansman öncesi düzeltilmeli.

---

## Önceliklendirilmiş Boşluk Listesi

### KRİTİK / SUBMIT BLOKERİ

**1. Ekran görüntüleri + profesyonel ikon eksik — submit edilemez**
Boyut: App Store · Önem: Kritik · Efor: M
App Store Connect en az bir 6.7" ekran görüntüsü olmadan yüklemeyi reddeder; mevcut ikon dokümanın kendi ifadesiyle placeholder.
Aksiyon: Profesyonel 1024 ikon (mor/unicorn, Aurora paleti) + en az 3-5 adet 1290x2796 ekran görüntüsü üret. `--onboard-step` argümanı ve tohumlanmış save'ler çekimi kolaylaştırıyor; APPSTORE.md:151'deki anlatı çerçevelerini kullan.
(Doğrulama notu: ikon teknik olarak derlenebilir bir placeholder; gerçek blokeri ekran görüntülerinin tümüyle yokluğu. Doğrulayıcı bu yüzden severity'yi "high" indirdi ama lansman için yine zorunlu.)

---

### YÜKSEK ÖNEM

✅ **2. Tekrarlanan cashPercent kartı = nakit istismarı**
Boyut: Ekonomi · Önem: Yüksek · Efor: S
`pricing-change` kartı (DecisionContent, once:false, trigger minUsers(500)) "Paywall'ı sertleştir" ile cashPercent(0.25) veriyor; nakit tavanı ve tekrar-engeli olmadığı için büyük kasada bileşik patlama yaratıp değerleme-tabanlı gating'i kırıyor.
Aksiyon: Kartı once:true yap, VEYA cashPercent yerine MRR-ölçekli tavanlı sabit nakit ver, VEYA cashPercent etkilerine mutlak tavan (min(cash*0.25, mrr*3)) koy. Genel kural: tekrarlanabilir kartlarda pozitif cashPercent kullanma.
(Not: Doğrulayıcı "kritik→high" indirdi — istismar otomatik değil, oyuncunun her seferinde manuel seçmesi ve kartın ağırlıklı havuzdan çıkması gerekiyor. Yine de gerçek mekanik kusur; efor S olduğu için ilk yapılacaklar arasında.)

**3. BalanceSim, Balance.swift'ten saptı — denge raporu yanıltıcı (ARPU evre çarpanı simde yok)**
Boyut: Ekonomi · Önem: Yüksek · Efor: M
Gerçek oyun ARPU'ya `arpuMultiplier(forStage:)` (1.15^stage) uyguluyor ama BalanceSim uygulamıyor; üst evrelerde gerçek MRR rapordan belirgin yüksek, yani BALANCE_REPORT.md süreleri/eşikleri gerçek oyunu yansıtmıyor ve gating "çok kolay" olabilir.
Aksiyon: Sim'in ARPU hesabına `Balance.arpuMultiplier(forStage:)`'ı ekle, yeniden koş, BALANCE_REPORT.md'yi güncelle, gating eşiklerini gözden geçir (muhtemelen yukarı).

✅ **4. Erken oyunda karar havuzu boşalıyor — dead air riski**
Boyut: Çekirdek Döngü · Önem: Yüksek · Efor: M
Stage 0/users=0'da yalnızca 3 kart eligible ve üçü de once:true; tükendikten sonra oyuncu users≥50'ye ulaşana dek hiç karar kartı gelmiyor, fallback yok — ilk 3-5 dakikada akış kopabilir.
Aksiyon: Stage 0 / düşük-kullanıcı için 6-10 adet tekrarlanabilir (once:false) erken-oyun kartı ekle; ayrıca havuz boşaldığında jenerik "mentor ipucu" fallback kartı ver.

**5. Hiç yerel bildirim/hatırlatma yok — geri-gelme kancası uygulama dışına uzanamıyor**
Boyut: Retention · Önem: Yüksek · Efor: M
Streak/günlük hedef "geri-dönüş kancası" olarak belgelenmiş ama UNUserNotificationCenter hiç kullanılmıyor; D1/D7 dönüşü tamamen oyuncunun kendiliğinden açmasına bağlı.
Aksiyon: UserNotifications ekle — (1) gün sonuna yakın streak-risk hatırlatması, (2) D1 inaktivite dönüş bildirimi. İzni onboarding sonrasına koy; `saveOnBackground`'da planla, `refreshOnForeground`'da iptal/yeniden planla.

**6. Gecikmeli/zincirleme karar etkileri (B maddesi) sadece metinde — mekanik motor yok**
Boyut: Felsefe · Önem: Yüksek · Efor: L
DESIGN_PRINCIPLES.md "pendingDecisionEffect listesi ekle" diyor; "2 çeyrek sonra burn patlar" gibi nedensellik yalnızca `result` metninde anlatılıyor, oyunda gerçekleşmiyor — "gerçek zincirleme sonuç" ilkesi kağıt üstünde kalıyor.
Aksiyon: GameState'e zaman-damgalı `pendingEffects: [(applyAtMonth, [DecisionEffect])]` ekle; tick'te vadesi gelenleri uygula + "X kararının gecikmeli sonucu geldi" toast'ı göster. Birkaç yüksek-etkili kartta pilot uygula.
(Not: Efor L olduğu için lansman-blokeri değil; lansman sonrası ilk büyük içerik güncellemesi için ideal.)

✅ **7. Şema versiyonlama yok — gelecekteki şema değişikliğinde sessiz veri kaybı**
Boyut: Sağlamlık · Önem: Yüksek · Efor: M
SaveManager.load() decode'u `try?` ile yutuyor ve hata yutulunca taze GameState'e düşüyor; yapısal bir şema değişikliği decode'u throw ederse oyuncunun tüm ilerlemesi sessizce silinir.
Aksiyon: GameState'e `schemaVersion: Int = 1` ekle + sürüm tabanlı migration zinciri kur; en azından decode başarısızlığında save.json'ı silmeden `.bak` olarak yedekle.

---

### ORTA ÖNEM

✅ **8. PrivacyInfo.xcprivacy gizlilik manifesti yok**
Boyut: App Store · Önem: Orta (doğrulayıcı high→medium) · Efor: S
UserDefaults (AudioManager) required-reason API kapsamında; manifest olmadan App Store Connect yükleme uyarısı/reddi gelebilir.
Aksiyon: PrivacyInfo.xcprivacy ekle: NSPrivacyTracking=false, NSPrivacyCollectedDataTypes=[], UserDefaults için CA92.1 beyan et. (Doğrulayıcı notu: C617.1/file-timestamp gerekmez — kod dosya zaman damgası okumuyor.)

**9. Uygulama TR-only ama listede İngilizce dil vaat ediliyor**
Boyut: App Store · Önem: Orta (high→medium) · Efor: M
Hiç lokalizasyon altyapısı yok; APPSTORE.md EN dili beyan edip tam EN metin içeriyor — EN kullanıcı için kırık deneyim + tutarsızlık riski.
Aksiyon: MVP için en gerçekçi yol: lansmanı TR-only yap, APPSTORE.md'den İngilizce dil beyanını ve EN metinleri "sonraki sürüm" notuna taşı. (72 kart + 20 ders çevrilmeden gerçek EN deneyimi olmaz.)

✅ **10. headcount/moduleLevels Codable migration tuzağı**
Boyut: Sağlamlık · Önem: Orta (high→medium) · Efor: S
Bu iki alan bildirimde varsayılan taşımadığı için JSON'da eksik kalırsa decode throw eder → tüm save reddedilir (sessiz fresh start), normalize() devreye giremez.
Aksiyon: Bildirime varsayılan ata: `var headcount: [Int] = Array(repeating: 0, count: Balance.departmentCount)` ve `moduleLevels` için benzeri.

✅ **11. Streak çift-sayım bug'ı**
Boyut: Retention · Önem: Orta (high→medium) · Efor: S
checkDailyCompletion'da `streak += 1` hem tamamlamada hem rollover'da sayıyor; iki ardışık aktif günden sonra streak 2 yerine 3 görünüyor (moral/lig skoru hafif şişer).
Aksiyon: Tek-sahiplik kuralı uygula — checkDailyCompletion'daki `streak += 1`'i kaldır, artışı yalnızca refreshDailyGoalIfNeeded'deki rolledStreak yönetsin.

✅ **12. Sürüm numarası hâlâ 0.1 / build 1**
Boyut: App Store · Önem: Orta · Efor: S
0.1 sürümü "beta/yarım" algısı yaratır ve kullanıcıya görünür.
Aksiyon: Lansman archive'ından önce MARKETING_VERSION'ı 1.0'a çek.

**13. Sıfır Dynamic Type / erişilebilirlik ölçekleme**
Boyut: UI/UX · Önem: Orta (high→medium) · Efor: L
Tüm tipografi sabit puntolu (8-10pt yer yer); kullanıcı sistem yazı boyutuna tepki vermiyor, 8pt App Store erişilebilirlik beklentisinin altında.
Aksiyon: Gövde/etiket fontlarını `Font.custom(_, size:, relativeTo:)` ile text style'a bağla; minimum ≥11pt taban belirle; 8pt badge/ItemTile metinlerini gözden geçir. (Efor L — lansman sonrası iyileştirme.)

**14. Destek URL'si + web gizlilik politikası sayfası yok**
Boyut: App Store · Önem: Orta · Efor: S
Support URL App Store Connect'te zorunlu alan; birçok kategoride privacy policy URL'si de istenir.
Aksiyon: Basit destek sayfası (omer@tipbox.co) + "veri toplanmıyor" beyanlı kısa gizlilik politikası sayfası yayınla, URL'leri gir.

**15. Tempolama çok hızlı — döngüler üst üste biniyor**
Boyut: Çekirdek Döngü · Önem: Orta · Efor: M
1× hızda ~30sn sprint, ~84sn senaryo, ~3dk çeyrek, 18-30sn karar aynı pencereye düşüp modal kuyruğu yaratıyor; "akış" bölünüyor.
Aksiyon: Sprint'i 0.5→0.75-1.0 aya çıkar veya başarılı sprint kapanışını sessiz toast'a indir; spawn aralıklarını faz-kaydırarak çakışmayı azalt.

**16. Geç oyunda evre başına kart çeşitliliği daralıyor**
Boyut: Çekirdek Döngü / İçerik · Önem: Orta · Efor: M
minStage(4)+ için yalnızca 2 kart var; Series B-C-Unicorn evrelerinde tekrar hissi belirginleşiyor.
Aksiyon: minStage(4)+ için 6-8 ileri-evre kartı ekle (IPO, ikincil pazar, antitröst, halka arz vs özel kalma); tekrarlı kartlara hafif metin varyasyonu ekle.

**17. ARPU'da salesPower / LTV'de churn tabanı sınırsız**
Boyut: Ekonomi · Önem: Orta · Efor: M
salesPower üst sınırsız (sim'de ARPU çarpanı ~5.9x'e çıkıyor), churn %1 tabanına inebiliyor → geç-oyunda "satışçı yığ" baskın mikro-strateji olabilir.
Aksiyon: salesPower katkısına doygunluk (tanh/tavan) ve LTV'ye makul tavan uygula; sim'i yeniden koşup zirve LTV:CAC'i <~10-15 bandına indir.

**18. BalanceSim'de birden çok sabit Balance.swift ile uyumsuz**
Boyut: Ekonomi · Önem: Orta · Efor: M
cacStageScaling, decisionMin/Max, moraleAdjustRate, modül costGrowth değerleri sim ≠ Balance; rapor güvenilirliğini düşürüyor.
Aksiyon: Sim sabitlerini Balance.swift ile birebir senkronla (ideali ortak kaynağı SwiftPM target'ına dahil etmek); CI/checklist'e "sim==Balance" doğrulaması ekle.

**19. Defter derslerinin mekanik-bağlı tooltip katmanı (D maddesi) yok**
Boyut: Felsefe · Önem: Orta · Efor: M
`mechanic` alanı tanımlı ama HUD/karar kartından ders açan kod yok; "her mekaniğin yanında ℹ → ilgili ders" akışı uygulanmamış.
Aksiyon: HUD metrik rozetlerine ve karar kartına küçük "ℹ" ekle; tıklanınca ilgili `mechanic` etiketli LessonEntry'yi aç.

**20. Geç-oyun içerik tekrarı (App Store retention)**
Boyut: App Store / İçerik · Önem: Orta · Efor: M
once kartlar tükenince ~48 tekrarlı kart monotonlaşıyor (PLAYTEST P2-4).
Aksiyon: Evre-bazlı kart kotaları + stage 3-4'e özel nadir stratejik kartlar; quick win olarak 1-2 geç-oyun modülü ekle. (#16 ile birleştirilebilir.)

**21. Ölü kod: FloatingNav/SideRail + occupant koltuk sistemi + EmployeeCardView erişilemez**
Boyut: UI/UX + Sağlamlık · Önem: Orta · Efor: S-M
SideRail/sideMenuTrailing hiç referanslanmıyor; FloorPlan occupant avatar sistemi (assignMembersToSeats) hiç çağrılmıyor; inspectedDept hiçbir yerde set edilmediği için EmployeeCardView dalı erişilemez (+ count(_:) sınır kontrolsüz, latent crash).
Aksiyon: Kullanılmayanları sil VEYA occupant sistemini canlandır (kroki "oyun hissi" kazanır). count(_:)/departments[i] erişimlerine `guard indices.contains` ekle.

**22. Panel kenar boşluğu çift-padding tutarsızlığı + HUD a11y etiket eksiği**
Boyut: UI/UX · Önem: Orta · Efor: S
Ofis ekranı kenarları diğer panellerle hizasız (sekme değişiminde içerik zıplıyor); pause/play ve hız butonlarında accessibilityLabel yok.
Aksiyon: Tek yatay padding otoritesi belirle (dış s3 veya iç s4, ikisi değil); timeButton'lara dinamik a11y etiketi ekle.

---

### DÜŞÜK ÖNEM

**23. detailRow +/− tespiti metin-tabanlı ve kırılgan**
Boyut: Çekirdek Döngü · Efor: S — Etki ön-izleme oklarını serbest metin yerine `choice.effects` dizisinden programatik üret.

**24. Karar tetikleyici yalnızca oyun-zamanına bağlı — yüksek hızda kart yağmuru**
Boyut: Çekirdek Döngü · Efor: S — Karar aralığına gerçek-zaman alt sınırı (≥12sn) koy.

**25. Streak koruması/freeze yok**
Boyut: Retention · Efor: M — Basit streak-freeze jetonu ekle (tek gün kaçırınca seri sıfırlanmasın); ekonomiye dokunmaz.

**26. Karar `result` satırı yalnızca geçici toast**
Boyut: Felsefe · Efor: M — En zengin eğitici içerik 3.5sn toast'ta kayboluyor; kalıcı/kapatılabilir küçük sonuç kartına taşı.

✅ **27. İlk seçenek görsel olarak vurgulanıyor ("bold")**
Boyut: Felsefe · Efor: S — `idx==0` bold vurgusu "tek doğru cevap yok" ilkesine aykırı önyargı yaratıyor; eşit ağırlık ver veya nötr etiketle.

**28. Para birimi: $ tabanlı ekonomi, TL'de sembol değişiyor ama tutar dönüşmüyor**
Boyut: Ekonomi · Efor: S — Ya saf $ tut ve dokümante et, ya da currency başına gösterim çarpanı uygula.

**29. GoalsStrip view'ı tanımlı ama render edilmiyor (yinelenen)**
Boyut: Retention/UI · Efor: S — Tek kaynak yap: GoalsStrip'i sil veya OfficePanel kopyasını GoalsStrip çağrısıyla değiştir.

**30. SegmentSwitcher kodu iki panelde kopyalanmış**
Boyut: UI/UX · Efor: S — Ortak `SegmentSwitcher<T>` bileşeni çıkar (DRY).

**31. Kompakt punto + textTertiary kontrast riski**
Boyut: UI/UX · Efor: S — Pasif tab/etiket metinlerinde puntoyu (≥11) veya opaklığı (textSecondary 0.78) artır.

**32. Autosave throttle gerçek-zamana bağlı + tick'te tekrarlı hesaplama**
Boyut: Sağlamlık · Efor: S-M — Autosave eşiğini oyun-ilerlemesine bağla; effects/health evaluate'i tick başında bir kez hesapla/cache'le. (Düşük öncelik — mevcut davranış çoğu durumda yeterli.)

---

## Hemen Yapılacak İlk 5 (En Yüksek ROI)

1. **cashPercent istismarını kapat** (#2, S) — Tek satırlık `once:true` veya tavan; ekonomi-kıran bir kusuru anında giderir.
2. **headcount/moduleLevels varsayılan + schemaVersion** (#10 + #7, S/M) — İki satırlık varsayılan ataması sessiz veri kaybı riskini büyük ölçüde kapatır; oyuncu ilerlemesini korur.
3. **Streak çift-sayım fix'i** (#11, S) — Tek satır kaldırma; retention metriklerinin doğru kalibre olması için kritik.
4. **Erken oyun karar kartları + fallback** (#4, M) — İlk 5 dakikadaki "dead air"i kapatmak D1 retention için en yüksek getirili oyun değişikliği.
5. **Submit paketi: ekran görüntüleri + ikon + PrivacyInfo + sürüm 1.0 + TR-only listeleme** (#1, #8, #9, #12, M toplam) — Bunlar olmadan App Store'a yükleme fiziksel olarak mümkün değil; çoğu tasarım dışı, hızlı kapatılabilir lansman işi.

---

## Boyut Skorları Özeti

| Boyut | Skor | Durum |
|---|---|---|
| Felsefe / eğitici derinlik | 80 | En güçlü; B+D maddeleri kısmi |
| UI/UX & oyun hissi | 76 | Tutarlı dil; a11y + ölü kod cilayı düşürüyor |
| Çekirdek döngü & karar | 72 | İçerik güçlü; erken dead-air + tempo |
| Retention zinciri | 72 | Tam bağlı; bildirim yok + streak bug |
| Sağlamlık & kod kalitesi | 74 | Savunmacı; migration tuzakları |
| Ekonomi & denge | 62 | En zayıf; sim sapması + cashPercent |
| App Store hazırlığı | 68 | İçerik hazır; görsel/yasal paket eksik |

**Sentez:** Bu, içerik ve sistem tasarımı App Store kalitesinin üzerinde, ancak **paketleme ve birkaç mekanik düzeltme** nedeniyle henüz submit-ready olmayan bir üründür. İlk 5 madde (çoğu S/M efor) tamamlandığında hem mekanik bütünlük hem de submit edilebilirlik sağlanır; L-efor maddeler (gecikmeli etki motoru, Dynamic Type) lansman sonrası ilk güncelleme için ideal adaylardır.

— Yanlış alarm notu: Sağlanan veride confirmed=false veya adjustedSeverity='invalid' işaretli boşluk bulunmadı; tüm doğrulanan boşluklar gerçek çıktı (bazıları severity olarak indirildi, yukarıda not edildi).