import Foundation

/// Görüntü para birimi (yalnızca sembol; ekonomi sayıları soyut/değişmez).
enum Currency: String, CaseIterable, Codable {
    case usd = "usd"
    case eur = "eur"
    case lira = "try"

    var symbol: String {
        switch self {
        case .usd:  return "$"
        case .eur:  return "€"
        case .lira: return "₺"
        }
    }
    var label: String {
        switch self {
        case .usd:  return "Dolar"
        case .eur:  return "Euro"
        case .lira: return "TL"
        }
    }
}

/// Büyük sayı biçimleme: 1.2K, 3.4M, 5.6B ... Para ve sayaçlar için.
enum BigNumber {
    /// Aktif görüntü para birimi (GameModel ayarlar).
    static var currency: Currency = .usd
    private static let suffixes: [String] = [
        "", "K", "M", "B", "T",
        "aa", "ab", "ac", "ad", "ae", "af", "ag", "ah", "ai", "aj"
    ]

    /// Düz sayı (kullanıcı, gün vb.): 1.2K, 3.4M
    static func format(_ value: Double) -> String {
        if value < 0 { return "-" + format(-value) }
        if value < 1000 {
            return value == value.rounded() ? String(Int(value)) : String(format: "%.0f", value)
        }
        var tier = 0
        var scaled = value
        while scaled >= 1000 && tier < suffixes.count - 1 {
            scaled /= 1000
            tier += 1
        }
        let formatted = scaled >= 100 ? String(format: "%.0f", scaled)
                      : scaled >= 10 ? String(format: "%.1f", scaled)
                      : String(format: "%.2f", scaled)
        return formatted + suffixes[tier]
    }

    /// Para: seçili para birimi sembolüyle.
    static func money(_ value: Double) -> String {
        let sign = value < 0 ? "-" : ""
        return "\(sign)\(currency.symbol)\(format(abs(value)))"
    }
}
