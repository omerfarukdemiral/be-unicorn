import SwiftUI
import StoreKit

/// B6 — Series A yumuşak duvarı. Seed turuna (Stage 2) kadar oyun tam oynanır;
/// Series A turunu toplamak Tam Sürüm gerektirir.
///
/// Kural-0: Yalnızca BUGÜN sevk edilmiş içerik vaat edilir —
/// - Seed sonrası tüm funding turları (Series A→B→C→Unicorn) ekonomi içinde var.
/// - Geç-oyun karar kartları (IPO, M&A, halka arz, çift sınıflı hisse vb.) sevk edildi.
/// - Defter dersleri + karar-sonrası ders köprüleri sevk edildi.
/// - "4 strateji yolu" = oyunun çoklu-strateji ekonomisi (Bootstrap / VC-Roket /
///   Niş Uzman / Platform) — hepsi aynı hedefe (Unicorn) farklı patikalardan varır.
///   Bu ekonomi sevk edildi; runtime "arketip rozeti" VAAT EDİLMEZ.
///
/// GameModel'den bağımsız: yalnızca StoreManager + iki callback alır.
struct PaywallView: View {
    @ObservedObject var store: StoreManager
    var theme: Theme

    /// Satın alma/geri yükleme ile Tam Sürüm açıldığında (entitlement true) çağrılır —
    /// ContentView bunu Series A turunu onaylamak için kullanır.
    let onUnlocked: () -> Void
    /// "Şimdilik Seed'de Devam" — duvarı kapat, Stage 2 oynanmaya devam.
    let onDismiss: () -> Void

    @State private var appeared = false

    private var priceText: String { store.displayPrice ?? "₺99" }   // lansman fiyatı (fallback)

    var body: some View {
        ZStack {
            // Derin prestij zemini — funding kutlamasıyla aynı dil, mor unicorn ışıltısı.
            Color(hex: "12101F").opacity(0.95).ignoresSafeArea()
            RadialGradient(colors: [Palette.unicorn.opacity(0.20), .clear],
                           center: .top, startRadius: 20, endRadius: 460)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: Space.s4) {
                    header
                    valueList
                    purchaseBlock
                    footerLinks
                }
                .padding(Space.s5)
                .frame(maxWidth: 380)
                .frame(maxWidth: .infinity)
            }
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            Haptics.medium()
            withAnimation(Motion.bouncy) { appeared = true }
        }
        .onChange(of: store.isFullVersion) { _, owned in
            if owned { onUnlocked() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Space.s3) {
            ZStack {
                UnicornHero(accent: Palette.unicorn, size: 96)
            }
            .frame(height: 96)

            Text("SERIES A KAPISI")
                .font(.eyebrow).tracking(1.5)
                .foregroundStyle(Palette.gold)
                .padding(.horizontal, Space.s3).padding(.vertical, Space.s1)
                .background(Palette.gold.opacity(0.13), in: Capsule())
                .overlay(Capsule().stroke(Palette.gold.opacity(0.4), lineWidth: 1))

            Text("Seed turunu kapattın.\nGerisi Tam Sürüm'de.")
                .font(.titleL)
                .foregroundStyle(theme.text)
                .multilineTextAlignment(.center)

            Text("Garajdan buraya kadar olan yolu ücretsiz oynadın. Series A'dan Unicorn'a uzanan yolculuğun tamamını tek seferlik bir ödemeyle aç — abonelik yok, reklam yok.")
                .font(.appText(13.5, .medium))
                .foregroundStyle(theme.subtle)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Değer listesi (yalnızca sevk edilmiş içerik)

    private var valueList: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            valueRow(icon: "chart.line.uptrend.xyaxis",
                     title: "Series A → Unicorn",
                     body: "Series A, B, C ve Unicorn turlarının tamamı. Değerlemeni 1 milyar dolara taşı.")
            valueRow(icon: "rectangle.stack.fill",
                     title: "Geç-oyun karar kartları",
                     body: "Halka arz, M&A, çift sınıflı hisse, antitröst, kurucu-CEO geçişi — büyük şirket dilemmaları.")
            valueRow(icon: "book.closed.fill",
                     title: "Defter dersleri büyür",
                     body: "Her kararının ardındaki gerçek startup dersi. Suçlamasız koçluk, tek doğru cevap yok.")
            valueRow(icon: "arrow.triangle.branch",
                     title: "4 strateji yolu",
                     body: "Bootstrap, VC-roketi, niş uzman ya da geniş platform — aynı zirveye farklı patikalardan.")
        }
        .padding(Space.s4)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Radius.m)
            .stroke(Palette.unicorn.opacity(0.22), lineWidth: 1))
    }

    private func valueRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: Space.s3) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.numberM).foregroundStyle(theme.text)
                Text(body).font(.labelText).foregroundStyle(theme.subtle)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Satın alma bloğu

    private var purchaseBlock: some View {
        VStack(spacing: Space.s2) {
            Button {
                Haptics.tap()
                Task { await store.purchaseFullVersion() }
            } label: {
                HStack(spacing: Space.s2) {
                    if store.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Tam Sürüm'ü Aç").font(.bodyL)
                        Text("· \(priceText)")
                            .font(.numberM).foregroundStyle(.white.opacity(0.9))
                    }
                }
                .modifier(ButtonChrome(bg: Palette.unicorn, fg: .white,
                                       glow: Palette.unicorn, height: AppButton.height))
            }
            .buttonStyle(.pressable)
            .disabled(store.isLoading)

            Text("Tek seferlik ödeme · abonelik yok · reklamsız")
                .font(.labelText).foregroundStyle(theme.subtle)

            Button { Haptics.selection(); onDismiss() } label: {
                Text("Şimdilik Seed'de devam et")
                    .font(.appText(13, .semibold))
                    .foregroundStyle(theme.subtle)
                    .padding(.vertical, Space.s2)
            }
            .buttonStyle(.plain)

            if let err = store.lastError {
                Text(err)
                    .font(.labelText)
                    .foregroundStyle(Palette.warning)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.s1)
            }
        }
    }

    // MARK: - Footer (geri yükle + yasal)

    private var footerLinks: some View {
        VStack(spacing: Space.s2) {
            Button {
                Haptics.selection()
                Task { await store.restorePurchases() }
            } label: {
                Text("Satın Almaları Geri Yükle")
                    .font(.appText(12.5, .semibold))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(store.isLoading)

            Text("Satın aldıysan başka bir cihazda da aynı Apple Kimliği ile geri yükleyebilirsin.")
                .font(.appText(10.5, .medium))
                .foregroundStyle(theme.subtle.opacity(0.8))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Space.s1)
    }
}
