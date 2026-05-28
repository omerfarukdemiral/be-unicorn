import SwiftUI

/// Ekip ekranı: departman bazlı işe alım / çıkarma, maaş & çıktı bilgisi.
struct TeamPanel: View {
    @ObservedObject var model: GameModel
    var theme: Theme

    var body: some View {
        ScrollView {
            VStack(spacing: Space.s3) {
                header
                ForEach(Balance.departments) { dept in
                    DeptRow(model: model, theme: theme, dept: dept)
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal, Space.s4)
            .padding(.top, Space.s3)
        }
    }

    private var header: some View {
        PanelCard(theme: theme) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ekip").font(.titleM)
                        .foregroundStyle(theme.text)
                    Text("\(model.totalHeadcount) kişi · maaş \(BigNumber.money(model.payrollPerMonth))/ay")
                        .font(.bodyText)
                        .foregroundStyle(theme.subtle)
                    // Koltuk doluluk — yeni gerçek işe alım kısıtı.
                    HStack(spacing: Space.s1) {
                        Image(systemName: "chair.fill").font(.system(size: 10, weight: .semibold))
                        Text("\(model.seatsUsed)/\(model.seatCapacity) koltuk dolu")
                            .font(.numberXS)
                    }
                    .foregroundStyle(model.seatsFull ? Palette.warning : Palette.success)
                }
                Spacer()
                // Ofis adı: bina ikonu + metin
                HStack(spacing: Space.s1) {
                    Image(systemName: Icons.Metric.office)
                        .font(.system(size: 11, weight: .semibold))
                    Text(model.officeName)
                        .font(.appText(12, .bold))
                }
                .foregroundStyle(theme.accent)
            }
        }
    }
}

