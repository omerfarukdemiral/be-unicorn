import SwiftUI

/// Modüller ekranı: kalıcı yükseltmeler / araştırma.
struct ModulesPanel: View {
    @ObservedObject var model: GameModel
    var theme: Theme

    var body: some View {
        ScrollView {
            VStack(spacing: Space.s3) {
                PanelCard(theme: theme) {
                    HStack {
                        Text("Modüller").font(.titleM)
                            .foregroundStyle(theme.text)
                        Spacer()
                        Text("Şirketi güçlendiren kalıcı yatırımlar")
                            .font(.labelText)
                            .foregroundStyle(theme.subtle)
                            .multilineTextAlignment(.trailing)
                    }
                }
                ForEach(Balance.modules) { mod in
                    if model.isModuleUnlocked(mod.id) {
                        ModuleRow(model: model, theme: theme, mod: mod)
                    } else {
                        LockedModuleRow(theme: theme, mod: mod)
                    }
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal, Space.s4)
            .padding(.top, Space.s3)
        }
    }
}

private struct ModuleRow: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let mod: ModuleDef

    var body: some View {
        PanelCard(theme: theme) {
            HStack(spacing: Space.s3) {
                // Modül ikonu: id bazlı SF Symbol
                Image(systemName: Icons.Module.symbol(for: mod.id))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: Space.s1) {
                        Text(mod.name).font(.appText(14, .bold))
                            .foregroundStyle(theme.text)
                        Text("Lv \(model.moduleLevel(mod.id))/\(mod.maxLevel)")
                            .font(.numberXS)
                            .foregroundStyle(theme.accent)
                    }
                    Text(mod.detail).font(.labelText)
                        .foregroundStyle(theme.subtle)
                }
                Spacer()
                if model.isModuleMaxed(mod.id) {
                    Text("MAX").font(.appText(12, .black))
                        .foregroundStyle(Palette.success)
                } else {
                    Button { Haptics.tap(); model.buyModule(mod.id) } label: {
                        Text(BigNumber.money(model.moduleCost(mod.id)))
                            .font(.numberS)
                            .padding(.horizontal, Space.s3).frame(height: 36)
                            .background(model.canBuyModule(mod.id) ? theme.accent : theme.surfaceHigh,
                                        in: RoundedRectangle(cornerRadius: Radius.s))
                            .foregroundStyle(model.canBuyModule(mod.id) ? .white : theme.textQuaternary)
                    }
                    .buttonStyle(.pressable)
                    .disabled(!model.canBuyModule(mod.id))
                }
            }
        }
    }
}

private struct LockedModuleRow: View {
    var theme: Theme
    let mod: ModuleDef
    var body: some View {
        PanelCard(theme: theme) {
            HStack(spacing: Space.s3) {
                // Kilitli modül: kilit SF Symbol
                Image(systemName: Icons.Screen.locked)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(theme.textQuaternary)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mod.name).font(.appText(14, .bold))
                        .foregroundStyle(theme.textQuaternary)
                    Text("\(Balance.stages[mod.unlockStage].name) turunda açılır")
                        .font(.labelText)
                        .foregroundStyle(theme.subtle)
                }
                Spacer()
            }
        }
        .opacity(0.7)
    }
}
