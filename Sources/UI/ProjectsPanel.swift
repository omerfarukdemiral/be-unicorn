import SwiftUI

/// Projeler sekmesi: şirketin ürün portföyü. Şirket projeleriyle büyür —
/// yeni proje başlat → mühendislik gücüyle geliştir → yayına al. Canlı projeler
/// büyüme/ARPU/itibara katkı verir; geliştirilenler ilerleme çubuğuyla gösterilir.
struct ProjectsPanel: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    @State private var showNewProject = false

    var body: some View {
        ScrollView {
            VStack(spacing: Space.s3) {
                portfolioCard

                ForEach(model.projects) { project in
                    ProjectRow(model: model, theme: theme, project: project)
                }

                newProjectButton
                Spacer(minLength: 20)
            }
            .padding(.horizontal, Space.s4).padding(.top, Space.s3)
        }
        .sheet(isPresented: $showNewProject) {
            NewProjectSheet(model: model, theme: theme)
        }
    }

    // MARK: Portföy özeti

    private var portfolioCard: some View {
        PanelCard(theme: theme) {
            VStack(alignment: .leading, spacing: Space.s3) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: Space.s1) {
                        Text("Proje Portföyü").font(.titleM).foregroundStyle(theme.text)
                        Text("Şirketin projeleriyle büyür. Yeni ürün başlat, geliştir, yayına al.")
                            .font(.bodyText).foregroundStyle(theme.subtle)
                    }
                    Spacer()
                }
                HStack(spacing: Space.s2) {
                    metric(Icons.Metric.health, "\(model.liveProjectCount)", "yayında")
                    metric("hammer.fill", "\(model.projects.count - model.liveProjectCount)", "geliştiriliyor")
                    metric("square.stack.3d.up.fill", "\(model.projects.count)/\(model.maxProjects)", "kapasite")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func metric(_ symbol: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: Space.s1) {
                Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Text(value).font(.numberS).foregroundStyle(theme.text)
            }
            Text(label).font(.caption).foregroundStyle(theme.subtle)
        }
        .frame(maxWidth: .infinity).padding(.vertical, Space.s2)
        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.s))
    }

    private var newProjectButton: some View {
        Button {
            Haptics.tap(); showNewProject = true
        } label: {
            HStack(spacing: Space.s2) {
                Image(systemName: "plus.circle.fill")
                Text(model.canStartNewProject ? "Yeni Proje Başlat" : "Portföy Dolu (evre yükselt)")
            }
            .font(.bodyL)
            .modifier(AppButton.primary(theme, enabled: model.canStartNewProject))
        }
        .buttonStyle(.pressable)
        .disabled(!model.canStartNewProject)
        .padding(.top, Space.s1)
    }
}

// MARK: - Tek proje kartı (yayında / geliştiriliyor)

private struct ProjectRow: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let project: ProjectState

    private var cat: ProjectCategoryDef { Balance.projectCategory(project.category) ?? Balance.projectCategories[0] }

    var body: some View {
        PanelCard(theme: theme, highlighted: project.isLive) {
            VStack(alignment: .leading, spacing: Space.s3) {
                HStack(spacing: Space.s2) {
                    Image(systemName: cat.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(project.isLive ? theme.accent : theme.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.s))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(project.name).font(.appText(15, .bold)).foregroundStyle(theme.text)
                            .lineLimit(1)
                        Text(cat.name).font(.numberXS).foregroundStyle(theme.subtle)
                    }
                    Spacer()
                    statusBadge
                }

                if project.isLive {
                    // Katkı rozetleri (yayında — büyüme/gelir/itibar).
                    HStack(spacing: Space.s2) {
                        if cat.growthBonus > 0 { contributionChip("arrow.up.right", "+\(pct(cat.growthBonus)) büyüme", Palette.success) }
                        if cat.arpuBonus > 0 { contributionChip("dollarsign.circle", "+\(pct(cat.arpuBonus)) gelir", theme.accent) }
                        if cat.reputationBonus > 0 { contributionChip("star.fill", "+\(Int(cat.reputationBonus)) itibar", Palette.gold) }
                    }
                } else {
                    // Geliştirme ilerlemesi + ETA.
                    VStack(alignment: .leading, spacing: Space.s1) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(theme.surfaceHigh)
                                Capsule().fill(theme.accent)
                                    .frame(width: geo.size.width * CGFloat(project.devProgress))
                            }
                        }
                        .frame(height: 8)
                        HStack {
                            Text("Geliştiriliyor · %\(Int(project.devProgress * 100))")
                                .font(.numberXS).foregroundStyle(theme.subtle)
                            Spacer()
                            Text(etaText).font(.numberXS).foregroundStyle(theme.accent)
                        }
                    }
                }
            }
        }
    }

    private var statusBadge: some View {
        Group {
            if project.isLive {
                badge("YAYINDA", Palette.success)
            } else {
                badge("GELİŞTİRME", theme.accent)
            }
        }
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text).font(.caption).kerning(0.6).foregroundStyle(color)
            .padding(.horizontal, Space.s2).padding(.vertical, Space.s1)
            .background(color.opacity(0.15), in: Capsule())
    }

    private func contributionChip(_ symbol: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 9, weight: .bold))
            Text(text).font(.appText(10, .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, Space.s2).padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
    }

    private func pct(_ v: Double) -> String { "%\(Int((v * 100).rounded()))" }

    private var etaText: String {
        let secs = model.projectETASeconds(project)
        if secs <= 0 { return "neredeyse hazır" }
        if secs < 60 { return "~\(Int(secs))sn" }
        return "~\(Int(secs / 60))dk \(Int(secs.truncatingRemainder(dividingBy: 60)))sn"
    }
}

