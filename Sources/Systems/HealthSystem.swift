import Foundation

/// Şirket sağlık durumu (state machine). Krizler artık jenerik random değil — bu state'e bağlı
/// tetiklenir ve zincirleme kötüleşme bu state üzerinden ölçülür.
///
/// Tasarım Prensipleri (E maddesi):
/// - "Sağlıklı → Sıkıntılı → Kriz → Toparlanma" geçişleri net olmalı.
/// - Aynı kötü gidişat sürerse zincirleme kriz tetiklenmeli (moral düşükse istifa → revenue düşer → yatırımcı sertleşir).
enum CompanyHealth: String, Codable {
    /// Yeşil bölge: runway uzun, ekip mutlu, ünit-ekonomi iyi, churn düşük.
    case healthy
    /// Sarı bölge: bir metrik bozulmaya başladı — uyarıcı kartlar uygun.
    case strained
    /// Kırmızı bölge: en az bir kritik metrik tehlikeli — crisis kartları öncelikli.
    case crisis
    /// Krizden çıkış yolunda: önceki kriz + son çeyrekte iyileşme eğilimi.
    case recovering
}

/// Saf hesaplama — GameModel'in computed `companyHealth` property'si bunu çağırır.
/// Buradaki eşikler ekonomi sabitlerini DEĞİŞTİRMEZ; sadece kart önceliklendirmeyi besler.
enum HealthSystem {
    /// Sağlıklı kabul edilen eşikler (yeşil bölge — hepsi sağlanmalı).
    static let healthyRunwayMonths: Double = 6
    static let healthyMorale: Double = 60
    static let healthyLtvCac: Double = 2
    static let healthyChurn: Double = 0.05

    /// Kriz eşikleri (kırmızı bölge — biri yeterli).
    static let crisisRunwayMonths: Double = 3
    static let crisisMorale: Double = 35
    static let crisisLtvCac: Double = 1

    /// Toparlanma için ardışık iyileşme noktası sayısı (history örnekleri).
    static let recoveryWindow: Int = 4

    /// Saf değerlendirme: GameModel'in computed metrikleri üzerinden state'i belirler.
    /// Önceki state opsiyonel — toparlanma sezgisi için (önceki "crisis" idiyse iyileşme aranır).
    @MainActor
    static func evaluate(model: GameModel, previous: CompanyHealth? = nil) -> CompanyHealth {
        let runway = model.runwayMonths
        let morale = model.morale
        let ltvCac = model.ltvCacRatio
        let churn = model.churnRate

        // 1) Kırmızı bölge: kritik metriklerden biri yeterli.
        if runway < crisisRunwayMonths || morale < crisisMorale || ltvCac < crisisLtvCac {
            return .crisis
        }

        // 2) Yeşil bölge: tüm metrikler sağlıklı.
        let isHealthy = runway > healthyRunwayMonths
            && morale > healthyMorale
            && ltvCac > healthyLtvCac
            && churn < healthyChurn
        if isHealthy {
            return .healthy
        }

        // 3) Sıkıntılı vs. Toparlanma — önceki state crisis idiyse iyileşme eğilimine bak.
        //    Basit heuristik: son N history noktasında cash trend pozitif + morale yükseliyor.
        if previous == .crisis || previous == .recovering {
            if isRecovering(model: model) {
                return .recovering
            }
        }

        // 4) Aksi halde sarı bölge (orta — strained).
        return .strained
    }

    /// Basit iyileşme heuristiği: son birkaç history noktasında
    /// cash trendi pozitif VE moral yükseliyor → toparlanma sayılır.
    /// Yeterli örnek yoksa (oyun erken evrede) güvenli false → strained kalır.
    @MainActor
    static func isRecovering(model: GameModel) -> Bool {
        let points = model.state.history.suffix(recoveryWindow)
        guard points.count >= 2 else { return false }
        let cashes = points.map { $0.cash }
        let firstCash = cashes.first ?? 0
        let lastCash = cashes.last ?? 0
        let cashTrendPositive = lastCash > firstCash
        // Morale yükseliyor mu? Anlık moral, çeyrek ortalamasından yüksekse "yukarı eğilim".
        let avgMorale = model.state.quarterMoraleSamples > 0
            ? model.state.quarterMoraleSum / model.state.quarterMoraleSamples
            : model.morale
        let moraleTrendPositive = model.morale > avgMorale
        return cashTrendPositive && moraleTrendPositive
    }
}

// Not: GameModel.state `private(set)` olduğu için dışarıdan okunabilir;
// HealthSystem yalnızca okuma yapar — yazma erişimi gerekmez.
