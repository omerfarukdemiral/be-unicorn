import SwiftUI

// MARK: - Merkezi SF Symbol eşleme
// Tüm emoji ikonları bu dosyadan SF Symbols ile karşılanır.
// Kullanım: Image(systemName: Icons.tab(.office))

enum Icons {

    // MARK: Tab bar sekme ikonları
    enum Tab {
        static let office   = "building.2.fill"
        static let team     = "person.2.fill"
        static let projects = "shippingbox.fill"
        static let growth   = "chart.line.uptrend.xyaxis"
        static let modules  = "square.grid.2x2.fill"
        static let roadmap  = "map.fill"
        static let stats    = "chart.bar.fill"
    }

    // MARK: Departman ikonları (Balance.departments id 0-4)
    enum Dept {
        static let engineering = "laptopcomputer"       // id 0 - Mühendislik
        static let product     = "paintbrush.fill"      // id 1 - Ürün & Tasarım
        static let marketing   = "megaphone.fill"       // id 2 - Pazarlama
        static let sales       = "dollarsign.circle.fill" // id 3 - Satış
        static let ops         = "gearshape.fill"       // id 4 - Operasyon

        /// Departman id'ye göre SF Symbol adını döndürür.
        static func symbol(for id: Int) -> String {
            switch id {
            case 0: return engineering
            case 1: return product
            case 2: return marketing
            case 3: return sales
            case 4: return ops
            default: return "person.fill"
            }
        }
    }

    // MARK: Modül ikonları (Balance.modules id 0-7)
    enum Module {
        static let cicd        = "arrow.triangle.2.circlepath" // id 0 - CI/CD Hattı
        static let growthHack  = "bolt.fill"                   // id 1 - Growth Hack
        static let premium     = "star.circle.fill"            // id 2 - Premium Paket
        static let success     = "headphones"                  // id 3 - Müşteri Başarısı
        static let culture     = "leaf.fill"                   // id 4 - Şirket Kültürü
        static let remote      = "house.fill"                  // id 5 - Uzaktan Çalışma
        static let server      = "server.rack"                 // id 6 - Sunucu Optimizasyonu
        static let hybrid      = "building.fill"               // id 7 - Hibrit Ofis
        static let autoscale   = "chart.line.uptrend.xyaxis"   // id 8 - Otomatik Ölçekleme
        static let perfMkt     = "scope"                       // id 9 - Performans Pazarlama
        static let enterprise  = "building.columns.fill"       // id 10 - Kurumsal Satış
        static let retention   = "magnet.fill"                 // id 11 - Tahminsel Elde Tutma
        static let finops      = "creditcard.circle.fill"      // id 12 - FinOps Disiplini
        static let mission     = "sparkles"                    // id 13 - Misyon & Liderlik

        /// Modül id'ye göre SF Symbol adını döndürür.
        static func symbol(for id: Int) -> String {
            switch id {
            case 0: return cicd
            case 1: return growthHack
            case 2: return premium
            case 3: return success
            case 4: return culture
            case 5: return remote
            case 6: return server
            case 7: return hybrid
            case 8: return autoscale
            case 9: return perfMkt
            case 10: return enterprise
            case 11: return retention
            case 12: return finops
            case 13: return mission
            default: return "square.grid.2x2"
            }
        }
    }

    // MARK: Gider kalemi ikonları (Balance.costItems id 0-5)
    enum Cost {
        static let rent      = "building.2"          // id 0 - Ofis Kirası
        static let saas      = "doc.text.fill"        // id 1 - SaaS & Yazılım
        static let cloud     = "cloud.fill"           // id 2 - Bulut & Sunucu
        static let legal     = "scalemass.fill"       // id 3 - Yasal & Muhasebe
        static let equipment = "desktopcomputer"      // id 4 - Ekipman & Donanım
        static let general   = "fork.knife"           // id 5 - Genel & İdari

        /// Gider id'ye göre SF Symbol adını döndürür.
        static func symbol(for id: Int) -> String {
            switch id {
            case 0: return rent
            case 1: return saas
            case 2: return cloud
            case 3: return legal
            case 4: return equipment
            case 5: return general
            default: return "creditcard.fill"
            }
        }
    }

    // MARK: Karar kategorisi ikonları (DecisionCategory)
    enum Decision {
        static let investor    = "dollarsign.circle.fill"
        static let crisis      = "exclamationmark.triangle.fill"
        static let press       = "newspaper.fill"
        static let team        = "person.2.fill"
        static let product     = "cube.fill"
        static let market      = "chart.xyaxis.line"
        static let opportunity = "sparkles"

        /// DecisionCategory string değerine göre SF Symbol döndürür.
        static func symbol(for category: String) -> String {
            switch category {
            case "investor":    return investor
            case "crisis":      return crisis
            case "press":       return press
            case "team":        return team
            case "product":     return product
            case "market":      return market
            case "opportunity": return opportunity
            default:            return "questionmark.circle"
            }
        }
    }

    // MARK: HUD / Metrik ikonları
    enum Metric {
        static let users      = "person.2.fill"
        static let cash       = "banknote.fill"
        static let mrr        = "chart.line.uptrend.xyaxis"
        static let runway     = "fuelpump.fill"
        static let runwayInf  = "infinity"              // karlı / sonsuz
        static let runwayWarn = "exclamationmark.triangle.fill"  // tehlike
        static let morale     = "face.smiling"
        static let valuation  = "building.columns.fill"
        static let churn      = "drop.fill"
        static let reputation = "star.fill"
        static let net        = "plusminus.circle.fill"
        static let arpu       = "person.text.rectangle.fill"
        static let ltv        = "chart.pie.fill"
        static let ltvcac     = "scale.3d"
        static let payback    = "clock.fill"
        static let organic    = "leaf.fill"
        static let netGrowth  = "arrow.up.right.circle.fill"
        static let decisions  = "list.bullet.clipboard"
        static let capacity   = "square.stack.fill"
        static let burn       = "flame.fill"
        static let office     = "building.2.fill"
        static let adBudget   = "megaphone.fill"
        static let health     = "checkmark.seal.fill"
        static let warning    = "exclamationmark.triangle.fill"
    }

    // MARK: Overlay / Ekran ikonları
    enum Screen {
        static let onboard0   = "chart.line.uptrend.xyaxis"  // Garajdan Zirveye (yükseliş)
        static let onboard1   = "person.2.fill"             // Ekibini Büyüt
        static let onboard2   = "rectangle.stack.fill"      // Kararlar Seni Bekler
        static let win        = "crown.fill"                // Unicorn kazandı
        static let bankruptcy = "xmark.octagon.fill"        // İflas
        static let funding    = "trophy.fill"               // Funding turu
        static let welcome    = "hand.wave.fill"            // Offline hoş geldin
        static let raise      = "arrow.up.forward.circle.fill" // Tur topla butonu
        static let founder    = "person.crop.circle.fill"   // Kurucu ipucu balonu
        static let locked     = "lock.fill"                 // Kilitli modül
    }
}

// MARK: - Yardımcı view uzantıları

extension Icons {
    /// Bir SF Symbol ikonu tutarlı stilde döndürür.
    static func image(_ name: String, size: CGFloat = 16, weight: Font.Weight = .semibold) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: weight))
    }
}
