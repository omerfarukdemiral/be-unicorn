import SwiftUI

/// Ofiste bir çalışana / departmana tıklanınca açılan kart.
/// **Önceki sürüm**: yalnızca dept sayacını gösterirdi ("5 kişilik ekip").
/// **Şimdi**: departmandaki tüm üyeleri **isimleriyle** listeler, kıdem + skill + atanmış proje
/// rozetlemesiyle gösterir, üyeye tıklanınca o üye spesifik fire'lanabilir.
struct EmployeeCardView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let deptIndex: Int
    @State private var appeared = false
    /// Aktif atama popover'ı için seçili üye (nil → kapalı).
    @State private var assignTarget: TeamMember? = nil

    private var dept: DepartmentDef { Balance.departments[deptIndex] }
    private var tint: Color { Color(hex: dept.colorHex) }
    private var roster: [TeamMember] { model.members(in: deptIndex) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { dismiss() }
            VStack {
                Spacer()
                card
                    .scaleEffect(appeared ? 1 : 0.9).opacity(appeared ? 1 : 0)
                    .padding(.horizontal, Space.s5).padding(.bottom, 40)
            }
        }
        .onAppear { withAnimation(Motion.snappy) { appeared = true } }
    }

    private var card: some View {
        VStack(spacing: 0) {
            // Tepe avatar (departman ikonu).
            ZStack {
                Circle().fill(tint.opacity(0.25)).frame(width: 80, height: 80)
                Image(systemName: Icons.Dept.symbol(for: deptIndex))
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .offset(y: 16)
            .zIndex(1)

            VStack(spacing: Space.s3) {
                Text(dept.name.uppercased())
                    .font(.appText(12, .black))
                    .kerning(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Space.s3).padding(.vertical, Space.s1)
                    .background(tint, in: Capsule())

                HStack(spacing: Space.s4) {
                    stat("Kişi", "\(model.count(deptIndex))")
                    stat("Maaş/kişi", BigNumber.money(perPersonSalary) + "/ay")
                    stat("Çıktı", String(format: "%.1f", model.deptOutput(deptIndex)))
                }

                // Üye listesi — kim oturuyor, hangi projede çalışıyor.
                if !roster.isEmpty {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(roster) { m in
                                rosterRow(m)
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                } else {
                    Text("Bu departmanda henüz çalışan yok.")
                        .font(.bodyText).foregroundStyle(theme.subtle)
                        .frame(maxWidth: .infinity).padding(.vertical, Space.s3)
                }

                VStack(spacing: Space.s2) {
                    Button { Haptics.tap(); model.hire(deptIndex) } label: {
                        label("İşe Al · \(BigNumber.money(model.hireCost(deptIndex)))",
                              bg: model.canHire(deptIndex) ? tint : theme.surfaceHigh,
                              fg: model.canHire(deptIndex) ? .white : theme.textQuaternary)
                    }.disabled(!model.canHire(deptIndex)).buttonStyle(.pressable)

                    Button { dismiss() } label: {
                        label("Kapat", bg: theme.surfaceHigh, fg: theme.text)
                    }.buttonStyle(.pressable)
                }
            }
            .padding(.top, Space.s6).padding(.horizontal, Space.s4).padding(.bottom, Space.s4)
            .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.overlay))
            .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
        }
        // Üyeden proje atama popover'ı — modal içinden de erişilebilir.
        .popover(item: $assignTarget,
                 attachmentAnchor: .point(.center),
                 arrowEdge: .top) { m in
            MemberAssignPopover(model: model, theme: theme, memberID: m.id) {
                assignTarget = nil
            }
            .presentationCompactAdaptation(.popover)
        }
    }

    /// Tek bir üye satırı: avatar, ad, skill, proje, kıdem + fire (kurucu hariç).
    private func rosterRow(_ m: TeamMember) -> some View {
        let projectName = m.assignedProjectID
            .flatMap { id in model.projects.first(where: { $0.id == id })?.name }
        let tenureMonths = max(0, model.months - m.joinedMonth)
        return HStack(spacing: Space.s2) {
            Text(m.initials)
                .font(.appText(10, .heavy)).foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint, in: Circle())
                .overlay(Circle().stroke(Palette.gold, lineWidth: m.isFounder ? 1.5 : 0))

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(m.fullName).font(.appText(12, .semibold)).foregroundStyle(theme.text)
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
                    Text("· \(tenureLabel(tenureMonths))").font(.appText(9, .medium))
                        .foregroundStyle(theme.subtle)
                    if let pname = projectName {
                        Text("· \(pname)").font(.appText(9, .medium))
                            .foregroundStyle(theme.accent).lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
            // Atama: küçük "yer değiştir" düğmesi — proje atama popover'ını açar.
            Button {
                Haptics.selection(); assignTarget = m
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 26, height: 26)
                    .background(theme.accent.opacity(0.12), in: Circle())
            }
            .buttonStyle(.pressable)
            // Fire: kurucu HARİÇ; her satırın kendi mini-trash butonu.
            if !m.isFounder {
                Button {
                    Haptics.tap(); model.fire(deptIndex)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.danger)
                        .frame(width: 26, height: 26)
                        .background(Palette.danger.opacity(0.12), in: Circle())
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(.horizontal, Space.s2).padding(.vertical, 4)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.s))
    }

    /// "3 ay" / "<1 ay" gibi insancıl kıdem.
    private func tenureLabel(_ months: Double) -> String {
        if months < 1 { return "<1 ay" }
        return "\(Int(months)) ay"
    }

    private var perPersonSalary: Double {
        dept.baseSalary * Balance.salaryMultiplier(forStage: model.stageIndex)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.numberL).foregroundStyle(theme.text)
            Text(label).font(.appText(10, .medium)).foregroundStyle(theme.subtle)
        }
    }

    private func label(_ text: String, bg: Color, fg: Color) -> some View {
        Text(text).font(.appText(14, .bold)).foregroundStyle(fg)
            .frame(maxWidth: .infinity).frame(height: AppButton.height)
            .background(bg, in: RoundedRectangle(cornerRadius: Radius.m))
    }

    private func dismiss() {
        withAnimation(Motion.quick) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { model.inspectedDept = nil }
    }
}
