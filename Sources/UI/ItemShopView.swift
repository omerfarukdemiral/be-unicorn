import SwiftUI

/// Ofis eşya mağazası — kategorili katalog. Satın al → krokiye eklenir + math güncellenir.
struct ItemShopView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    @Environment(\.dismiss) private var dismiss
    @State private var category: ItemCategory = .workstation

    private var items: [OfficeItemDef] {
        Balance.officeItems.filter { $0.category == category }
    }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                categoryTabs
                ScrollView {
                    LazyVStack(spacing: Space.s2) {
                        ForEach(items) { item in
                            ItemCard(model: model, theme: theme, item: item)
                        }
                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, Space.s4)
                    .padding(.top, Space.s3)
                }
            }
        }
    }

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

/// Tek eşya kartı: ikon, ad, etkiler, m², maliyet + alınabilirlik durumu.
private struct ItemCard: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let item: OfficeItemDef

    private var color: Color { Color(hex: item.category.colorHex) }
    private var owned: Int { model.ownedCount(item.id) }
    private var locked: Bool { !model.isItemUnlocked(item.id) }
    private var noArea: Bool { !locked && model.freeAreaM2 < item.areaM2 }
    private var noCash: Bool { !locked && !noArea && model.cash < item.cost }
    private var canBuy: Bool { model.canBuyItem(item.id) }

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
                buyButton
            }
        }
    }

    /// Etki rozetleri: koltuk / moral / üretim / itibar / m².
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

    @ViewBuilder private var buyButton: some View {
        if locked {
            statusLabel(icon: Icons.Screen.locked,
                        text: Balance.stages[item.unlockStage].name,
                        tint: theme.textQuaternary)
        } else {
            Button {
                Haptics.tap()
                withAnimation(Motion.snappy) { model.buyItem(item.id) }
            } label: {
                VStack(spacing: 1) {
                    Text(BigNumber.money(item.cost)).font(.numberS)
                    Text(noArea ? "alan yok" : (noCash ? "nakit yok" : "Al"))
                        .font(.system(size: 8, weight: .bold)).opacity(0.8)
                }
                .foregroundStyle(canBuy ? .white : theme.textQuaternary)
                .frame(width: 76, height: 44)
                .background(canBuy ? color : theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.s))
            }
            .buttonStyle(.pressable)
            .disabled(!canBuy)
        }
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