private struct DeptRow: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let dept: DepartmentDef
    /// Aktif atama popover'ı için seçili üye (nil → kapalı).
    @State private var assignTarget: TeamMember? = nil

    private var deptColor: Color { Color(hex: dept.colorHex) }

    var body: some View {
        PanelCard(theme: theme) {
            VStack(spacing: Space.s3) {
                HStack(spacing: Space.s3) {
                    ZStack {
                        Circle().fill(deptColor.opacity(0.25)).frame(width: 42, height: 42)
                        // Departman ikonu: id bazlı SF Symbol eşlemesi
                        Image(systemName: Icons.Dept.symbol(for: dept.id))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(deptColor)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(dept.name).font(.appText(15, .bold))
                            .foregroundStyle(theme.text)
                        Text("\(model.count(dept.id)) kişi · çıktı \(String(format: "%.1f", model.deptOutput(dept.id)))")
                            .font(.numberXS)
                            .foregroundStyle(theme.subtle)
                            .contentTransition(.numericText())
                        // Görsel çıktı barı — sayı yerine büyüme hissi.
                        outputBar
                    }
                    Spacer()
                }

                // Üye listesi: kim oturuyor, hangi projede çalışıyor (kimlik katmanı).
                // Çok sayıda üye varsa max 4 göster + "+N daha" rozeti — kart şişmesin.
                let members = model.members(in: dept.id)
                if !members.isEmpty {
                    rosterRows(members: members)
                }

                HStack(spacing: Space.s2) {
                    // Çıkar: danger dili (ikon yeterli, nötr dolgu).
                    Button { Haptics.tap(); model.fire(dept.id) } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: AppButton.compactHeight, height: AppButton.compactHeight)
                            .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.s))
                            .foregroundStyle(model.count(dept.id) > 0 ? Palette.danger : theme.textQuaternary)
                    }
                    .buttonStyle(.pressable)
                    .disabled(model.count(dept.id) == 0)

                    Button { Haptics.tap(); model.hire(dept.id) } label: {
                        HStack(spacing: Space.s1) {
                            // Koltuk dolu ise işe alım yerine "masa/alan al" yönlendir.
                            Image(systemName: model.seatsFull ? "chair.fill" : "person.badge.plus")
                            Text(model.seatsFull
                                 ? "Koltuk dolu · masa al"
                                 : "İşe Al · \(BigNumber.money(model.hireCost(dept.id)))")
                                .font(.appText(13, .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: AppButton.compactHeight)
                        .background(model.canHire(dept.id) ? deptColor : theme.surfaceHigh,
                                    in: RoundedRectangle(cornerRadius: Radius.s))
                        .foregroundStyle(model.canHire(dept.id) ? .white : theme.textQuaternary)
                    }
                    .buttonStyle(.pressable)
                    .disabled(!model.canHire(dept.id))
                }
            }
        }
        // Üye satırına basıldığında — proje atama popover'ı (iPhone'da popover olarak yapışır).
        .popover(item: $assignTarget,
                 attachmentAnchor: .point(.center),
                 arrowEdge: .top) { m in
            MemberAssignPopover(model: model, theme: theme, memberID: m.id) {
                assignTarget = nil
            }
            .presentationCompactAdaptation(.popover)
        }
    }

    /// Departmandaki üyelerin mini satırları: avatar (initial) + ad + skill yıldızları + proje rozeti.
    /// Maksimum 4 satır; fazlası "+N" rozetiyle özetlenir (kart şişmemesi için).
    @ViewBuilder
    private func rosterRows(members: [TeamMember]) -> some View {
        let visible = Array(members.prefix(4))
        let extra = max(0, members.count - visible.count)
        VStack(spacing: 4) {
            ForEach(visible) { m in
                memberRow(m)
            }
            if extra > 0 {
                HStack {
                    Text("+\(extra) kişi daha")
                        .font(.numberXS).foregroundStyle(theme.subtle)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func memberRow(_ m: TeamMember) -> some View {
        let projectName = m.assignedProjectID
            .flatMap { id in model.projects.first(where: { $0.id == id })?.name }
        // Tüm satır tıklanabilir → atama popover'ı; kart-içi mini chip yerine satır eylem.
        return Button {
            Haptics.selection()
            assignTarget = m
        } label: {
            HStack(spacing: Space.s2) {
                Text(m.initials)
                    .font(.appText(9, .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(deptColor, in: Circle())
                    .overlay(Circle().stroke(Palette.gold, lineWidth: m.isFounder ? 1.5 : 0))

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(m.fullName).font(.appText(11, .semibold)).foregroundStyle(theme.text)
                            .lineLimit(1)
                        if m.isFounder {
                            Text("CEO").font(.system(size: 7, weight: .black)).foregroundStyle(Palette.gold)
                                .padding(.horizontal, 3).padding(.vertical, 1)
                                .background(Palette.gold.opacity(0.18), in: Capsule())
                        }
                    }
                    HStack(spacing: 4) {
                        Text(m.skillStars).font(.system(size: 7, weight: .bold))
                            .foregroundStyle(Palette.gold)
                        // Proje rozeti — atanmamışsa "Atanmamış" göster (tıkla → ata).
                        if let pname = projectName {
                            Text("· \(pname)").font(.appText(9, .medium))
                                .foregroundStyle(theme.accent).lineLimit(1)
                        } else {
                            Text("· Atanmamış").font(.appText(9, .medium))
                                .foregroundStyle(theme.textQuaternary)
                        }
                    }
                }
                Spacer(minLength: 0)
                // Atama göstergesi — tıklanabilir olduğu görsel ipucu.
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.subtle)
            }
            .padding(.horizontal, 4).padding(.vertical, 3)
        }
        .buttonStyle(.pressable)
    }

    /// Departman çıktı oranını dolu bar olarak gösterir (referans olarak headcount*2 hedef).
    private var outputBar: some View {
        let target = max(Double(model.count(dept.id)) * 2.0, 1)
        let ratio = min(1, model.deptOutput(dept.id) / target)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.surfaceHigh)
                Capsule().fill(deptColor.opacity(0.8))
                    .frame(width: geo.size.width * CGFloat(model.count(dept.id) > 0 ? ratio : 0))
            }
        }
        .frame(width: 90, height: 5)
    }
}
