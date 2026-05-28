import Foundation

// MARK: - Günlük Hedef + Streak (geri-dönüş kancası, completed-cycle ilkesi)
// Saf fonksiyonlar: gerçek-takvim gününe dayalı küçük tamamlanabilir görev seti,
// streak (ardışık gün) mantığı + lige besleme katkısı.
// Mantık burada izole — GameModel sadece çağırır, GameState veriyi saklar.

/// Günlük hedefin tek bir alt görevi (oyun aksiyonlarından beslenir).
enum DailyTaskKind: Int, Codable, CaseIterable {
    case hire        // bugün N işe alım yap
    case decision    // bugün N karar ver
    case users       // bugün +N kullanıcı kazan

    var icon: String {   // SF Symbol (emoji YOK)
        switch self {
        case .hire:     return "person.fill.badge.plus"
        case .decision: return "list.bullet.clipboard"
        case .users:    return "person.2.fill"
        }
    }
    var label: String {
        switch self {
        case .hire:     return "İşe alım yap"
        case .decision: return "Karar ver"
        case .users:    return "Yeni kullanıcı kazan"
        }
    }
}

/// Bir günlük alt görev: tür + hedef adet. İlerleme GameState sayaçlarından okunur.
struct DailyTask: Identifiable {
    let kind: DailyTaskKind
    let target: Int
    var id: Int { kind.rawValue }

    /// Görev metni (ör. "1 işe alım yap").
    var title: String {
        switch kind {
        case .hire:     return "\(target) işe alım yap"
        case .decision: return "\(target) karar ver"
        case .users:    return "+\(BigNumber.format(Double(target))) kullanıcı kazan"
        }
    }
    var icon: String { kind.icon }
}

enum DailyGoalSystem {

    // MARK: Takvim günü anahtarı (gerçek güne dayalı)

    /// Bir tarihin "gün anahtarı": yerel takvim gününe göre ardışık tam sayı (referanstan beri gün).
    /// Gün farkı = anahtar farkı → streak/sıfırlama mantığı bu fark üzerinden işler.
    static func dayKey(for date: Date = Date()) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        // 2001-01-01 referanslı gün indexi (referenceDate civarı). Negatif olmaz pratikte.
        let days = Int(start.timeIntervalSinceReferenceDate / 86_400)
        return days
    }

    // MARK: Günlük görev seti (güne göre rotasyonlu — deterministik)

    /// Verilen gün anahtarına göre o günün görev setini üret.
    /// Her zaman 1 işe alım + 1 karar sabit; 3. görev güne göre rotasyonlu kullanıcı hedefi.
    /// Kullanıcı hedefi şirket ölçeğiyle hafif ölçeklenir (erken oyunda küçük, geç oyunda anlamlı).
    static func tasks(dayKey: Int, users: Double, stage: Int) -> [DailyTask] {
        // Kullanıcı hedefi: ölçeğe göre kabaca günlük büyümenin küçük bir dilimi.
        // Taban + evre ölçeği; "tamamlanabilir" kalsın diye mütevazı.
        let base = Balance.dailyUsersBase
        let scaled = base * pow(1.8, Double(stage)) + users * 0.04
        // 10'a yuvarla, makul taban/tavan.
        let target = max(Int(base), Int((scaled / 10).rounded()) * 10)

        return [
            DailyTask(kind: .hire,     target: 1),
            DailyTask(kind: .decision, target: 1),
            DailyTask(kind: .users,    target: target),
        ]
    }

    // MARK: Streak mantığı (gerçek tarih farkı)

    /// Yeni güne geçildiğinde streak'i güncelle.
    /// - dünkü hedef tamamlandıysa ve gün farkı tam 1 ise streak +1
    /// - gün atlanırsa (fark > 1) veya dün tamamlanmadıysa streak 1'e/0'a sıfırlanır
    /// Dönüş: yeni streak değeri.
    static func rolledStreak(previousStreak: Int, dayGap: Int, yesterdayCompleted: Bool) -> Int {
        guard dayGap >= 1 else { return previousStreak }   // aynı gün — değişme
        if dayGap == 1 && yesterdayCompleted {
            return previousStreak + 1
        }
        // Gün kaçırıldı ya da dün tamamlanmadı → sıfırla.
        return 0
    }

    /// Streak'in moral hedefine kalıcı katkısı (puan) — artan ama tavanlı (abartma).
    static func streakMoraleBonus(_ streak: Int) -> Double {
        min(Balance.streakMoraleCap, Double(streak) * Balance.streakMoralePerDay)
    }

    /// Streak'in çeyrek lig skoruna katkısı (0-100 ölçeğine eklenir, küçük).
    /// Streak büyüdükçe artan ama tavanlı bonus — gerçek bahis hissini bozmaz.
    static func leagueScoreBonus(streak: Int, dailyGoalsThisQuarter: Int) -> Double {
        let streakPart = min(Balance.streakLeagueCap, Double(streak) * 0.6)
        let completionPart = min(Balance.dailyLeagueCap, Double(dailyGoalsThisQuarter) * 1.0)
        return streakPart + completionPart
    }
}
