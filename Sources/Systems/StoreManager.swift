import Foundation
import StoreKit

/// B6 — StoreKit 2 IAP yöneticisi (tek seferlik non-consumable Tam Sürüm).
///
/// Tasarım kararları:
/// - Entitlement (satın alma hakkı) **Apple'da** tutulur (`Transaction.currentEntitlements`).
///   GameState'e YAZILMAZ — kaynak doğruluk her zaman App Store'dur; cihaz değiştirince
///   "Satın Almaları Geri Yükle" çalışır.
/// - GameModel bu sınıftan TAMAMEN bağımsızdır. Gating yalnızca ContentView seviyesinde
///   `store.isFullVersion` okunarak yapılır (Series A yumuşak duvarı).
/// - @MainActor: tüm @Published mutasyonları ana thread'de; UI doğrudan gözlemler.
@MainActor
final class StoreManager: ObservableObject {

    /// Tam Sürüm ürün kimliği (App Store Connect + Unicorn.storekit ile birebir eşleşmeli).
    static let fullVersionID = "co.omerfarukdemiral.unicorn.fullversion"

    /// Yüklenen ürün (fiyat etiketi yereldir — App Store'dan gelir, hardcode edilmez).
    @Published private(set) var fullVersionProduct: Product?

    /// Oyuncu Tam Sürüm'e sahip mi? (Apple entitlement'ından türetilir.)
    @Published private(set) var isFullVersion: Bool = false

    /// Ürün yükleme/satın alma sırasında aktif mi (UI spinner için).
    @Published private(set) var isLoading: Bool = false

    /// Son hata (kullanıcı-dostu, opsiyonel UI mesajı).
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        // Arka planda Apple'dan gelen transaction güncellemelerini dinle
        // (başka cihazda satın alma, iade, aile paylaşımı vb.).
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlement()
        }
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Ürün yükleme

    /// App Store'dan ürün metadata'sını (yerelleştirilmiş fiyat dahil) çeker.
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.fullVersionID])
            fullVersionProduct = products.first(where: { $0.id == Self.fullVersionID })
        } catch {
            lastError = "Ürün bilgisi yüklenemedi. İnternet bağlantını kontrol et."
        }
    }

    /// Yerelleştirilmiş fiyat etiketi (örn. "₺149,00" / "$6.99"). Yüklenmediyse nil.
    var displayPrice: String? { fullVersionProduct?.displayPrice }

    // MARK: - Satın alma

    /// Tam Sürüm'ü satın alır. Başarılıysa isFullVersion otomatik true olur.
    /// - Returns: satın alma tamamlandıysa true; iptal/bekleme/hata ise false.
    @discardableResult
    func purchaseFullVersion() async -> Bool {
        guard let product = fullVersionProduct else {
            await loadProducts()
            guard fullVersionProduct != nil else {
                lastError = "Ürün şu an yüklenemiyor. Birazdan tekrar dene."
                return false
            }
            return await purchaseFullVersion()
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlement()
                return isFullVersion
            case .userCancelled:
                return false
            case .pending:
                lastError = "Satın alma onay bekliyor (örn. Aile Onayı). Onaylanınca açılır."
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "Satın alma tamamlanamadı. Tekrar dene."
            return false
        }
    }

    // MARK: - Geri yükleme

    /// "Satın Almaları Geri Yükle" — App Store hesabıyla senkronize eder.
    /// Yeni cihaz / yeniden kurulum sonrası entitlement'ı geri getirir.
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if !isFullVersion {
                lastError = "Bu hesapta Tam Sürüm satın alması bulunamadı."
            }
        } catch {
            lastError = "Geri yükleme başarısız oldu. Tekrar dene."
        }
    }

    // MARK: - Entitlement

    /// Apple'ın güncel entitlement'larını tarar; Tam Sürüm hakkı varsa isFullVersion=true.
    func refreshEntitlement() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.fullVersionID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isFullVersion = owned
    }

    // MARK: - Transaction dinleyici

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.refreshEntitlement()
                }
            }
        }
    }

    private enum StoreError: Error { case failedVerification }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