// MARK: - Yeni proje başlatma sayfası

private struct NewProjectSheet: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category = 0
    @FocusState private var nameFocused: Bool

    private var cost: Double { model.projectStartCost(category) }
    private var affordable: Bool { model.canStartProject(category) }

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s4) {
                    HStack {
                        Text("Yeni Proje").font(.titleL).foregroundStyle(theme.text)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24)).foregroundStyle(theme.subtle)
                        }
                    }

                    VStack(alignment: .leading, spacing: Space.s1) {
                        Text("PROJE ADI").font(.eyebrow).kerning(1).foregroundStyle(theme.subtle)
                        HStack(spacing: Space.s2) {
                            TextField("Atlas", text: $name)
                                .focused($nameFocused)
                                .font(.bodyL).foregroundStyle(theme.text).tint(theme.accent)
                                .padding(.horizontal, Space.s3).padding(.vertical, Space.s3)
                                .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
                                .overlay(RoundedRectangle(cornerRadius: Radius.m)
                                    .stroke(nameFocused ? theme.accent.opacity(0.6) : theme.hairline,
                                            lineWidth: nameFocused ? 1.5 : 1))
                            Button {
                                Haptics.selection(); name = NarrativeContent.randomProjectName()
                            } label: {
                                Image(systemName: "dice.fill").font(.bodyL).foregroundStyle(theme.accent)
                                    .frame(width: 48, height: 48)
                                    .background(theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.m))
                            }
                            .buttonStyle(.pressable)
                        }
                    }

                    Text("PROJE TÜRÜ").font(.eyebrow).kerning(1).foregroundStyle(theme.subtle)
                    ForEach(Balance.projectCategories) { c in
                        categoryRow(c)
                    }

                    startButton
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, Space.s4).padding(.top, Space.s5)
            }
        }
        .onAppear { if name.isEmpty { name = NarrativeContent.randomProjectName() } }
        .presentationDetents([.large])
    }

    private func categoryRow(_ c: ProjectCategoryDef) -> some View {
        let selected = category == c.id
        let rowCost = model.projectStartCost(c.id)
        return Button {
            Haptics.selection(); withAnimation(Motion.snappy) { category = c.id }
        } label: {
            HStack(spacing: Space.s3) {
                Image(systemName: c.icon).font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selected ? theme.accent : theme.textSecondary)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Space.s2) {
                        Text(c.name).font(.appText(14, .bold)).foregroundStyle(theme.text)
                        Text(BigNumber.money(rowCost)).font(.numberXS).foregroundStyle(theme.subtle)
                    }
                    Text(c.detail).font(.appText(10.5, .medium)).foregroundStyle(theme.subtle)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 16)).foregroundStyle(theme.accent)
                }
            }
            .padding(Space.s3)
            .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(RoundedRectangle(cornerRadius: Radius.m)
                .stroke(selected ? theme.accent.opacity(0.6) : theme.hairline,
                        lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.pressable)
    }

    private var startButton: some View {
        Button {
            Haptics.tap()
            if model.startProject(name: name, category: category) { dismiss() }
        } label: {
            HStack(spacing: Space.s2) {
                Image(systemName: "hammer.fill")
                Text(affordable ? "Geliştirmeye Başla · \(BigNumber.money(cost))"
                                : (model.canStartNewProject ? "Yetersiz nakit" : "Portföy dolu"))
            }
            .font(.bodyL)
            .modifier(AppButton.primary(theme, enabled: affordable))
        }
        .buttonStyle(.pressable)
        .disabled(!affordable)
        .padding(.top, Space.s2)
    }
}
