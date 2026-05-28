import SwiftUI

/// Ofis eşya mağazası — kategorili katalog + SEPET.
/// Oyuncu birden çok eşyayı sepete ekler, toplamı görür, tek tıkla satın alır.
struct ItemShopView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    @Environment(\.dismiss) private var dismiss
    @State private var category: ItemCategory = .workstation
    /// itemId → sepetteki adet. UI tüm hesaplamalarda buradan okur.
    @State private var cart: [Int: Int] = [:]

    private var items: [OfficeItemDef] {
        Balance.officeItems.filter { $0.category == category }
    }

    // MARK: Sepet özetleri

    private var cartItemCount: Int { cart.values.reduce(0, +) }
    private var cartTotalCost: Double {
        cart.reduce(0) { acc, kv in acc + (Balance.officeItem(kv.key)?.cost ?? 0) * Double(kv.value) }
    }
    private var cartTotalArea: Double {
        cart.reduce(0) { acc, kv in acc + (Balance.officeItem(kv.key)?.areaM2 ?? 0) * Double(kv.value) }
    }
    /// Sepet bir bütün olarak alınabilir mi (nakit + alan kontrolü).
    private var cartCheckoutable: Bool {
        cartItemCount > 0
            && cartTotalCost <= model.cash
            && cartTotalArea <= model.freeAreaM2
    }
    /// Bir eşyanın sepete bir adet daha eklenebilir mi (alan + evre + cüzdan).
    private func canAddToCart(_ item: OfficeItemDef) -> Bool {
        guard model.isItemUnlocked(item.id) else { return false }
        let projectedArea = cartTotalArea + item.areaM2
        let projectedCost = cartTotalCost + item.cost
        return projectedArea <= model.freeAreaM2 && projectedCost <= model.cash
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                categoryTabs
                ScrollView {
                    LazyVStack(spacing: Space.s2) {
                        ForEach(items) { item in
                            ItemCard(theme: theme, model: model, item: item,
                                     quantity: cart[item.id] ?? 0,
                                     canAdd: canAddToCart(item)) {
                                add(item)
                            } onRemove: {
                                remove(item)
                            }
                        }
                        // Sepet bar açıkken alt boşluk — son kart bar arkasında kalmasın.
                        Spacer(minLength: cartItemCount > 0 ? 110 : 30)
                    }
                    .padding(.horizontal, Space.s4)
                    .padding(.top, Space.s3)
                }
            }

            // Sepet bar: yalnızca eşya varken görünür, alttan yaylı kayar.
            if cartItemCount > 0 {
                CartBar(theme: theme,
                        count: cartItemCount,
                        totalCost: cartTotalCost,
                        totalArea: cartTotalArea,
                        affordable: cartTotalCost <= model.cash,
                        roomy: cartTotalArea <= model.freeAreaM2,
                        canCheckout: cartCheckoutable,
                        onClear: { withAnimation(Motion.snappy) { cart.removeAll() } },
                        onCheckout: { checkout() })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.snappy, value: cartItemCount)
    }

    // MARK: Sepet işlemleri

    private func add(_ item: OfficeItemDef) {
        Haptics.selection()
        withAnimation(Motion.snappy) { cart[item.id, default: 0] += 1 }
    }
    private func remove(_ item: OfficeItemDef) {
        Haptics.selection()
        withAnimation(Motion.snappy) {
            let n = (cart[item.id] ?? 0) - 1
            if n <= 0 { cart.removeValue(forKey: item.id) } else { cart[item.id] = n }
        }
    }

    /// Sepeti satın al: her eşyayı sırayla `model.buyItem` ile dene; başarısız olanı atla.
    /// Çoklu alımda her satır kendi nakit/alan kontrolünü tekrar yapar (atomik garanti yok ama
    /// sepet özeti zaten önceden kabaca kontrol etti; tick arasında değişen değerler için
    /// son kontrol model katmanında).
    private func checkout() {
        Haptics.tap()
        var bought = 0
        for (id, qty) in cart {
            for _ in 0..<qty {
                if model.buyItem(id) { bought += 1 } else { break }
            }
        }
        if bought > 0 {
            withAnimation(Motion.snappy) { cart.removeAll() }
        }
    }

    // MARK: Üst çubuk + kategori sekmeleri

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("MAĞAZA").font(.eyebrow).foregroundStyle(theme.accent)
                Text("\(Int(model.freeAreaM2)) m² boş · \(BigNumber.money(model.cash))")
                    .font(.numberS).foregroundStyle(theme.subtle)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(theme.surfaceHigh, in: Circle())
                    .foregroundStyle(theme.text)
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, Space.s4).padding(.top, Space.s4).padding(.bottom, Space.s2)
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s2) {
                ForEach(ItemCategory.allCases, id: \.self) { cat in
                    let selected = cat == category
                    Button {
                        Haptics.selection()
                        withAnimation(Motion.smooth) { category = cat }
                    } label: {
                        Text(cat.title)
                            .font(.appText(13, selected ? .bold : .medium))
                            .padding(.horizontal, Space.s3).padding(.vertical, Space.s2)
                            .background(selected ? Color(hex: cat.colorHex).opacity(0.25) : theme.surfaceHigh,
                                        in: Capsule())
                            .overlay(Capsule().stroke(selected ? Color(hex: cat.colorHex) : .clear, lineWidth: 1))
                            .foregroundStyle(selected ? Color(hex: cat.colorHex) : theme.subtle)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, Space.s4).padding(.vertical, Space.s2)
        }
    }
}

