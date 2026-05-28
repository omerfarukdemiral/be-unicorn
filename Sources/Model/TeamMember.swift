import Foundation

/// Şirketteki tek bir çalışan — adı, departmanı, yeteneği, kıdemi ve atandığı projesi var.
/// `headcount[i]` sayaçları KORUNUYOR (eski ekonomi formülleri değişmez); bu struct
/// üzerine kimlik katmanı ekler: kim bu masada oturuyor, hangi projeye çalışıyor.
///
/// `skillLevel` SADECE kozmetiktir (1-5) — ekonomi katsayılarını etkilemez; karakter
/// derinliği için (yıldız rozeti, "L3 mühendis" görünümü). Hire'da rastgele rulo edilir
/// (çoğu L1-L2, nadiren L4-L5).
///
/// `assignedProjectID` opsiyoneldir; mühendislik/ürün üyeleri otomatik atanır,
/// diğerleri (pazarlama/satış/ops) proje-bağımsız çalışır.
struct TeamMember: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var firstName: String
    var lastName: String
    var deptIndex: Int                // Balance.departments indeksi (0-4)
    var skillLevel: Int = 1           // 1-5; sadece görsel rozetlemede kullanılır
    var joinedMonth: Double = 0       // şirkete katıldığı oyun-ayı
    var isFounder: Bool = false       // CEO/kurucu mu (fire edilemez, HUD'da görünür)
    var assignedProjectID: UUID? = nil

    /// "Ada Yılmaz" — boş soyad güvenli.
    var fullName: String {
        let n = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "Çalışan" : n
    }

    /// "AY" — koltuk avatarında 2 harf. Boş ise "?".
    var initials: String {
        let f = firstName.first.map { String($0) } ?? "?"
        let l = lastName.first.map { String($0) } ?? ""
        return (f + l).uppercased()
    }

    /// Beceri yıldız metni (skillLevel 1-5 → "★" tekrar).
    var skillStars: String {
        String(repeating: "★", count: min(5, max(1, skillLevel)))
    }
}
