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
    @State private var manageTeam = false

    private var cat: ProjectCategoryDef { Balance.projectCategory(project.category) ?? Balance.projectCategories[0] }
    private var team: [TeamMember] { model.teamMembers(forProject: project.id) }
    /// Ürünü inşa edebilecek (mühendislik/ürün ağırlıklı) atanmış biri var mı.
    private var hasBuilder: Bool { model.projectBuildPower(project) > 0 }
    private var mature: Bool { project.devProgress >= 1 }

    var body: some View {
        PanelCard(theme: theme, highlighted: project.isLive) {
            VStack(alignment: .leading, spacing: Space.s3) {
                headerRow
                maturitySection
                if project.isLive {
                    // Katkı rozetleri (yayında — büyüme/gelir/itibar).
                    HStack(spacing: Space.s2) {
                        if cat.growthBonus > 0 { contributionChip("arrow.up.right", "+\(pct(cat.growthBonus)) büyüme", Palette.success) }
                        if cat.arpuBonus > 0 { contributionChip("dollarsign.circle", "+\(pct(cat.arpuBonus)) gelir", theme.accent) }
                        if cat.reputationBonus > 0 { contributionChip("star.fill", "+\(Int(cat.reputationBonus)) itibar", Palette.gold) }
                    }
                }
                if !mature { teamManageRow }
            }
        }
        .sheet(isPresented: $manageTeam) {
            ProjectTeamSheet(model: model, theme: theme, projectID: project.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var headerRow: some View {
        HStack(spacing: Space.s2) {
            Image(systemName: cat.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(project.isLive ? theme.accent : theme.textSecondary)
                .frame(width: 34, height: 34)
                .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.s))
            VStack(alignment: .leading, spacing: 1) {
                Text(project.name).font(.appText(15, .bold)).foregroundStyle(theme.text)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(cat.name).font(.numberXS).foregroundStyle(theme.subtle)
                    if !team.isEmpty {
                        Text("·").font(.numberXS).foregroundStyle(theme.subtle)
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(theme.accent)
                        Text(teamLabel(team)).font(.numberXS).foregroundStyle(theme.subtle)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            statusBadge
        }
    }

    /// Ürün olgunluğu bar'ı + özellik checklist + durum satırı (her durumda — ürün
    /// yayından sonra da gelişmeye devam eder, olgunlukla geliri büyür).
    private var maturitySection: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            HStack {
                Text("Ürün olgunluğu").font(.numberXS).foregroundStyle(theme.subtle)
                Spacer()
                Text("%\(Int(project.devProgress * 100))")
                    .font(.numberXS).foregroundStyle(mature ? Palette.success : theme.accent)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.surfaceHigh)
                    Capsule().fill(mature ? Palette.success : theme.accent)
                        .frame(width: geo.size.width * CGFloat(min(1, max(0, project.devProgress))))
                }
            }
            .frame(height: 8)
            featureChecklist
            statusLine
        }
    }

    /// Geliştirilecek özellikler — tamamlanan ✓, sıradaki vurgulu (ürüne modül ekleme hissi).
    private var featureChecklist: some View {
        let milestones = Balance.projectFeatureMilestones(project.category)
        let nextIdx = milestones.firstIndex { project.devProgress < $0.threshold - 0.0001 }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s1 + 2) {
                ForEach(Array(milestones.enumerated()), id: \.offset) { idx, m in
                    featureChip(m.name,
                                done: project.devProgress >= m.threshold - 0.0001,
                                next: idx == nextIdx)
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func featureChip(_ name: String, done: Bool, next: Bool) -> some View {
        let tint: Color = done ? Palette.success : (next ? theme.accent : theme.subtle)
        return HStack(spacing: 3) {
            Image(systemName: done ? "checkmark.circle.fill" : (next ? "hammer.circle.fill" : "circle"))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(done ? Palette.success : (next ? theme.accent : theme.textQuaternary))
            Text(name).font(.appText(10, .semibold))
                .foregroundStyle(done ? theme.textSecondary : (next ? theme.text : theme.subtle))
        }
        .padding(.horizontal, Space.s2).padding(.vertical, 4)
        .background(tint.opacity(0.12), in: Capsule())
        .overlay(next ? Capsule().stroke(theme.accent.opacity(0.5), lineWidth: 1) : nil)
    }

    @ViewBuilder private var statusLine: some View {
        if mature {
            statusLabel("checkmark.seal.fill", "Ürün olgun — tam gelir katkısı", Palette.success)
        } else if !hasBuilder {
            statusLabel("exclamationmark.triangle.fill", "Geliştirecek ekip atanmadı — ürün ilerlemiyor", Palette.warning)
        } else if project.isLive {
            statusLabel("hammer.fill", "Olgunlaşıyor — kalan özellikler geliştiriliyor", theme.accent)
        } else {
            statusLabel("hammer.fill", "Yayına (MVP) \(etaText)", theme.accent)
        }
    }

    private func statusLabel(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold))
            Text(text).font(.numberXS)
        }
        .foregroundStyle(color)
    }

    /// Ekibi bu ürüne ata/yönet — inşa atanan ekiple sürdüğü için ana aksiyon budur.
    private var teamManageRow: some View {
        let warn = !hasBuilder
        let tint = warn ? Palette.warning : theme.accent
        return Button { Haptics.tap(); manageTeam = true } label: {
            HStack(spacing: Space.s2) {
                Image(systemName: "person.2.badge.plus.fill").font(.system(size: 12, weight: .bold))
                Text(team.isEmpty ? "Ekip ata — ürünü geliştir" : "Ekibi yönet · \(team.count) kişi")
                    .font(.appText(12, .bold))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, Space.s3).padding(.vertical, Space.s2)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.s))
        }
        .buttonStyle(.pressable)
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

    /// "Ada + 2" / "Ada Yılmaz" gibi proje takımı özeti. Tek kişi varsa tam ad,
    /// çoklu ise ilk üyenin adı + "+N" rozeti — kart başlığı bilgisi daraltmak için.
    private func teamLabel(_ team: [TeamMember]) -> String {
        guard let first = team.first else { return "" }
        if team.count == 1 { return first.firstName }
        return "\(first.firstName) +\(team.count - 1)"
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
        if !secs.isFinite { return "— ekip ata" }
        if secs <= 0 { return "neredeyse hazır" }
        if secs < 60 { return "~\(Int(secs))sn" }
        return "~\(Int(secs / 60))dk \(Int(secs.truncatingRemainder(dividingBy: 60)))sn"
    }
}