// MARK: - Tek eşya kartı (sepet adetli +/− stepper'lı)

/// Bir eşya satırı: ikon, ad, etki rozetleri, fiyat + sepet stepper'ı.
/// Adet 0 iken sadece "+" gösterilir; adet ≥1 iken "−  N  +" rozet seti gösterilir.
private struct ItemCard: View {
    var theme: Theme
    @ObservedObject var model: GameModel
    let item: OfficeItemDef
    let quantity: Int
    let canAdd: Bool
    var onAdd: () -> Void
    var onRemove: () -> Void

    private var color: Color { Color(hex: item.category.colorHex) }
    private var owned: Int { model.ownedCount(item.id) }
    private var locked: Bool { !model.isItemUnlocked(item.id) }

    var body: some View {
        PanelCard(theme: theme) {
            HStack(spacing: Space.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.s)
                        .fill(color.opacity(0.18)).frame(width: 46, height: 46)
                    Image(systemName: item.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: Space.s1) {
                        Text(item.name).font(.appText(15, .bold)).foregroundStyle(theme.text)
                        if owned > 0 {
                            Text("×\(owned)").font(.numberXS).foregroundStyle(color)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(color.opacity(0.2), in: Capsule())
                        }
                    }
                    effectsLine
                }
                Spacer()
                cartControl
            }
        }
    }

    /// Etki rozetleri: m² / koltuk / moral / üretim / itibar.
    private var effectsLine: some View {
        HStack(spacing: Space.s2) {
            badge(icon: "ruler", "\(Int(item.areaM2)) m²", theme.subtle)
            if item.seatCapacity > 0 { badge(icon: "chair.fill", "+\(item.seatCapacity)", Palette.success) }
            if item.moraleBonus > 0 { badge(icon: "face.smiling", "+\(Int(item.moraleBonus))", Palette.warning) }
            if item.outputBonus > 0 { badge(icon: "bolt.fill", "+%\(Int(item.outputBonus * 100))", theme.accent) }
            if item.reputationBonus > 0 { badge(icon: "star.fill", "+\(Int(item.reputationBonus))", Palette.gold) }
        }
    }

    private func badge(icon: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 8, weight: .bold))
            Text(text).font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(tint)
    }

    /// Sağ taraf: kilitli → kilit etiketi; aksi halde fiyat + sepet kontrolleri.
    @ViewBuilder private var cartControl: some View {
        if locked {
            statusLabel(icon: Icons.Screen.locked,
                        text: Balance.stages[item.unlockStage].name,
                        tint: theme.textQuaternary)
        } else if quantity == 0 {
            // Boş sepet: tek "Ekle" butonu, fiyat üstte.
            Button(action: onAdd) {
                VStack(spacing: 1) {
                    Text(BigNumber.money(item.cost)).font(.numberS)
                    HStack(spacing: 2) {
                        Image(systemName: "plus")
                        Text("Ekle")
                    }
                    .font(.system(size: 9, weight: .bold)).opacity(0.85)
                }
                .foregroundStyle(canAdd ? .white : theme.textQuaternary)
                .frame(width: 76, height: 44)
                .background(canAdd ? color : theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.s))
            }
            .buttonStyle(.pressable)
            .disabled(!canAdd)
        } else {
            // Sepette: stepper "− N +".
            HStack(spacing: 0) {
                stepperButton(icon: "minus", enabled: true, action: onRemove)
                Text("\(quantity)")
                    .font(.numberS).foregroundStyle(.white)
                    .frame(width: 26)
                    .contentTransition(.numericText())
                stepperButton(icon: "plus", enabled: canAdd, action: onAdd)
            }
            .frame(height: 44)
            .background(color, in: RoundedRectangle(cornerRadius: Radius.s))
        }
    }

    private func stepperButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(enabled ? .white : Color.white.opacity(0.35))
                .frame(width: 28, height: 44)
        }
        .buttonStyle(.pressable)
        .disabled(!enabled)
    }

    private func statusLabel(icon: String, text: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold))
            Text(text).font(.system(size: 8, weight: .bold))
        }
        .foregroundStyle(tint)
        .frame(width: 76, height: 44)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.s))
    }
}

