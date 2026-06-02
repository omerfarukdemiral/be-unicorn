import Foundation

/// Deterministik, seedli sahte-rastgele üretici (SplitMix64).
///
/// Neden: oyunun ekonomi-kritik rastgeleliği (karar seçimi/zamanlaması, senaryo türü,
/// rakip kohortu) `meta.seed`'den türesin ki "aynı tohum → aynı oyun" mümkün olsun.
/// Bu testi, replay'i ve balans simülasyonunu açar (Faz 0). Kozmetik rastgelelik
/// (isim/ipucu önerileri) bilerek seed'siz, sistemin `SystemRandomNumberGenerator`'ı
/// ile taze kalır — her kuruluş özgün hissetsin.
///
/// SplitMix64: tek `UInt64` state, hızlı, dependency'siz, iyi dağılımlı. Swift'in
/// `RandomNumberGenerator` protokolüne uyduğu için `Double.random(in:using:&rng)`,
/// `Array.shuffled(using:)`, `randomElement(using:)` doğrudan çalışır.
struct SplitMix64RNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // 0 tohumu da geçerli bir akış üretir (sabit nokta yok) — yine de çağıran
        // taraf 0'ı "otomatik üret" işareti olarak kullanır, buraya 0 gelmez.
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
