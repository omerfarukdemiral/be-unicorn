import Foundation

// MARK: - Haftalık Sprint (çeyrek içi kısa, kapanan döngü — completed-cycle ilkesi)
// Saf fonksiyonlar: sprint başında net + TAMAMLANABİLİR bir hedef seç (ölçeğe göre),
// süre dolunca KAPANIŞ (başarılı = zirve/kutlama + ödül; başarısız = yine kapanış, ödül yok).
// Mantık burada izole — GameModel sadece çağırır, GameState veriyi saklar.

/// Bir sprint hedefinin türü (oyun metriklerinden beslenir).
enum SprintGoalKind: Int, Codable, CaseIterable {
    case mrr        // bu sprint: +%X MRR
    case users      // bu sprint: +X kullanıcı
    case decisions  // bu sprint: N karar ver

    var icon: String {   // SF Symbol (emoji YOK)
        switch self {
        case .mrr:       return "chart.line.uptrend.xyaxis"
        case .users:     return "person.2.fill"
        case .decisions: return "list.bullet.clipboard"
        }
    }
}

/// Bir sprint hedefi: tür + hedef değer. İlerleme GameState snapshot'larından okunur.
/// `target`: yüzde hedefleri için yüzde puanı (ör. 10 = +%10); sayı hedefleri için adet.
struct SprintGoal {
    let kind: SprintGoalKind
    let target: Double

    /// Hedef metni (ör. "+%10 MRR", "+1.2K kullanıcı", "3 karar ver").
    var title: String {
        switch kind {
        case .mrr:       return "+%\(Int(target.rounded())) MRR"
        case .users:     return "+\(BigNumber.format(target)) kullanıcı"
        case .decisions: return "\(Int(target.rounded())) karar ver"
        }
    }
    /// Kısa amaç açıklaması (kart alt satırı).
    var caption: String {
        switch kind {
        case .mrr:       return "Bu sprint geliri büyüt"
        case .users:     return "Bu sprint kullanıcı kazan"
        case .decisions: return "Bu sprint yön belirle"
        }
    }
    var icon: String { kind.icon }
}

enum SprintSystem {

    /// Sprint başı için net + tamamlanabilir bir hedef seç (sprint indeksiyle rotasyonlu).
    /// Ölçek mevcut metriklerden alınır; hedef mütevazı tutulur ("tamamlanabilir" ilkesi).
    /// - mrrAtStart: sprint başı MRR (yüzde hedefi için referans, deterministik bant)
    /// - users / stage: kullanıcı hedefini ölçeklemek için
    static func goal(sprintIndex: Int, mrrAtStart: Double, users: Double, stage: Int) -> SprintGoal {
        switch sprintIndex % 3 {
        case 0:
            // +%X MRR — erken oyunda büyüme hızlı, geç oyunda ılımlı hedef.
            let pct = stage <= 1 ? 12.0 : (stage <= 3 ? 9.0 : 7.0)
            return SprintGoal(kind: .mrr, target: pct)
        case 1:
            // +X kullanıcı — ölçeğe göre, 10'a yuvarlı, makul taban.
            let base = Balance.dailyUsersBase * 2.5
            let scaled = base * pow(1.7, Double(stage)) + users * 0.06
            let target = max(base, (scaled / 10).rounded() * 10)
            return SprintGoal(kind: .users, target: target)
        default:
            // N karar — kısa sprintte ulaşılabilir küçük sayı.
            return SprintGoal(kind: .decisions, target: stage <= 2 ? 2 : 3)
        }
    }

    /// Bir sprint hedefinin tamamlanıp tamamlanmadığını ölç.
    /// - startValue/currentValue: hedef metriğin sprint başı ve şu anki değeri.
    /// Dönüş: (ilerleme 0-1, tamamlandı mı, gösterim "x/y" done/target çifti).
    static func evaluate(goal: SprintGoal,
                         startMRR: Double, currentMRR: Double,
                         startUsers: Double, currentUsers: Double,
                         startDecisions: Int, currentDecisions: Int)
        -> (fraction: Double, done: Double, target: Double) {
        switch goal.kind {
        case .mrr:
            // Yüzde büyüme: (current/start - 1) * 100, hedef yüzde puanına göre.
            let grown = startMRR > 0.0001 ? (currentMRR - startMRR) / startMRR * 100 : (currentMRR > 0 ? 100 : 0)
            let done = max(0, grown)
            let frac = goal.target > 0 ? min(1, done / goal.target) : 1
            return (frac, done, goal.target)
        case .users:
            let done = max(0, currentUsers - startUsers)
            let frac = goal.target > 0 ? min(1, done / goal.target) : 1
            return (frac, done, goal.target)
        case .decisions:
            let done = Double(max(0, currentDecisions - startDecisions))
            let frac = goal.target > 0 ? min(1, done / goal.target) : 1
            return (frac, done, goal.target)
        }
    }

    /// İlerleme/hedef değerini kartta gösterilecek metne çevir (tür-duyarlı).
    static func progressText(goal: SprintGoal, done: Double, target: Double) -> String {
        switch goal.kind {
        case .mrr:       return "%\(Int(done.rounded()))/%\(Int(target.rounded()))"
        case .users:     return "\(BigNumber.format(done))/\(BigNumber.format(target))"
        case .decisions: return "\(Int(done.rounded()))/\(Int(target.rounded()))"
        }
    }

    /// Tamamlanan sprint'lerin çeyrek lig skoruna katkısı (0-100 ölçeğine eklenir, küçük).
    /// Streak besleme gibi tavanlı — gerçek bahis hissini bozmaz.
    static func leagueScoreBonus(sprintsWonThisQuarter: Int) -> Double {
        min(Balance.sprintLeagueCap, Double(sprintsWonThisQuarter) * Balance.sprintLeaguePerWin)
    }
}
