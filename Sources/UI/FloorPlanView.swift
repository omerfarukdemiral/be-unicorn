import SwiftUI

/// 2D top-down ofis krokisi (SwiftUI, sahne/3D YOK).
/// m²'ye orantılı plan çerçevesi + hafif grid + sahip olunan eşyaların otomatik grid yerleşimi.
struct FloorPlanView: View {
    @ObservedObject var model: GameModel
    var theme: Theme

    /// Krokide gösterilecek hücreler: her sahip olunan eşya adedi başına bir hücre.
    private var cells: [PlanCell] {
        var result: [PlanCell] = []
        // Katalog id sırasına göre dolaş (kalıcı/stabil yerleşim).
        for item in Balance.officeItems {
            let n = model.ownedCount(item.id)
            guard n > 0 else { continue }
            for k in 0..<n {
                result.append(PlanCell(itemID: item.id, instance: k, def: item))
            }
        }
        return result
    }

    var body: some View {
        PanelCard(theme: theme) {
            VStack(alignment: .leading, spacing: Space.s2) {
                header
                planCanvas
                legend
            }
        }
    }

    // MARK: Üst başlık + metrikler

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.officeName.uppercased())
                    .font(.eyebrow)
                    .foregroundStyle(theme.accent)
                Text("Kroki").font(.titleM).foregroundStyle(theme.text)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                metricRow(icon: Icons.Metric.office,
                          text: "\(Int(model.usedAreaM2)) / \(Int(model.totalAreaM2)) m²",
                          tint: theme.accent)
                metricRow(icon: "chair.fill",
                          text: "\(model.seatsUsed) / \(model.seatCapacity) koltuk",
                          tint: model.seatsFull ? Palette.warning : Palette.success)
            }
            speedButton
        }
    }

    /// Kroki üstündeki köşe hız kontrolü: 1× / 2× / 3× — Ofis tepesindeki boşluğu temizler.
    private var speedButton: some View {
        let active = model.speed > 1
        return Button { Haptics.selection(); model.cycleSpeed() } label: {
            HStack(spacing: 3) {
                Image(systemName: "forward.fill").font(.system(size: 11, weight: .bold))
                Text("\(Int(model.speed))×").font(.numberS)
            }
            .foregroundStyle(active ? .white : theme.accent)
            .padding(.horizontal, Space.s2).frame(height: 28)
            .background(active ? theme.accent : theme.surfaceHigh, in: Capsule())
            .overlay(Capsule().stroke(theme.accent.opacity(active ? 0 : 0.5), lineWidth: 1))
            .shadow(color: active ? theme.accent.opacity(0.45) : .clear, radius: active ? 8 : 0, y: 2)
        }
        .buttonStyle(.pressable)
    }

    private func metricRow(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: Space.s1) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(text).font(.numberS)
        }
        .foregroundStyle(tint)
    }

    // MARK: Plan tuvali — m²'ye orantılı çerçeve + grid + eşya hücreleri

    private var planCanvas: some View {
        let usage = model.totalAreaM2 > 0 ? min(1, model.usedAreaM2 / model.totalAreaM2) : 0
        return VStack(spacing: Space.s2) {
            GeometryReader { geo in
                let cols = adaptiveColumns(width: geo.size.width)
                let spacing: CGFloat = 8
                let cellSize = (geo.size.width - spacing * CGFloat(cols - 1)) / CGFloat(cols)

                ZStack(alignment: .topLeading) {
                    // Mimari kroki arka planı: ince accent çerçeve + hafif grid.
                    RoundedRectangle(cornerRadius: Radius.m)
                        .fill(Color.black.opacity(0.18))
                    GridBackground(spacing: 22)
                        .stroke(theme.hairline, lineWidth: 0.5)
                    RoundedRectangle(cornerRadius: Radius.m)
                        .stroke(theme.accent.opacity(0.5), lineWidth: 1.5)

                    if cells.isEmpty {
                        emptyHint
                            .frame(width: geo.size.width, height: geo.size.height)
                    } else {
                        // Akış/grid packing: katalog sırasına göre soldan-sağa, satır satır.
                        ForEach(Array(cells.enumerated()), id: \.offset) { idx, cell in
                            let row = idx / cols
                            let col = idx % cols
                            ItemTile(cell: cell, theme: theme, size: cellSize)
                                .frame(width: cellSize, height: cellSize)
                                .offset(x: CGFloat(col) * (cellSize + spacing),
                                        y: CGFloat(row) * (cellSize + spacing) + 6)
                                .transition(.scale(scale: 0.4).combined(with: .opacity))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.m))
            }
            .frame(height: 200)
            .animation(Motion.snappy, value: cells.count)

            // Doluluk bar'ı.
            occupancyBar(usage: usage)
        }
    }

    private func adaptiveColumns(width: CGFloat) -> Int {
        // Çok eşya oldukça daha sıkı grid; az eşyada ferah.
        let n = cells.count
        if n <= 6 { return 4 }
        if n <= 16 { return 5 }
        return 6
    }

    private var emptyHint: some View {
        VStack(spacing: Space.s2) {
            Image(systemName: "square.dashed")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(theme.textQuaternary)
            Text("Boş ofis. Mağazadan masa ve eşya al.")
                .font(.bodyText)
                .foregroundStyle(theme.subtle)
        }
    }

    private func occupancyBar(usage: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.surfaceHigh)
                    Capsule()
                        .fill(LinearGradient(colors: [theme.accent.opacity(0.7), theme.accent],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(usage))
                }
            }
            .frame(height: 6)
            Text("Alan doluluğu %\(Int(usage * 100))")
                .font(.numberXS)
                .foregroundStyle(theme.subtle)
        }
    }

    // MARK: Kategori lejantı (renk kodları)

    private var legend: some View {
        let used = Set(cells.map { $0.def.category })
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s2) {
                ForEach(ItemCategory.allCases, id: \.self) { cat in
                    let active = used.contains(cat)
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: cat.colorHex)).frame(width: 7, height: 7)
                        Text(cat.title).font(.appText(10, .semibold))
                    }
                    .opacity(active ? 1 : 0.35)
                    .padding(.horizontal, Space.s2).padding(.vertical, 4)
                    .background(theme.surfaceHigh, in: Capsule())
                    .foregroundStyle(theme.textSecondary)
                }
            }
        }
    }
}

/// Krokide tek bir eşya örneğini temsil eden veri.
private struct PlanCell {
    let itemID: Int
    let instance: Int
    let def: OfficeItemDef
}

/// Plan içindeki tek eşya hücresi: yumuşak kart + SF Symbol + ad.
private struct ItemTile: View {
    let cell: PlanCell
    let theme: Theme
    let size: CGFloat

    private var color: Color { Color(hex: cell.def.category.colorHex) }

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: cell.def.icon)
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(color)
                .frame(height: size * 0.42)
            Text(cell.def.name)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.s))
        .overlay(RoundedRectangle(cornerRadius: Radius.s).stroke(color.opacity(0.4), lineWidth: 1))
    }
}

/// Hafif grid arka plan çizgileri (mimari kroki hissi).
private struct GridBackground: Shape {
    let spacing: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var x: CGFloat = spacing
        while x < rect.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: rect.height)); x += spacing }
        var y: CGFloat = spacing
        while y < rect.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: rect.width, y: y)); y += spacing }
        return p
    }
}
