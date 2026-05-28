import SwiftUI

/// Yol haritası: Garaj → Unicorn funding evreleri + hedef ilerlemesi. (Hedef odaklı retention ekranı.)
struct RoadmapPanel: View {
    @ObservedObject var model: GameModel
    var theme: Theme

    var body: some View {
        ScrollView {
            VStack(spacing: Space.s3) {
                // Şirket kimliği — kuruluşta girilen CEO + şirket + sektör + portföy.
                CompanyHeaderCard(model: model, theme: theme)

                PanelCard(theme: theme) {
                    VStack(alignment: .leading, spacing: Space.s3) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: Space.s1) {
                                Text("Yol Haritası").font(.titleM)
                                    .foregroundStyle(theme.text)
                                Text("Garajdan Unicorn'a giden yol. Sıradaki hedef: \(model.nextStage?.name ?? "Zirve")")
                                    .font(.bodyText)
                                    .foregroundStyle(theme.subtle)
                            }
                            Spacer()
                        }
                        // Lig rozeti + çeyrek ilerlemesi (completed-cycle göstergesi).
                        LeaguePill(model: model, theme: theme)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Canlı leaderboard — rakip kohort + gerçek bahis (sıralamaya göre terfi/düşüş).
                LeaderboardCard(model: model, theme: theme)
                // Sezon koleksiyonu — kazanılan kalıcı ünvanlar + üretim çarpanı (uzun-vade tamamlanma).
                SeasonCollectionCard(model: model, theme: theme)
                // Dikey "yol" — satırlar arası bağlantı çizgisi.
                VStack(spacing: 0) {
                    ForEach(Balance.stages) { stage in
                        StageRow(model: model, theme: theme, stage: stage)
                    }
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal, Space.s4).padding(.top, Space.s3)
        }
    }
}

private struct StageRow: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let stage: StageDef

    private var isDone: Bool { model.stageIndex > stage.id }
    private var isCurrent: Bool { model.stageIndex == stage.id }
    private var isNext: Bool { model.stageIndex + 1 == stage.id }
    private var isLast: Bool { stage.id == Balance.stageCount - 1 }
    private var isFirst: Bool { stage.id == 0 }

    private var dotColor: Color {
        if isDone { return Palette.success }
        if isCurrent { return theme.accent }
        if isLast { return Palette.gold }
        return theme.surfaceHigh
    }

    var body: some View {
        HStack(alignment: .top, spacing: Space.s3) {
            // Sol: bağlantı çizgisi + durum dairesi.
            VStack(spacing: 0) {
                // Üst segment (önceki satıra) — ilk hariç.
                Rectangle()
                    .fill(isDone || isCurrent ? Palette.success : theme.hairline)
                    .frame(width: 2, height: 10)
                    .opacity(isFirst ? 0 : 1)
                statusDot
                // Alt segment (sonraki satıra) — son hariç.
                Rectangle()
                    .fill(isDone ? Palette.success : theme.hairline)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .opacity(isLast ? 0 : 1)
            }
            .frame(width: 38)

            // Sağ: içerik kartı.
            PanelCard(theme: theme, highlighted: isCurrent) {
                HStack(spacing: Space.s2) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stage.name).font(.appText(15, .bold))
                            .foregroundStyle(isCurrent ? theme.accent : (isLast ? Palette.gold : theme.text))
                        Text(stage.valuationTarget > 0 ? "Hedef değerleme: \(BigNumber.money(stage.valuationTarget))" : "Başlangıç")
                            .font(.numberXS)
                            .foregroundStyle(theme.subtle)
                        if isNext {
                            ProgressView(value: model.raiseProgress)
                                .tint(theme.accent)
                                .scaleEffect(x: 1, y: 1.2)
                                .padding(.top, 2)
                        }
                    }
                    Spacer()
                    if isCurrent {
                        Text("ŞİMDİ").font(.caption).kerning(0.6)
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, Space.s2).padding(.vertical, Space.s1)
                            .background(theme.accent.opacity(0.15), in: Capsule())
                    }
                }
            }
            .padding(.vertical, Space.s1)
            .opacity(isDone || isCurrent || isNext || isLast ? 1 : 0.55)
        }
    }

    private var statusDot: some View {
        ZStack {
            Circle()
                .fill(dotColor)
                .frame(width: 38, height: 38)
                .shadow(color: isCurrent ? theme.accent.opacity(0.5) : .clear, radius: 8)
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
            } else if isLast {
                // Son hedef: gold taç (Unicorn zirvesi) — her zaman parıltılı.
                Image(systemName: "crown.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isCurrent ? .white : Color(hex: "1A1320"))
            } else {
                Text("\(stage.id)")
                    .font(.appNumber(16, .black))
                    .foregroundStyle(isCurrent ? .white : theme.subtle)
            }
        }
    }
}

// MARK: - Şirket kimlik kartı (CEO + şirket + sektör + portföy özeti)

/// Yol haritasının üstünde duran kimlik kartı: kuruluşta girilen profili
/// kalıcı olarak görünür kılar. CEO + şirket adı + sektör + portföy özeti.
private struct CompanyHeaderCard: View {
    @ObservedObject var model: GameModel
    var theme: Theme

    var body: some View {
        PanelCard(theme: theme, highlighted: true) {
            VStack(alignment: .leading, spacing: Space.s3) {
                HStack(spacing: Space.s3) {
                    // Sektör ikonu — kimliğin görsel imzası.
                    Image(systemName: model.sectorDef.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color(hex: model.sectorDef.colorHex))
                        .frame(width: 46, height: 46)
                        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.companyName.isEmpty ? "Şirket" : model.companyName)
                            .font(.titleM).foregroundStyle(theme.text).lineLimit(1)
                        HStack(spacing: 5) {
                            Text(model.sectorDef.name)
                                .font(.numberXS).foregroundStyle(Color(hex: model.sectorDef.colorHex))
                            Text("·").font(.numberXS).foregroundStyle(theme.subtle)
                            Text(model.currentStage.name).font(.numberXS).foregroundStyle(theme.subtle)
                        }
                    }
                    Spacer()
                }
                // CEO satırı + portföy satırı (kimliğin gerçek-hayat detayları).
                HStack(spacing: Space.s3) {
                    identityCell(icon: "person.crop.circle.fill",
                                 label: model.founderTitle,
                                 value: model.founderFullName.isEmpty ? "—" : model.founderFullName)
                    identityCell(icon: "shippingbox.fill",
                                 label: "portföy",
                                 value: "\(model.liveProjectCount) yayında / \(model.projects.count)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func identityCell(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Space.s2) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption).kerning(0.5).foregroundStyle(theme.subtle)
                Text(value).font(.numberS).foregroundStyle(theme.text).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.s))
    }
}
