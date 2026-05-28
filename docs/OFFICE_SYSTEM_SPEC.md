# Ofis Kroki & Eşya Sistemi — Tasarım Spec'i

## Yön (kullanıcı kararı)
- **İzometrik/3D sahne KALDIRILIYOR.** SpriteKit ofis sahnesi, vektör mobilyalar, karakterler — hepsi uçurulacak.
- Yerine: **2D top-down, oyunlaştırılmış KROKİ** (mimari plan). Sade, hafif, SwiftUI (Canvas/shape). Sahne/obje/3D yok.
- Ofis bir **m² alandır**; oyuncu **eşya satın aldıkça kroki dinamik dolar.** Eşyalar modern lükssten en basitine yüzlerce çeşit.
- Her şey **oyun matematiğine bağlı** (alan, koltuk kapasitesi, moral, üretim, itibar).

## Kaldırılacaklar (uçur)
- `Sources/Scene/` tamamen: `OfficeScene.swift`, `IsoFurniture.swift`, `EmployeeNode.swift`, `FounderMascot.swift`, `Art.swift`. (`Art.swift`'teki `UIColor.lighter/darker` başka yerde kullanılıyorsa küçük bir yardımcıya taşı; değilse sil.)
- `OfficePanel.swift` içindeki `SpriteView`/`OfficeScene` kullanımı; `ContentView`'daki `OfficeScene` kurulumu. Ofis sekmesi artık SwiftUI `FloorPlanView`.
- Kalan Kenney/iso referansı sıfır olmalı.

## Model

### Ofis alanı (m²) — evreye bağlı
`Balance.officeAreaM2(stage:)` → ör. Garaj 30, Pre-seed 80, Seed 200, Series A 500, Series B 1200, Series C 3000, Unicorn 8000. (İsteğe bağlı sonraki iş: evre içinde "alan genişletme/kira" satın alımı.)

### Eşya tanımı
```
struct OfficeItemDef: Identifiable {
  let id: Int
  let name: String
  let category: ItemCategory
  let icon: String            // SF Symbol (emoji YOK)
  let cost: Double
  let areaM2: Double          // tükettiği alan
  let seatCapacity: Int       // çalışan koltuğu (masalar)
  let moraleBonus: Double     // moraleTargetBonus'a katkı
  let outputBonus: Double     // global üretim +% (0.02 = %2)
  let reputationBonus: Double // itibar etkisi
  let unlockStage: Int
}
enum ItemCategory { case workstation, social, kitchen, comfort, plant, luxury, infra }
```

### GameState
- `ownedItems: [Int: Int]` (itemId → adet). Codable + `normalize()` güvenli.
- (Geri uyumluluk: eski kayıtta yoksa boş; garaj için varsayılan birkaç masa tohumla ki ilk çalışan oturabilsin.)

### GameModel (türetilmiş)
- `usedAreaM2` = Σ owned * areaM2; `totalAreaM2` = officeAreaM2(stage); `freeAreaM2`.
- `seatCapacity` = Σ owned * seatCapacity (+ garaj tabanı, ör. 2). **headcount cap = seatCapacity.**
- Eşya moral katkısı → `moraleTarget` hesabına eklenir (mevcut moraleTargetBonus mantığına ek bir `itemMoraleBonus`).
- Eşya `outputBonus` → mevcut `effects.globalOutput`'a benzer şekilde üretime; `reputationBonus` → itibara küçük kalıcı katkı.
- `canBuyItem(id)` = stage>=unlock && cash>=cost && freeAreaM2>=areaM2 && (workstation değilse veya alan varsa). `buyItem(id)`: nakit düş, owned++, save.
- **İşe alım kısıtı:** `canHire(dept)` artık ayrıca `totalHeadcount < seatCapacity` şartı; koltuk yoksa TeamPanel "Masa/alan al" yönlendirir.

## Katalog (başlangıç ~30-40, "yüzlerce"ye genişletilebilir — id sırası KORUNMALI)
Etki dengesi BalanceSim ile sonra kalibre edilir; başlangıç makul değerler:

**workstation (koltuk + üretim):** Basit Masa (ucuz, seat+1, küçük alan), Ergonomik Masa (seat+1, +output, daha pahalı/alan), Ayakta Masa, Toplantı Masası (+output/+reputation, koltuk yok), Beyaz Tahta (+output), Kitaplık/Dolap (küçük +output), Ekstra Monitör (+output).

**social (moral):** Masa Tenisi, Langırt, Bilardo, Dart, Oyun Konsolu+TV, Atari Kabini, Bordoyun Köşesi.

**kitchen (moral):** Kahve Makinesi, Espresso İstasyonu, Mini Mutfak, Buzdolabı, Atıştırmalık Bar, Su Sebili.

**comfort (moral, churn↓ hissi):** Dinlenme Kanepesi, Puf Köşesi, Hamak, Uyku Kapsülü (nap pod), Kütüphane Köşesi, Ergonomik Lounge.

**plant (moral + estetik/itibar):** Saksı Bitki, Büyük Bitki, Dikey Bahçe, Akvaryum, Bonsai.

**luxury (yüksek moral + itibar, pahalı + çok alan, ileri evre):** Şömine, Jakuzi, Golf Simülatörü, İçki Barı, Mini Sinema, Masaj Koltuğu, Sanat Koleksiyonu, Çatı Terası.

**infra (flavor/utility):** Sunucu Rafı, Telefon Kabini, Resepsiyon Bankosu, Konferans Ekranı.

(Her kategori ileride onlarca varyantla "yüzlerce"ye çıkarılabilir; sistem id-tabanlı ve veri-odaklı.)

## Kroki görünümü (FloorPlanView — SwiftUI, 2D top-down, sade)
- Ofis sınırı: m²'ye orantılı bir plan dikdörtgeni (veya sabit tuval + "doluluk" göstergesi). İnce accent çerçeve + hafif grid arka plan = mimari kroki hissi.
- Sahip olunan eşyalar plan içine **otomatik yerleşir** (akış/grid packing). Her eşya: yumuşak hücre (RoundedRect, Palette yüzey) + SF Symbol ikon + ad + adet rozeti. Kategori rengiyle ince vurgu.
- Üstte: "m² kullanım: X/Y", koltuk: dolu/kapasite, doluluk bar'ı.
- **Dinamik:** ownedItems değişince kroki anında güncellenir (satın alma → yeni hücre pop animasyonu, Motion/Haptics token'larıyla).
- Estetik: Palette/Typography/Theme dilini kullan; evre arttıkça plan paleti zenginleşir (mevcut "evre güzelleşme" ilkesi). Tamamen 2D, hafif.

## Mağaza (ItemShopView)
- Ofis sekmesinden açılan katalog (sheet veya alt panel). Kategori sekmeleri/filtre. Her eşya kartı: ikon, ad, cost, +etkiler (koltuk/moral/üretim/itibar), m². Alınabilirlik: kilit (evre), alan yetersiz, nakit yetersiz durumları net.
- Satın al → krokiye eklenir + ilgili math güncellenir (kapasite/moral/üretim).

## UI yerleşimi
- "Ofis" sekmesi = FloorPlanView (kroki) + "Mağaza" aç butonu (+ hız/funding kontrolleri OfficePanel'den taşınır). Founder ipucu balonu kalabilir.
- TeamPanel: işe alım koltuk kapasitesine bağlı; kapasite dolu ise "Daha fazla masa/alan al" uyarısı.
- HUD/İstatistik: koltuk doluluk + m² kullanım küçük metrik eklenebilir.

## Math entegrasyon özeti
- Masa sayısı → çalışan kapasitesi (işe alım tavanı) — yeni gerçek kısıt.
- Sosyal/mutfak/konfor/bitki/lüks → moral hedefi (mutlu ekip, churn↓, üretim↑ moralFactor üzerinden).
- Bazı eşyalar → üretim %'si / itibar.
- Hepsi m² tüketir → funding ile büyüyen ofis = daha çok eşya = ölçek. Denge (cost/area/effect) sonradan BalanceSim ile kalibre.

## Sıra
1. (önce) Retention #1 (Ligler) ajanı bitsin → build temiz.
2. Bu sistemi kuran ajan: iso sahneyi kaldır → model (alan/eşya/kapasite/math) → FloorPlanView + ItemShopView → TeamPanel koltuk kısıtı → build green + simülatör doğrulama (boş garaj → birkaç eşya alınca kroki dolması). Tek build'ci.
3. Sonra retention döngüsü kaldığı yerden veya denge turu.
