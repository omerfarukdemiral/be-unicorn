# Unicorn: Garajdan Zirveye — UI Tasarım Spec'i

> Hedef: **sade + estetik + "uygulama değil oyun" hissi.** Apple HIG ile uyumlu ama karakterli.
> Bu doküman SwiftUI'ya birebir çevrilebilir token ve komponent spec'leri içerir. Web kodu yoktur.

## 0. Tasarım yönü (kısa manifesto)

Oyunun en güçlü görsel varlığı **izometrik ofis sahnesi** (iso4/iso6). Tüm arayüz bu sahneye "çerçeve" olmalı, onunla yarışmamalı. Yön:

- **Karanlık, derin, sinematik bir taban** + **tek güçlü accent** (evre rengi). Renkler "timid/eşit dağılım" değil; dominant koyu yüzey + keskin accent.
- **Sayılar kahraman, etiketler fısıltı.** Space Grotesk büyük sayılarda parlasın; Inter küçük etiketlerde geri çekilsin.
- **Cam değil, derinlik.** `ultraThinMaterial` yalnız yüzen katmanlarda (tab bar, balon, toast). Paneller opak yüzey + ince hairline + yumuşak gölge.
- **Evre büyüdükçe "güzelleşme":** köşe yumuşar, gölge derinleşir, kenarlık ışıldar, accent doygunlaşır — ama hiçbir zaman dağınıklaşmaz.

Mevcut en büyük 3 problem (detay §7):
1. HUD aşırı yoğun — 4 katman (başlık+nakit / değerleme / 3 pill / 2 bar) tek nefeste geliyor, hiyerarşi yok.
2. Yüzey sistemi "düz" — tüm kartlar aynı `surface` + `opacity(0.05)` tonunda; katman/derinlik okunmuyor, evre büyümesi hissedilmiyor.
3. Renk token'ları dağınık — `Color(hex: "4FD1A1")` gibi sihirli hex'ler 8+ dosyada tekrar ediyor; başarı/uyarı/tehlike merkezi değil.

---

## 1. Renk Sistemi

### 1.1 Mimari: 3 katman + semantik + nötr

Mevcut `Theme` yalnız `bg / surface / accent` taşıyor. Bunu **yüzey kademeleri** ve **merkezi semantik palet** ile genişlet. Öneri: yeni bir `Palette` enum/struct'ı (sabitler) + `Theme`'e türetilmiş alanlar.

#### Nötr / yüzey katmanları (evreden bağımsız sabit taban — `bg`/`surface` hex'ler `model`'den gelmeye devam eder, aşağıdakiler onların ÜSTÜNE bindirilir)

| Token | Tanım | Değer | Kullanım |
|---|---|---|---|
| `bg` | En arka plan | model.stageBgHex | Kök ZStack |
| `surfaceLow` | Panel zemini | model.stageSurfaceHex | PanelCard arka planı |
| `surfaceHigh` | Panel içi yükseltilmiş hücre | `bg` üstüne `white .06` | İç pill, metric hücresi, bar track |
| `surfaceFloat` | Yüzen katman | `.ultraThinMaterial` | Tab bar, founder balonu, toast |
| `hairline` | Kenarlık | `white .08 + stage*0.012` | Tüm kart stroke |
| `hairlineStrong` | Vurgulu kenarlık | `accent .35` | Seçili/aktif kart |

#### Semantik (evreden bağımsız sabit — TÜM dosyalarda tek kaynak)

| Token | Hex | Anlam |
|---|---|---|
| `success` | `#3FCF8E` | Pozitif delta, sağlıklı oran, karlı runway, tamamlanan evre |
| `successDim` | `#2BA876` | success'in koyu/dolgu varyantı (bar dolgusu altı) |
| `warning` | `#F5C451` | Kırılgan, dikkat, orta moral |
| `danger` | `#F0584F` | Negatif nakit, düşük runway, iflas, çıkar butonu |
| `dangerDim` | `#C2443C` | danger basılı/dolgu |
| `gold` | `#FFD479` | Kutlama, XP, prestij vurgusu (funding/win) |

> Mevcut `4FD1A1 / FFD166 / E0574F` üçlüsünü yukarıdaki `success/warning/danger` ile **değiştir** (biraz daha doygun ve tutarlı). Tek yerde tanımla, her dosya oradan okusun.