// MARK: - Ekip atama sayfası (proje-merkezli: bu ürünü kim geliştiriyor)

/// Bir projeye ekip atayan/yöneten sayfa. Ürünü asıl Mühendislik (d0) inşa eder; bu
/// projeye atanan kişiler ürünün olgunluğunu ilerletir. Üye satırına dokun → bu projeye
/// at / bu projeden çıkar (model.assign). "Ekibi ürüne yönetmek" çekirdek aksiyonudur.
private struct ProjectTeamSheet: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let projectID: UUID
    @Environment(\.dismiss) private var dismiss

    private var project: ProjectState? { model.projects.first { $0.id == projectID } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ekip Ata").font(.titleM).foregroundStyle(theme.text)
                    if let p = project {
                        Text(p.name).font(.bodyText).foregroundStyle(theme.subtle)
                    }
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24)).foregroundStyle(theme.subtle)
                }
            }
            .padding(Space.s4)

            Text("Ürünü asıl Mühendislik geliştirir. Bu projeye atadığın kişiler olgunluğu ilerletir — kimseyi atamazsan ürün ilerlemez.")
                .font(.bodyText).foregroundStyle(theme.subtle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.s4).padding(.bottom, Space.s2)

            ScrollView {
                VStack(spacing: Space.s2) {
                    ForEach(model.members) { m in memberRow(m) }
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, Space.s4).padding(.top, Space.s1)
            }
        }
        .background(theme.bg.ignoresSafeArea())
    }

    private func memberRow(_ m: TeamMember) -> some View {
        let onThis = m.assignedProjectID == projectID
        let di = min(max(0, m.deptIndex), Balance.departments.count - 1)
        let dept = Balance.departments[di]
        let builds = di == 0 || di == 1   // mühendislik/ürün ürünü inşa eder
        return Button {
            Haptics.selection()
            model.assign(memberID: m.id, toProject: onThis ? nil : projectID)
        } label: {
            HStack(spacing: Space.s2) {
                Text(m.initials)
                    .font(.system(size: 12, weight: .black)).foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color(hex: dept.colorHex), in: Circle())
                    .overlay(Circle().stroke(Palette.gold, lineWidth: m.isFounder ? 1.5 : 0))
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.fullName).font(.appText(14, .bold)).foregroundStyle(theme.text).lineLimit(1)
                    HStack(spacing: 4) {
                        Text(dept.name + (m.isFounder ? " · Kurucu" : ""))
                            .font(.numberXS).foregroundStyle(theme.subtle)
                        if !builds {
                            Text("· ürünü inşa etmez").font(.numberXS).foregroundStyle(theme.textQuaternary)
                        }
                    }
                }
                Spacer()
                if let pid = m.assignedProjectID, pid != projectID,
                   let other = model.projects.first(where: { $0.id == pid }) {
                    Text(other.name).font(.appText(10, .medium))
                        .foregroundStyle(theme.textQuaternary).lineLimit(1)
                }
                Image(systemName: onThis ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(onThis ? Palette.success : theme.accent)
            }
            .padding(Space.s3)
            .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(RoundedRectangle(cornerRadius: Radius.m)
                .stroke(onThis ? theme.hairlineStrong : theme.hairline))
        }
        .buttonStyle(.pressable)
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
