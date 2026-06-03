import SwiftUI

/// 2D top-down ofis krokisi (SwiftUI, sahne/3D YOK).
/// m²'ye orantılı plan çerçevesi + hafif grid + sahip olunan eşyaların otomatik grid yerleşimi.
struct FloorPlanView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    /// Tuval genişliği — hücre boyutu (cellSize) ve buna bağlı tuval yüksekliği bundan
    /// türetilir. Arka plandaki widthReader ölçer; layout absolute-offset ile dizilir.
    @State private var canvasWidth: CGFloat = 0

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
        let cols = adaptiveColumns(width: canvasWidth)
        let spacing: CGFloat = 12   // ferah: daha bol boşluk
        // Genişlik ölçülene dek makul bir taban; ölçülünce kesin değer.
        let cellSize = canvasWidth > 0
            ? (canvasWidth - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            : 100
        let rows = cells.isEmpty ? 0 : (cells.count + cols - 1) / cols
        // İçeriğe göre KESİN minimum tuval yüksekliği. Eski maxHeight:.infinity tuvali
        // ekran kalabalıkken hücre boyunun altına sıkıştırıp doluluk bar'ı + etiketlerle
        // ÖRTÜŞTÜRÜYORDU. minHeight tabanı bu bindirmeyi tamamen kaldırır; fazla dikey alan
        // varsa tuval büyür (boş m² hissi — temaya uygun), bar her zaman ALTTA kalır.
        let gridHeight: CGFloat = cells.isEmpty
            ? 132
            : CGFloat(rows) * cellSize + CGFloat(max(0, rows - 1)) * spacing + 6

        return VStack(spacing: Space.s2) {
            ZStack(alignment: .topLeading) {
                // Sade zemin — yoğun blueprint ızgarası KALDIRILDI; tek sakin yüzey.
                RoundedRectangle(cornerRadius: Radius.m)
                    .fill(Color.black.opacity(0.12))

                if cells.isEmpty {
                    emptyHint
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Ekibi masalara dağıt → masalarda canlı avatar rozetleri (artık boş değil).
                    let seated = assignMembersToSeats(cells: cells, members: model.state.members)
                    // Akış/grid packing: katalog sırasına göre soldan-sağa, satır satır.
                    ForEach(Array(cells.enumerated()), id: \.offset) { idx, cell in
                        let row = idx / cols
                        let col = idx % cols
                        ItemTile(cell: cell, theme: theme, size: cellSize,
                                 occupants: seated[idx] ?? [],
                                 imminent: model.decisionImminent,
                                 onTap: {
                                     // Tap-to-do: çalışan masaya dokun → ekibi dürtükle, kararı öne çek.
                                     if model.nudgeTeam() { Haptics.selection() } else { Haptics.tap() }
                                 })
                            .frame(width: cellSize, height: cellSize)
                            .offset(x: CGFloat(col) * (cellSize + spacing),
                                    y: CGFloat(row) * (cellSize + spacing) + 6)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
            }
            .frame(minHeight: gridHeight, maxHeight: .infinity)
            .background(widthReader)
            .clipShape(RoundedRectangle(cornerRadius: Radius.m))
            .animation(Motion.snappy, value: cells.count)

            // Doluluk bar'ı.
            occupancyBar(usage: usage)

            // Tap-to-do ipucu — yalnız ekip oturmuşken, sade bir fısıltı.
            if !cells.isEmpty && !model.state.members.isEmpty {
                tapHint
            }
        }
    }

    /// Çalışan masalara dokunmanın ne işe yaradığını anlatan ince ipucu satırı.
    private var tapHint: some View {
        HStack(spacing: Space.s1) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 9, weight: .semibold))
            Text("Çalışan masalara dokun → ekibi dürtükle, kararı öne çek")
                .font(.appText(10, .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(theme.subtle)
    }

    /// Tuval genişliğini ölçüp `canvasWidth`'e yazan görünmez arka plan.
    private var widthReader: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { canvasWidth = geo.size.width }
                .onChange(of: geo.size.width) { _, w in canvasWidth = w }
        }
    }

    private func adaptiveColumns(width: CGFloat) -> Int {
        // Ferah yerleşim: büyük kartlar, az sütun (sıkışık 5-6 grid YOK).
        let n = cells.count
        if n <= 6 { return 3 }
        return 4   // çok eşyada bile en fazla 4 sütun → kartlar büyük kalır
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
    /// Bir sonraki karar "demleniyor" mu — dolu masa accent parıltısıyla dokunmaya davet eder.
    var imminent: Bool = false
    /// Tap-to-do: çalışan masaya dokunma eylemi (nil ise masa dekoratif kalır).
    var onTap: (() -> Void)? = nil

    @State private var tapPulse = false

    private var catColor: Color { Color(hex: cell.def.category.colorHex) }
    /// Bu masada biri oturuyor mu — dolu masa "canlı" (parlak), boş masa sönük görünür.
    private var occupied: Bool { !occupants.isEmpty }
    /// Yalnızca çalışan masalar dürtüklenebilir (boş eşya/dekorasyon dokunmaz).
    private var tappable: Bool { occupied && onTap != nil }

    var body: some View {
        tileBody
            .contentShape(RoundedRectangle(cornerRadius: Radius.m))
            .scaleEffect(tapPulse ? 0.93 : 1)
            .animation(Motion.snappy, value: tapPulse)
            .onTapGesture {
                guard tappable else { return }
                onTap?()
                withAnimation(Motion.snappy) { tapPulse = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    withAnimation(Motion.snappy) { tapPulse = false }
                }
            }
    }

    private var tileBody: some View {
        ZStack(alignment: .topTrailing) {
            // Sade tek-ton: ikon accent (renk yarışı yok), kategori sadece küçük nokta.
            VStack(spacing: 4) {
                Image(systemName: cell.def.icon)
                    .font(.system(size: size * 0.30, weight: .semibold))
                    .foregroundStyle(occupied ? theme.accent : theme.accent.opacity(0.5))
                    .frame(height: size * 0.40)
                Text(cell.def.name)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(occupied ? theme.textSecondary : theme.subtle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Kategori kimliği: sade küçük nokta (sol-üst) — renk yarışı yaratmaz.
            Circle().fill(catColor.opacity(0.8)).frame(width: 5, height: 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(6)

            // Dolu masada avatarlar hafifçe "nefes alır" — masaya item id'sine göre fazlanmış
            // (senkron değil) → ofis canlı görünür, statik ikon-grid hissi kırılır.
            if occupied {
                TimelineView(.animation) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    let phase = Double(cell.itemID * 7 + cell.instance * 3)
                    let breath = 1 + 0.035 * sin(t * 1.6 + phase)
                    occupantBadges
                        .scaleEffect(breath, anchor: .topTrailing)
                        .padding(5)
                }
            }
        }
        // Sade nötr yüzey; dolu masa hafif accent ısısı + ince kenarlık. Karar demlenirken
        // (imminent) çalışan masalar bir tık daha parlar → dokunmaya sessiz davet.
        .background(
            RoundedRectangle(cornerRadius: Radius.m)
                .fill(occupied ? theme.accent.opacity(imminent ? 0.16 : 0.08) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m)
                .stroke(occupied ? theme.accent.opacity(imminent ? 0.6 : 0.35) : theme.hairline,
                        lineWidth: occupied && imminent ? 1.5 : 1)
        )
        .animation(Motion.smooth, value: imminent)
        // Dolu masada nabız atan yeşil "aktif/çalışıyor" noktası (sol-alt köşe).
        .overlay(alignment: .bottomLeading) {
            if occupied {
                TimelineView(.animation) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    let pulse = 0.5 + 0.5 * sin(t * 2.2 + Double(cell.itemID))
                    Circle()
                        .fill(Palette.success)
                        .frame(width: 6, height: 6)
                        .opacity(0.4 + 0.5 * pulse)
                        .shadow(color: Palette.success.opacity(0.6 * pulse), radius: 3)
                        .padding(7)
                }
            }
        }
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
