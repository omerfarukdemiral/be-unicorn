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
        }
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
                        .stroke(theme.hairline, lineWidth: 1)

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
            .frame(maxHeight: .infinity)
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
                    Capsule().fill(theme.hairline)
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: geo.size.width * CGFloat(usage))
                }
            }
            .frame(height: 4)
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
    /// Bu koltuğu sahiplenen üyeler (en fazla seatCapacity adet). Avatarlar üst sağ köşede.
    var occupants: [TeamMember] = []

    private var color: Color { Color(hex: cell.def.category.colorHex) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
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

            if !occupants.isEmpty {
                occupantBadges.padding(3)
            }
        }
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.s))
        .overlay(RoundedRectangle(cornerRadius: Radius.s).stroke(color.opacity(0.4), lineWidth: 1))
    }

    /// Avatar yığını: en fazla 2 görünür başharf rozeti, fazlası "+N".
    private var occupantBadges: some View {
        let visible = Array(occupants.prefix(2))
        let extra = max(0, occupants.count - visible.count)
        return HStack(spacing: -3) {
            ForEach(visible) { m in
                Text(m.initials)
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 14, height: 14)
                    .background(deptColor(for: m.deptIndex), in: Circle())
                    .overlay(Circle().stroke(Palette.gold, lineWidth: m.isFounder ? 1 : 0))
                    .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 0.5))
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.system(size: 6, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 14, height: 14)
                    .background(Color.black.opacity(0.55), in: Circle())
            }
        }
    }

    private func deptColor(for deptIndex: Int) -> Color {
        guard deptIndex >= 0 && deptIndex < Balance.departments.count else { return .gray }
        return Color(hex: Balance.departments[deptIndex].colorHex)
    }
}

/// Üyeleri ofisteki koltuklu eşyalara sırayla dağıt. Sıra: önce kurucu (her zaman ilk
/// koltukta), sonra mevcut hire sırasıyla diğer üyeler. Yalnızca seatCapacity > 0
/// olan cell'ler oturma yeri olarak kullanılır. Çıktı: `cell index → o cell'in sakinleri`.
private func assignMembersToSeats(cells: [PlanCell], members: [TeamMember])
    -> [Int: [TeamMember]] {
    var queue: [TeamMember] = []
    if let founder = members.first(where: { $0.isFounder }) { queue.append(founder) }
    queue.append(contentsOf: members.filter { !$0.isFounder })

    var assignments: [Int: [TeamMember]] = [:]
    for (idx, cell) in cells.enumerated() {
        let seats = cell.def.seatCapacity
        guard seats > 0, !queue.isEmpty else { continue }
        var here: [TeamMember] = []
        for _ in 0..<seats {
            guard !queue.isEmpty else { break }
            here.append(queue.removeFirst())
        }
        assignments[idx] = here
    }
    return assignments
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
