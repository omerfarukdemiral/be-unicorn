import SwiftUI

/// Ofiste bir çalışana tıklanınca açılan departman/çalışan kartı (referans stili).
struct EmployeeCardView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let deptIndex: Int
    @State private var appeared = false

    private var dept: DepartmentDef { Balance.departments[deptIndex] }
    private var tint: Color { Color(hex: dept.colorHex) }

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
            ZStack {
                Circle().fill(tint.opacity(0.25)).frame(width: 80, height: 80)
                // Büyük departman ikonu: zarif SF Symbol
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

                Text("\(model.count(deptIndex)) kişilik ekip")
                    .font(.numberL).foregroundStyle(theme.text)
                    .contentTransition(.numericText())

                HStack(spacing: Space.s6) {
                    stat("Maaş/kişi", BigNumber.money(perPersonSalary) + "/ay")
                    stat("Çıktı", String(format: "%.1f", model.deptOutput(deptIndex)))
                }

                VStack(spacing: Space.s2) {
                    Button { Haptics.tap(); model.hire(deptIndex) } label: {
                        label("İşe Al · \(BigNumber.money(model.hireCost(deptIndex)))",
                              bg: model.canHire(deptIndex) ? tint : theme.surfaceHigh,
                              fg: model.canHire(deptIndex) ? .white : theme.textQuaternary)
                    }.disabled(!model.canHire(deptIndex)).buttonStyle(.pressable)

                    HStack(spacing: Space.s2) {
                        Button { Haptics.tap(); model.fire(deptIndex) } label: {
                            label("Çıkar", bg: Palette.danger.opacity(0.85), fg: .white)
                        }.disabled(model.count(deptIndex) == 0).buttonStyle(.pressable)
                        Button { dismiss() } label: {
                            label("Kapat", bg: theme.surfaceHigh, fg: theme.text)
                        }.buttonStyle(.pressable)
                    }
                }
            }
            .padding(.top, Space.s6).padding(.horizontal, Space.s4).padding(.bottom, Space.s4)
            .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.overlay))
            .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
        }
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