#### Metin opaklık kademeleri (beyaz üstüne)

| Token | Opaklık | Kullanım |
|---|---|---|
| `textPrimary` | `1.0` | Kahraman sayılar, başlıklar |
| `textSecondary` | `0.78` | Gövde metni, balon içeriği |
| `textTertiary` | `0.52` | Etiketler ("kullanıcı", "MRR") |
| `textQuaternary` | `0.32` | Devre dışı, kilitli, placeholder |

> Mevcut `subtle = 0.55` → `textTertiary = 0.52`'ye sabitlensin. Etiket fısıltısı için yeterli kontrast + sade.

### 1.2 Evre-bazlı accent paleti (rafine)

`model.stageAccentHex` değerleri korunur ama **evre büyüdükçe accent doygunlaşmalı ve hafif parlamalı.** Ekran görüntülerinde: Garaj turuncu, Series A/B mor, Series C+ teal yönüne gidiyor — bu iyi bir "olgunlaşma" hikayesi. Öneri renk çizgisi (mevcut hex'leri bu yöne çekmek için referans):

| Evre | Accent (hedef) | His |
|---|---|---|
| Garaj / Pre-seed | `#E8924A` (sıcak turuncu) | ham, enerjik, "garaj" |
| Seed | `#E0C24A` → `#9B8CF0` geçiş | filizlenme |
| Series A/B | `#8B7BF5` (mor) | momentum, hype |
| Series C | `#3FC9C2` (teal) | olgun, kurumsal-cool |
| Unicorn | `#FF6FB5` (pembe) | zafer, prestij |

### 1.3 "Evre büyüdükçe güzelleşme" derinleşmesi

| Sinyal | Garaj (stage 0) | Unicorn (stage ~5) |
|---|---|---|
| Köşe yarıçapı | 16 | 22 (bkz §3) |
| Gölge | yok/çok hafif | belirgin yumuşak gölge |
| Kart kenarlık opaklığı | `.08` | `.14` (hafif ışıltı) |
| Accent doygunluğu | ham | parlak/derin |
| Panel iç vurgu çizgisi | yok | kart üstünde 1px accent-glow gradient (opsiyonel P2) |

---

## 2. Tipografi Ölçeği

Fontlar doğru: **Space Grotesk = `appNumber`** (sayı/vurgu), **Inter = `appText`** (metin/etiket). Sorun: ölçek serbest dağılmış (8, 9, 10, 11, 12, 13... her dosyada farklı). Aşağıdaki **sabit ölçek** kullanılsın — `Font` extension'ına named helper'lar eklenmeli.

| Rol | Font | Punto | Weight | Kullanım |
|---|---|---|---|---|
| `displayXL` | appNumber | 34 | .black | Win ekranı "UNICORN" |
| `displayL` | appNumber | 26 | .heavy | HUD nakit (kahraman) |
| `displayM` | appNumber | 22 | .heavy | Reklam bütçesi, büyük metrik |
| `numberL` | appNumber | 17 | .heavy | Metric kart değeri |
| `numberM` | appNumber | 14 | .bold | İkincil sayı (yatırım satırı) |
| `numberS` | appNumber | 12 | .bold | Pill değeri, buton bedeli |
| `numberXS` | appNumber | 10 | .bold | Bar yüzdesi, "Lv 2/5" |
| `titleL` | appText | 24 | .black | Overlay başlık (funding/onboard) |
| `titleM` | appText | 18 | .heavy | Panel başlığı ("Ekip", "Büyüme") |
| `bodyL` | appText | 15 | .semibold | Karar prompt, buton ana metni |
| `body` | appText | 13 | .medium | Açıklama, founder balonu |
| `label` | appText | 11 | .medium | Etiket ("kullanıcı", "MRR") |
| `caption` | appText | 9 | .bold | Üst etiket ("DEĞERLEME"), "ŞİMDİ" rozeti |
| `eyebrow` | appText | 11 | .black | Üst başlık caps ("GARAJ", "TEKNOLOJI BLOGU") |

**Kurallar:**
- Eyebrow/caps başlıklar (`GARAJ`, kategori adı) `tracking ~0.08em` (`.kerning(1.0)`) ile nefes alsın.
- `numericText()` transition'ı sayılarda tutarlı kullanılsın (HUD nakit ✓, reklam bütçesi ✓ — kullanıcı/MRR/değerlemeye de ekle).
- 8pt etiket (HUD `statSF` "kullanıcı") çok küçük → 9pt `caption`'a yükselt; gerekirse pill etiketi tek satırda kalsın diye `minimumScaleFactor` yerine kısalt.

---

## 3. Boşluk / Köşe / Elevation Token'ları

### 3.1 Spacing skalası (4pt tabanlı)

| Token | px | Kullanım |
|---|---|---|
| `space1` | 4 | İkon-metin arası, satır içi mikro |
| `space2` | 8 | Pill içi, eleman arası dar |
| `space3` | 12 | Kart iç padding dikey, kartlar arası standart |
| `space4` | 16 | Kart iç padding, ekran kenar |
| `space5` | 22 | Overlay iç padding |
| `space6` | 28 | Overlay hero boşluk |

> Mevcut padding'ler (14, 10, 6, 18, 26...) bu skalaya yuvarlanmalı. Ekran kenar boşluğu **her panelde tutarlı `space4 = 16`** olsun (şu an 14). Kartlar arası `space3 = 12` (zaten çoğunda 12 ✓).

### 3.2 Köşe yarıçapı (evre-duyarlı)

| Token | Değer | Kullanım |
|---|---|---|
| `radiusS` | 10 | İç pill, küçük buton, bar track |
| `radiusM` | 14 | Standart buton, balon |
| `radiusCard` | `16 + stage*1.2` (clamp 16…22) | PanelCard (mevcut `18 + stage*1.5` biraz hızlı büyüyor → yumuşat) |
| `radiusOverlay` | 24 | Karar kartı, funding kartı |
| `radiusPill` | `Capsule` | Stat çubukları, rozetler |

### 3.3 Elevation kademeleri

| Seviye | Gölge | Kullanım |
|---|---|---|
| `elev0` | yok | İç hücreler, bar track |
| `elev1` | `black .20, r: 8 + stage*1.5, y: 3` | PanelCard (mevcut `stage*2` → biraz yumuşat + taban ver) |
| `elev2` | `black .35, r: 20, y: 8` | Overlay kartları |
| `accentGlow` | `accent .45, r: 12, y: 4` | Birincil CTA (raise/funding butonu ✓ zaten var) |

> Garajda (stage 0) bile **hafif taban gölge** (`r:8`) olsun — şu an stage 0'da gölge tamamen 0, kartlar bg'ye yapışık duruyor. Minik bir y-offset derinlik hissini hemen yükseltir.

---

## 4. Komponent Spec'leri

> Her biri **Şu an / Sorun / Önerilen** formatında.

### 4.1 HUD (en kritik)

**Şu an:** Tek `VStack` içinde: (eyebrow + nakit) | (değerleme + hisse) yan yana, altında 3 pill, altında moral barı, altında raise barı. 5 ayrı bilgi katmanı dikey üst üste.

**Sorun:** Görsel gürültü; göz nereye bakacağını bilmiyor. Nakit (kahraman) ile değerleme aynı ağırlıkta algılanıyor. İki ince bar (moral + raise) birbirine karışıyor, etiketleri (Moral / Pre-seed) farklı font ailesinde. Pill etiketleri 8pt — okunmuyor.

**Önerilen:**
- **Hiyerarşi:** Nakit tek başına kahraman (`displayL`). Değerleme + hisse sağda küçük, gruplanmış (`numberM` + `caption`). Eyebrow (`GARAJ`) accent + `eyebrow` stili, nakit'in hemen üstünde mikro etiket gibi.
- **3 pill:** `surfaceHigh` zeminde, ikon `accent` (tehlike/karlı durumda semantik renk), değer `numberS`, etiket `caption` (9pt). İkon + değer **tek satır, ortalı**; etiket altta. Pill'ler arası `space2`.
- **Runway pill'i durum rengini taşısın** (zaten var ✓): <2 ay → `danger` + uyarı ikonu; karlı → `success` + `infinity`.
- **İki barı birleştir/sadeleştir:** Moral ve "sıradaki tur" barlarını **tek satır, iki ince segment** halinde ya da raise barını ofis ekranındaki CTA'ya taşıyıp HUD'dan kaldır. Minimum: ikisinin de etiketi aynı `label` (Inter) stili olsun, sol etiket sabit genişlikte hizalı, sağ değer monospace hizalı.
- **Negatif nakit:** `danger` rengi + çok hafif kırmızı arka plan flash (bkz §6) — şu an sadece renk değişiyor, fark edilmiyor.
- **Üst safe-area:** HUD notch'a fazla yakın; `space2` üst nefes ekle.

### 4.2 PanelCard

**Şu an:** `padding(14)` + `surface` + `cardCorner` + `white.opacity(0.06+stage*0.01)` stroke + `black.25` gölge (stage*2 radius).

**Sorun:** Tek yüzey tonu — iç hücreler (`white .05`) ile kart yüzeyi neredeyse aynı; katman okunmuyor. Stage 0'da gölge yok → düz. Stroke çok soluk.

**Önerilen:**
- `padding(space4=16)`, `radiusCard` (clamp'li), `surfaceLow` zemin, `hairline` stroke (biraz daha görünür), `elev1` (taban gölge dahil).
- **İç hücreler `surfaceHigh`** (kart yüzeyinden bir ton açık) → katman netleşir.
- Aktif/seçili kart varyantı: `hairlineStrong` (accent .35) + hafif accent glow.

### 4.3 Butonlar (birincil / ikincil / tehlike)

**Şu an:** Her yerde inline tanımlı; `theme.accent` dolu = birincil, `white.opacity(0.08)` = ikincil, `E0574F` = tehlike. Tutarsız corner (10/11/13/14/16) ve yükseklik (36/38/40/48).

**Sorun:** Tek bir buton dili yok; her panel kendi yüksekliğini/köşesini seçiyor.

**Önerilen — 3 stil + tek yükseklik sistemi:**

| Stil | Zemin | Metin | Köşe | Yükseklik | Disabled |
|---|---|---|---|---|---|
| Primary | `accent` (dolu) | `white` | `radiusM` | 44 (HIG min) | zemin `surfaceHigh`, metin `textQuaternary` |
| Secondary | `surfaceHigh` | `textPrimary` | `radiusM` | 44 | aynı, metin `textQuaternary` |
| Danger | `danger .9` | `white` | `radiusM` | 44 | — |
| Compact (step) | renk | `white` | `radiusS` | 40 | — |
| Icon (kare) | `surfaceHigh`/`accent` | — | `radiusM` | 44×44 | — |

- **Birincil CTA'larda `accentGlow`** (raise/funding butonunda zaten var; primary'lere standart yap, hafif).
- Buton metni `bodyL` (15) ana, alt-detay `numberS`/`label`.
- `buttonStyle(.plain)` + basılı durumda `scaleEffect 0.97` + hafif opacity (bkz §6).

### 4.4 Karar Kartı (DecisionCardView)

**Şu an:** Ortada dikey kart; dairesel kategori ikonu + tint, speaker caps, prompt, seçimler `white .08` + tint stroke. Spring giriş ✓.

**Sorun:** İyi durumda ama: seçim butonları hepsi aynı görsel ağırlıkta — "riskli" vs "güvenli" seçim ayrımı renkle desteklenmiyor. Detay metni (`+itibar, +kullanıcı / risk`) düz; ikon yok. Backdrop `black .6` yeterli ama kart kenar parlaması kategori tint'ini az kullanıyor.

**Önerilen:**
- Kategori tint'i merkezi semantiğe bağla (crisis→`danger`, opportunity→`success/gold`, investor→`accent`...).
- Seçim butonları: ilk (cesur) seçim hafif tint dolgulu kenarlık, ikincisi (güvenli) nötr. Detay satırına minik +/− ikonu (yeşil ↑ / kırmızı ↓) ile **etki ön-izlemesi** — "oyun hissi"ni en çok artıran nokta.
- Karar geldiğinde hafif haptik (`.warning`/`.impact`) (bkz §6).
- Kart üst kenarına kategori tint'inde 2px ışıltılı şerit (overlay).

### 4.5 Çalışan / Departman Kartı (EmployeeCardView + DeptRow)

**Şu an:** EmployeeCardView referans stili güzel (ikon yarısı kartın üstünden taşıyor ✓). TeamPanel DeptRow daha sade.

**Sorun:** İki yerde departman görselleştirmesi farklı dilde (biri büyük dairesel taşan ikon, diğeri 42px daire). "Çıkar" butonu DeptRow'da nötr `minus`, EmployeeCard'da kırmızı — tutarsız.

**Önerilen:**
- Dept rengi (`dept.colorHex`) tutarlı: ikon + "İşe Al" butonu o renkte, "Çıkar" her yerde `danger` dili (ikon `minus` yeterli, dolgu değil).
- DeptRow'a minik **çıktı barı** (dept output / hedef) ekle — sayı yerine görsel "büyüme" hissi.
- Headcount değişince sayıda `numericText()` + minik pop.

### 4.6 Tab Bar

**Şu an:** `ultraThinMaterial` + üstte 1px hairline. SF Symbol `hierarchical`, seçili accent, diğerleri `white .5`. (Eski screenshot'larda emoji görünüyordu — kod SF Symbol'e geçmiş ✓.)

**Sorun:** Seçili sekme yalnız renk + weight ile ayrışıyor; "aktif" hissi zayıf. 6 sekme dar ekranda sıkışık, etiketler 10pt.

**Önerilen:**
- Seçili sekmenin **arkasına yumuşak accent "pill" highlight** (`accent .15`, `radiusM`, `matchedGeometryEffect` ile kayan) — net "neredeyim" sinyali + oyunsu.
- Seçili ikon `.symbolEffect(.bounce)` seçildiğinde (iOS 17+).
- Etiketleri `caption`(9 bold caps) yerine `label`(11) tut; seçili olanı `numberXS`→ hayır, metin Inter kalsın; sadece weight farkı.
- Üst hairline `hairline` token'ı.

### 4.7 Overlay'ler (funding / win / iflas / offline / onboarding)

**Şu an:** Hepsi merkezi kart + büyük hero SF Symbol + spring. İyi temel.

**Sorun:** Backdrop opaklıkları tutarsız (`.6/.7/.9/.65/.92`). Funding/Win'de kutlama "anı" zayıf — statik ikon büyüyor ama konfeti/parıltı yok. Onboarding düz arka plan (`14161F`), accent yok.

**Önerilen:**
- **Backdrop standardı:** içerik overlay'leri `black .6` + `radiusOverlay` + `elev2`; tam-ekran sonuç (win/iflas) `bg`'nin koyu tonu `.92`.
- **Funding & Win = kutlama anı:** hero ikon spring + `gold`/accent **parıltı halkası** (genişleyip sönen daire), hafif konfeti (SpriteKit emitter ya da basit `TimelineView` ile 12 partikül), `.success` haptik. (bkz §6 — sade tutarak.)
- **Onboarding:** evre-0 accent'ini taban gradient olarak çok hafif kullan (`accent .08` → `bg`), hero ikon `symbolEffect(.pulse)`.
- Tüm overlay primary butonları §4.3 Primary stiline uysun.

### 4.8 Büyüme reklam kontrolü (GrowthPanel budgetCard)

**Şu an:** Büyük accent bütçe sayısı (`displayM` ✓ `numericText` ✓), 4 step buton (`− + +×5 Sıfırla`), altında 2 projeksiyon stat. Metrik grid 6'lı.

**Sorun:** 4 step buton eşit ağırlıkta — `−`(danger) ve `+`(success) ile `+×5`(accent) `Sıfırla`(gri) aynı boyutta yarışıyor. CAC/LTV metrikleri ayrı grid'de, bütçe→sonuç bağı görsel değil.

**Önerilen:**
- Step kontrolü: `−` / `+` ana ikili (geniş), `+×5` ve `Sıfırla` daha küçük ikincil. Ya da bir **slider/stepper** hibriti (dokunsal "gaz pedalı" hissi).
- `LTV:CAC` oranı zaten renk-kodlu (`ratioColor` → semantiğe bağla) ✓. Bütçe değişince "Net büyüme/ay" metriğine minik vurgu animasyonu — "kararımın sonucu" hissi.
- healthNote ikonu/metni semantik renk (`success`/`warning`/`danger`) — zaten yapıyor ✓, sadece token'a bağla.

### 4.9 Gider Dağılımı Çubukları (StatsPanel costBreakdown)

**Şu an:** Her gider kalemi: ikon + ad + tutar, altında tek renk (`accent .75`) capsule bar, track `white .06`.

**Sorun:** Tüm barlar aynı renk → kalemler ayrışmıyor; en büyük gider (genelde maaş) öne çıkmıyor. Toplam başlık `danger` ama kalemler nötr.

**Önerilen:**
- Her bara **kalemin kendi tonu** (maaş=accent, reklam=warning, kira/cloud=nötr accent tonları) — ya da en azından **en büyük kalem dolu accent, diğerleri `accent .4`**.
- Barların hizası: tutar sağda monospace hizalı (`numberS`). Bar yüksekliği 6→8 (daha okunur).
- Bar animasyonu: panel açılışında soldan dolma (`.easeOut`, staggered delay).

### 4.10 Yol Haritası Satırları (RoadmapPanel StageRow)

**Şu an:** Dairesel durum göstergesi (✓/taç/numara) + ad + hedef değerleme; sıradaki evrede ProgressView; pasif evreler `.55` opacity.

**Sorun:** İyi ama dikey "yol" hissi yok — satırlar bağımsız kartlar, aralarında çizgi/bağlantı yok. "Yol haritası" metaforu görselde zayıf.

**Önerilen:**
- Daireler arasına **dikey bağlantı çizgisi** (tamamlanan kısım `success`, gelecek kısım `hairline`) — gerçek bir "yol" hissi.
- Mevcut evre kartı `hairlineStrong` + hafif accent glow (sen buradasın).
- Tamamlanan ✓ daireleri `success`, mevcut `accent`, gelecek nötr ✓ (zaten böyle, sadece çizgi ekle).
- Unicorn (son) satırı `gold` taç + her zaman hafif görünür (kilit gri değil, "hedef" parıltısı).

### 4.11 Founder İpucu Balonu & Speed Butonu

**Şu an:** Balon `ultraThinMaterial` + kişi ikonu; speed butonu 48×48 kare.

**Önerilen:**
- Balona küçük "konuşma kuyruğu" (üçgen) — maskot konuşuyor hissi; metin değişince mevcut `easeInOut` + hafif `numericText`/fade ✓.
- Speed butonu yüksekliği 44/48 sistemine uysun; aktif (>1×) durumda `accentGlow`.
- Runway <3 ay olunca balon tint'i `warning`/`danger`'a kaysın (içerik zaten uyarı veriyor).

---

## 5. İkonografi (SF Symbols)

**Şu an:** `Icons.swift` merkezi ✓ — çok iyi. Bazı yerlerde inline `systemName` (HUD checkmark/xmark, funding satır ikonları) merkez dışı.

**Kurallar:**
- **Boyut ölçeği:** mikro `10`, satır içi `12`, standart `14`, hücre `18`, hero `30/60/72`. Tek bir `IconSize` enum'ı.
- **Weight kuralı:** satır içi/etiket `.semibold`, vurgulu/aktif `.bold`, hero `.bold`. Tutarlı tut.
- **Renk kuralı:** varsayılan `accent`; durum bildiren ikon semantik (`success/warning/danger`); nötr bağlam `textTertiary`.
- **Rendering:** çok-renk gereken yerde `.hierarchical` (tab bar ✓, karar ikonu ✓); tek renk ise düz.
- Inline kalan ikonları (`checkmark.circle.fill`, funding `banknote.fill` vb.) `Icons` altına taşı — tek kaynak.
- `crown.fill` (Unicorn) hep `gold`; `xmark.octagon.fill` (iflas) hep `danger`.

---

## 6. Hareket / Animasyon & "Oyun Hissi"

> İlke: **az ama isabetli.** Bir iyi orkestre edilmiş "an" > on dağınık mikro-animasyon. Sade kalarak oyunlaştır.

### 6.1 Standart eğriler (token)

| Token | Spring/Easing | Kullanım |
|---|---|---|
| `animSnappy` | `.spring(response: 0.32, dampingFraction: 0.75)` | Overlay giriş, kart pop (mevcut değerlerle uyumlu ✓) |
| `animBouncy` | `.spring(response: 0.4, dampingFraction: 0.6)` | Kutlama (funding/win hero) ✓ |
| `animSmooth` | `.easeInOut(0.25)` | Tab geçiş, balon metni, renk değişimi |
| `animQuick` | `.easeIn(0.12–0.15)` | Çıkış/dismiss ✓ |

### 6.2 Sayaç & değer animasyonları

- `contentTransition(.numericText())` **tüm anlamlı sayılarda**: HUD nakit ✓/değerleme/kullanıcı/MRR, reklam bütçesi ✓, metrik değerleri, headcount.
- Büyük artışta (raise, funding) nakit sayısında **kısa scale-pop** (`1.0→1.08→1.0`, `animSnappy`).

### 6.3 Geçişler

- Tab değişimi: panel `opacity + 6px y-offset` fade (`animSmooth`) — sert kesme yerine yumuşak.
- Tab bar seçili pill `matchedGeometryEffect` ile kayar (§4.6).

### 6.4 Vurgu / durum animasyonları

- **Negatif nakit / kritik runway:** HUD nakit arkasında çok hafif `danger .12` pulse (1.2s, `repeatForever` autoreverse) — panik değil, dikkat.
- **Buy/Hire başarılı:** ilgili kart kenarında 1 kez yeşil `success` flash + scale-pop.
- Buton basılı: `scaleEffect 0.97` + `brightness -0.05` (`.plain` + custom `ButtonStyle`).

### 6.5 Kutlama anları (en yüksek "oyun" getirisi)

- **Funding turu / Unicorn:** hero ikon `animBouncy` + genişleyip sönen **parıltı halkası** (`Circle().stroke(gold)` scale 0.4→2.2, opacity 1→0), 10–14 partikül konfeti (SpriteKit `SKEmitterNode` ya da basit SwiftUI `TimelineView`/`Canvas`), `.success` haptik.
- Sade kalsın: konfeti 1.5s sonra biter, arka plan sakin.

### 6.6 Haptik (UIImpact/Notification)

| Olay | Haptik |
|---|---|
| Birincil CTA (raise) | `.impact(.medium)` |
| İşe al / modül satın al | `.impact(.light)` |
| Karar geldi | `.impact(.rigid)` veya `.warning` |
| Funding / Win | `.success` |
| İflas | `.error` |
| Tab değişimi | `.selection` (hafif) |
| Negatif nakit eşiği | `.warning` (bir kez) |

> Tek `Haptics` yardımcı enum'ı (`Haptics.tap()`, `.success()`, `.warning()`...).

---

## 7. Önceliklendirilmiş UI Cila Backlog'u

> Format: **[Öncelik] Ne — neden — hangi dosya — kabaca nasıl.**

### P0 (en yüksek etki, düşük risk — önce bunlar)

1. **Merkezi renk/semantik token'ları** — sihirli hex'ler 8+ dosyada tekrar; tutarsızlık. *Dosya:* yeni `Sources/UI/Palette.swift` + `Theme.swift`. *Nasıl:* `enum Palette { static let success/warning/danger/gold... }`; `Theme`'e `surfaceHigh`, `hairline`, `textTertiary` türetilmiş alanlar. Tüm `Color(hex:"4FD1A1")` vb. → `Palette.success`.

2. **Named tipografi ölçeği** — punto kaosu, hiyerarşi zayıf. *Dosya:* `Typography.swift`. *Nasıl:* `Font.displayL/numberL/titleM/body/label/caption...` helper'ları ekle; panellerde ham `appText(13,...)` çağrılarını bunlarla değiştir (kademeli).

3. **HUD hiyerarşi + sadeleştirme** — en yoğun ekran, ilk izlenim. *Dosya:* `HUDView.swift`. *Nasıl:* nakit kahraman, değerleme/hisse ikincil grup; pill etiketi 8→9pt; iki barın etiketlerini aynı Inter stiline hizala; üst nefes (`space2`). Negatif nakit pulse (§6.4).

4. **PanelCard katmanlama** — düz görünüm, derinlik yok. *Dosya:* `Theme.swift`. *Nasıl:* `surfaceHigh` iç hücre tonu; stage 0'a taban gölge (`r:8`); stroke biraz görünür; corner clamp (`16…22`).

5. **Tek buton dili (44pt, 3 stil)** — tutarsız yükseklik/köşe. *Dosya:* yeni `Sources/UI/Buttons.swift` (PrimaryButtonStyle / SecondaryButtonStyle / DangerButtonStyle veya `ViewModifier`). *Nasıl:* 44pt min, `radiusM`, basılı `scale 0.97`; panellerdeki inline butonları bağla.

### P1 (oyun hissi + tutarlılık)

6. **Haptik katmanı** — dokunsal geri bildirim yok, "oyun" hissi eksik. *Dosya:* yeni `Sources/UI/Haptics.swift`. *Nasıl:* §6.6 tablosu; aksiyon noktalarına çağrı ekle.

7. **Karar kartı etki ön-izlemesi + tint** — kararın sonucu görünmüyor. *Dosya:* `DecisionCardView.swift`. *Nasıl:* `choice.detail`'a +/− semantik ikon; kategori tint→semantik; üst 2px şerit; geldiğinde haptik.

8. **Tab bar aktif highlight** — "neredeyim" zayıf. *Dosya:* `ContentView.swift`. *Nasıl:* seçili arkasına `accent .15` pill + `matchedGeometryEffect`; ikon `symbolEffect(.bounce)`.

9. **numericText + scale-pop yaygınlaştır** — sayılar canlansın. *Dosya:* HUD, Growth, Stats, Team. *Nasıl:* anlamlı sayılara `.contentTransition(.numericText())`; raise/funding'de nakit pop.

10. **Gider barları renk + animasyon** — kalemler ayrışmıyor. *Dosya:* `StatsPanel.swift`. *Nasıl:* en büyük kalem dolu accent / diğerleri `.4`; açılışta soldan dolma stagger.

11. **Overlay backdrop + buton standardı** — opaklık/stil tutarsız. *Dosya:* `EventOverlays.swift`, `OnboardingOverlay.swift`. *Nasıl:* §4.7 backdrop standardı; primary butonları yeni stile bağla.

### P2 (parlatma — sona)

12. **Funding/Win kutlama anı** — parıltı halkası + konfeti + `.success` haptik. *Dosya:* `EventOverlays.swift` (+ opsiyonel SpriteKit emitter). *Nasıl:* §6.5; sade, 1.5s.

13. **Roadmap dikey "yol" çizgisi** — metafor görselde yok. *Dosya:* `RoadmapPanel.swift`. *Nasıl:* daireler arası bağlantı çizgisi (tamamlanan `success`, gelecek `hairline`); mevcut evre glow.

14. **Evre büyümesi "güzelleşme" sinyalleri** — köşe/gölge/kenarlık/accent kademeli. *Dosya:* `Theme.swift`. *Nasıl:* §1.3 tablosu; kademeleri stage'e bağla, clamp'le.

15. **Tab geçiş + balon kuyruğu + speed glow** — mikro cila. *Dosya:* `ContentView.swift`, `OfficePanel.swift`. *Nasıl:* panel fade/offset; balon üçgen kuyruk; speed >1× glow.

16. **İkon merkezileştirme tamamlama** — inline `systemName` kalanları `Icons`'a taşı. *Dosya:* `Icons.swift` + çağrı yerleri. *Nasıl:* §5; `IconSize` enum.

---

## Özet sayfası (uygulayıcı için tek bakış)

- **Renk:** `bg → surfaceLow → surfaceHigh → surfaceFloat` katmanları + sabit `success #3FCF8E / warning #F5C451 / danger #F0584F / gold #FFD479` + metin opaklık 1.0/0.78/0.52/0.32. Accent evreyle doygunlaşır.
- **Tipo:** Space Grotesk sayı / Inter metin; named ölçek (display/number/title/body/label/caption).
- **Boşluk:** 4pt skala; kenar 16; köşe `16…22` evre-duyarlı; gölge stage 0'da bile hafif taban.
- **Buton:** 44pt, 3 stil, basılı `scale 0.97`.
- **Hareket:** `numericText` her sayıda; kutlama anı (halka+konfeti+haptik); negatif nakit pulse; tab pill highlight.
- **İlk 3 P0:** (1) merkezi token'lar (2) tipo ölçeği (3) HUD hiyerarşi.
