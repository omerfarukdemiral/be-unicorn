import Foundation
import UserNotifications

/// Yerel bildirim yöneticisi (#5) — BASKICI DEĞİL.
///
/// Blueprint retention notu: streak baskısı manipülatif olmasın. Bu yüzden ton
/// "kaldığın yerden devam" / "seni bekliyoruz" — suçlama, sayaç korkutması,
/// "X saat içinde her şeyi kaybedeceksin" gibi karanlık desen YOK.
///
/// İki nazik hatırlatma planlanır (yalnızca uygulama arka plana alınınca):
///  1. Streak-risk: oyuncunun KORUYACAK bir streak'i varsa, gün bitmeden önce
///     (yerel saatle akşam) tek bir "serini koru" anımsatması. Streak yoksa
///     bu bildirim hiç planlanmaz — yapay aciliyet üretmeyiz.
///  2. D1 inaktivite dönüşü: ~24 saat sonra "kaldığın yerden devam" daveti.
///
/// Foreground'a dönünce bekleyen TÜM planlı bildirimler iptal edilir
/// (oyuncu zaten içerideyken bildirim göndermek anlamsız + rahatsız edici).
/// Plist anahtarı GEREKMEZ — izin runtime'da UNUserNotificationCenter ile istenir.
enum NotificationManager {

    // Bildirim kimlikleri (yeniden planlamada eskisini deduplike etmek için sabit).
    private static let streakRiskID = "unicorn.streakRisk"
    private static let comebackID   = "unicorn.comeback"

    private static var center: UNUserNotificationCenter { .current() }

    // MARK: - İzin

    /// İzin durumunu sessizce sorgula (UI tetiklemeden).
    static func authorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    /// İzni iste — yalnızca daha önce KARAR VERİLMEMİŞSE sistem diyaloğunu göster.
    /// Onboarding/şirket kuruluşu tamamlandıktan SONRA (doğal an) çağrılır.
    /// Reddedilse bile sessizce devam edilir; oyun bildirimsiz tam çalışır.
    static func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                // Sonucu önemsemiyoruz: izin yoksa schedule no-op olur (status kontrollü).
            }
        }
    }

    // MARK: - Planlama / iptal

    /// Uygulama arka plana alınırken çağrılır: nazik hatırlatmaları planla.
    /// `hasStreakToProtect`: oyuncunun bugün henüz tamamlanmamış ama korunacak
    /// bir streak'i var mı (streak > 0 && !dailyCompleted). `false` ise streak
    /// bildirimi PLANLANMAZ — sadece dönüş daveti kalır.
    static func scheduleReminders(streak: Int, dailyCompleted: Bool) {
        authorizationStatus { status in
            guard status == .authorized || status == .provisional else { return }
            // Önce eskileri temizle (üst üste binmeyi önle).
            cancelAll()

            let hasStreakToProtect = streak > 0 && !dailyCompleted
            if hasStreakToProtect {
                scheduleStreakRisk(streak: streak)
            }
            scheduleComeback()
        }
    }

    /// Foreground'a dönünce çağrılır: bekleyen tüm planlı bildirimleri iptal et.
    static func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: [streakRiskID, comebackID])
    }

    // MARK: - Yardımcılar

    /// Streak-risk: bugün akşam (yerel ~20:00), gün dolmadan tek nazik anımsatma.
    /// Eğer şu an zaten 20:00'ı geçtiyse hiç planlama (geçmiş tetikleyemez,
    /// yarına ertelemek "yapay aciliyet" olur — dönüş bildirimi zaten kapsar).
    private static func scheduleStreakRisk(streak: Int) {
        let now = Date()
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: now)
        comps.hour = 20
        comps.minute = 0
        guard let fireDate = Calendar.current.date(from: comps), fireDate > now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Serin seni bekliyor"
        // Suçlamasız ton: "koru" daveti, "kaybedeceksin" tehdidi değil.
        content.body = "\(streak) günlük serin sürüyor. Bugünün küçük hedefini tamamlayıp kaldığın yerden devam et."
        content.sound = .default

        let interval = max(1, fireDate.timeIntervalSince(now))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: streakRiskID, content: content, trigger: trigger))
    }

    /// D1 inaktivite dönüş daveti: ~24 saat sonra "kaldığın yerden devam".
    private static func scheduleComeback() {
        let content = UNMutableNotificationContent()
        content.title = "Şirketin seni bekliyor"
        content.body = "Ekibin çalışmaya devam etti. Kaldığın yerden dön, bir sonraki kararı sen ver."
        content.sound = .default

        let oneDay: TimeInterval = 24 * 60 * 60
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: oneDay, repeats: false)
        center.add(UNNotificationRequest(identifier: comebackID, content: content, trigger: trigger))
    }
}