// MARK: - Sepet alt çubuğu (sticky)

/// Sepet özetini + tek tık "Satın Al" eylemini gösteren alttan kayan sticky bar.
/// Sepet boşsa görünmez. Nakit ya da alan yetmiyorsa uyarı + buton disabled.
private struct CartBar: View {
    var theme: Theme
    let count: Int
    let totalCost: Double
    let totalArea: Double
    let affordable: Bool
    let roomy: Bool
    let canCheckout: Bool
    var onClear: () -> Void
    var onCheckout: () -> Void

    private var statusLine: String {
        if !affordable { return "Nakit yetmiyor" }
        if !roomy { return "Alan yetmiyor" }
        return "\(count) eşya · \(Int(totalArea)) m²"
    }
    private var statusTint: Color {
        if !affordable || !roomy { return Palette.danger }
        return theme.subtle
    }

    var body: some View {
        HStack(spacing: Space.s3) {
            // Sepet ikonu + sayaç (oyunsu rozet — sepetteki adet rozeti)
            ZStack(alignment: .topTrailing) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 38, height: 38)
                    .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.s))
                Text("\(count)")
                    .font(.appNumber(10, .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Palette.danger, in: Capsule())
                    .offset(x: 6, y: -6)
            }

            // Tutar + durum (yeterli mi).
            VStack(alignment: .leading, spacing: 1) {
                Text(BigNumber.money(totalCost))
                    .font(.numberL).foregroundStyle(theme.text)
                    .contentTransition(.numericText())
                Text(statusLine)
                    .font(.numberXS).foregroundStyle(statusTint)
            }

            Spacer()

            // Sepeti temizle (ikincil).
            Button(action: onClear) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(theme.subtle)
                    .frame(width: 38, height: 38)
                    .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.s))
            }
            .buttonStyle(.pressable)

            // Satın al CTA.
            Button(action: onCheckout) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Text("Satın Al")
                }
                .font(.bodyL)
                .foregroundStyle(canCheckout ? .white : theme.textQuaternary)
                .padding(.horizontal, Space.s4)
                .frame(height: 44)
                .background(canCheckout ? theme.accent : theme.surfaceHigh,
                            in: RoundedRectangle(cornerRadius: Radius.s))
            }
            .buttonStyle(.pressable)
            .disabled(!canCheckout)
        }
        .padding(.horizontal, Space.s3).padding(.vertical, Space.s2)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(theme.hairline))
        .padding(.horizontal, Space.s3)
        .padding(.bottom, Space.s3)
    }
}
