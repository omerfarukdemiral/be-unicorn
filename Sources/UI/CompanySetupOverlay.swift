import SwiftUI

/// Onboarding tanıtımından sonra: oyuncu (CEO) kimliğini ve ilk projesini kurar.
/// 3 adım: 1) Kurucu ad-soyad  2) Şirket adı + sektör  3) İlk proje (ad + tür).
/// Bitince model.completeCompanySetup ile profil + ilk (yayında) proje oluşturulur.
struct CompanySetupOverlay: View {
    @ObservedObject var model: GameModel
    var theme: Theme

    @State private var step = 0
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var company = ""
    @State private var sector = 0
    @State private var projectName = ""
    @State private var projectCategory = 0
    @State private var leaning = FounderLeaning.balanced   // A1: adım 3 — kurucu eğilimi
    @FocusState private var focused: Field?

    private enum Field { case first, last, company, project }

    private var canAdvance: Bool {
        switch step {
        case 0: return !firstName.trimmed.isEmpty && !lastName.trimmed.isEmpty
        case 1: return !company.trimmed.isEmpty
        case 2: return !projectName.trimmed.isEmpty
        case 3: return true                              // A2 KRİTİK: eğilim adımı her zaman ilerleyebilir
        default: return false
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "14161F").ignoresSafeArea()
            LinearGradient(colors: [theme.accent.opacity(0.12), .clear],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.s4) {
                        switch step {
                        case 0: founderStep
                        case 1: companyStep
                        case 2: projectStep
                        default: leaningStep
                        }
                    }
                    .padding(.horizontal, Space.s5)
                    .padding(.top, Space.s4)
                    .padding(.bottom, Space.s6)
                }
                footer
            }
        }
        .onAppear {
            if firstName.isEmpty {
                let n = NarrativeContent.randomFounderName()
                firstName = n.first; lastName = n.last
            }
            if company.isEmpty { company = NarrativeContent.randomCompanyName() }
            if projectName.isEmpty { projectName = NarrativeContent.randomProjectName() }
        }
    }

    // MARK: Header — adım göstergesi + başlık

    private var header: some View {
        VStack(spacing: Space.s3) {
            HStack(spacing: Space.s1) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule().fill(i == step ? theme.accent : theme.textQuaternary)
                        .frame(width: i == step ? 22 : 8, height: 8)
                        .animation(Motion.smooth, value: step)
                }
            }
            .padding(.top, Space.s5)

            VStack(spacing: Space.s1) {
                Image(systemName: stepIcon)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(theme.accent)
                    .id(step)
                    .transition(.scale.combined(with: .opacity))
                Text(stepTitle).font(.titleL).foregroundStyle(theme.text)
                Text(stepSubtitle).font(.bodyText)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Space.s5)
        }
    }

    private var stepIcon: String {
        switch step {
        case 0: return "person.crop.circle.fill"
        case 1: return "building.2.fill"
        case 2: return "shippingbox.fill"
        default: return "sparkles"
        }
    }
    private var stepTitle: String {
        switch step {
        case 0: return "Kurucu Kim?"
        case 1: return "Şirketini Kur"
        case 2: return "İlk Projen"
        default: return "Senin Tarzın?"
        }
    }
    private var stepSubtitle: String {
        switch step {
        case 0: return "Bu maceranın CEO'su sensin. Kendini tanıt."
        case 1: return "Şirketinin adını ve faaliyet alanını seç."
        case 2: return "Şirketinin ilk ürünü. Kuruluşta yayında başlar."
        default: return "Nasıl bir kurucu olacaksın? Doğru cevap yok — sadece senin yolun."
        }
    }

    // MARK: Adım 0 — Kurucu

    private var founderStep: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            labeledField("Ad", text: $firstName, placeholder: "Ada", field: .first)
            labeledField("Soyad", text: $lastName, placeholder: "Yılmaz", field: .last)
            suggestButton {
                let n = NarrativeContent.randomFounderName()
                firstName = n.first; lastName = n.last
            }
            // Ünvan önizleme: kuruluşta evre 0 → "Hacker", büyüdükçe CEO.
            HStack(spacing: Space.s2) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(theme.accent)
                Text("Ünvan: \(model.founderTitle)").font(.bodyText).foregroundStyle(theme.textSecondary)
            }
            .padding(Space.s3).frame(maxWidth: .infinity, alignment: .leading)
            .cellSurface(theme)
        }
    }

    // MARK: Adım 1 — Şirket + sektör

    private var companyStep: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            labeledField("Şirket adı", text: $company, placeholder: "Nova Labs", field: .company)
            suggestButton { company = NarrativeContent.randomCompanyName() }

            Text("SEKTÖR").font(.eyebrow).kerning(1).foregroundStyle(theme.subtle)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.s2),
                                GridItem(.flexible(), spacing: Space.s2)], spacing: Space.s2) {
                ForEach(Balance.sectors) { s in
                    pickCard(icon: s.icon, title: s.name, detail: s.tagline,
                             tint: Color(hex: s.colorHex), selected: sector == s.id) {
                        Haptics.selection(); withAnimation(Motion.snappy) { sector = s.id }
                    }
                }
            }
        }
    }

    // MARK: Adım 2 — İlk proje + tür

    private var projectStep: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            labeledField("Proje adı", text: $projectName, placeholder: "Atlas", field: .project)
            suggestButton { projectName = NarrativeContent.randomProjectName() }

            Text("PROJE TÜRÜ").font(.eyebrow).kerning(1).foregroundStyle(theme.subtle)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.s2),
                                GridItem(.flexible(), spacing: Space.s2)], spacing: Space.s2) {
                ForEach(Balance.projectCategories) { c in
                    pickCard(icon: c.icon, title: c.name, detail: c.detail,
                             tint: theme.accent, selected: projectCategory == c.id) {
                        Haptics.selection(); withAnimation(Motion.snappy) { projectCategory = c.id }
                    }
                }
            }
        }
    }

    // MARK: Adım 3 — Kurucu eğilimi (A1/HZ-3; mekanik etki yok, salt felsefe)

    private var leaningStep: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            ForEach(FounderLeaning.allCases, id: \.rawValue) { l in
                pickCard(icon: l.icon, title: l.title, detail: l.blurb,
                         tint: theme.accent, selected: leaning == l) {
                    Haptics.selection(); withAnimation(Motion.snappy) { leaning = l }
                }
            }
            // Seçime göre değişen felsefe damlası (suçlamasız koçluk).
            HStack(alignment: .top, spacing: Space.s2) {
                Image(systemName: "sparkles").foregroundStyle(theme.accent)
                Text(leaning.philosophyDrop).font(.bodyText)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.s3).frame(maxWidth: .infinity, alignment: .leading)
            .cellSurface(theme)
            .id(leaning)
            .transition(.opacity)
        }
    }

    // MARK: Footer — geri / devam / kur

    private var footer: some View {
        HStack(spacing: Space.s2) {
            if step > 0 {
                Button {
                    Haptics.tap(); focused = nil
                    withAnimation(Motion.snappy) { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left").font(.bodyL)
                        .frame(width: 52)
                        .modifier(AppButton.secondary(theme))
                }
                .buttonStyle(.pressable)
            }
            Button {
                Haptics.tap(); focused = nil
                if step < 3 { withAnimation(Motion.snappy) { step += 1 } }
                else { finish() }
            } label: {
                HStack(spacing: Space.s2) {
                    Text(step < 3 ? "Devam" : "Şirketi Kur")
                    Image(systemName: step < 3 ? "arrow.right" : "checkmark.circle.fill")
                }
                .font(.bodyL)
                .modifier(AppButton.primary(theme, enabled: canAdvance))
            }
            .buttonStyle(.pressable)
            .disabled(!canAdvance)
        }
        .padding(.horizontal, Space.s5)
        .padding(.bottom, Space.s6).padding(.top, Space.s2)
    }

    private func finish() {
        model.completeCompanySetup(firstName: firstName, lastName: lastName,
                                   company: company, sector: sector,
                                   firstProjectName: projectName, firstProjectCategory: projectCategory,
                                   leaning: leaning)
    }

    // MARK: Yardımcı bileşenler

    private func labeledField(_ label: String, text: Binding<String>,
                              placeholder: String, field: Field) -> some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text(label.uppercased()).font(.eyebrow).kerning(1).foregroundStyle(theme.subtle)
            TextField(placeholder, text: text)
                .focused($focused, equals: field)
                .font(.bodyL)
                .foregroundStyle(theme.text)
                .tint(theme.accent)
                .submitLabel(.done)
                .padding(.horizontal, Space.s3).padding(.vertical, Space.s3)
                .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
                .overlay(RoundedRectangle(cornerRadius: Radius.m)
                    .stroke(focused == field ? theme.accent.opacity(0.6) : theme.hairline,
                            lineWidth: focused == field ? 1.5 : 1))
        }
    }

    private func suggestButton(_ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection(); withAnimation(Motion.smooth) { action() }
        } label: {
            HStack(spacing: Space.s1) {
                Image(systemName: "dice.fill")
                Text("Öner")
            }
            .font(.bodyText)
            .foregroundStyle(theme.accent)
            .padding(.horizontal, Space.s3).padding(.vertical, Space.s2)
            .background(theme.accent.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.pressable)
    }

    private func pickCard(icon: String, title: String, detail: String,
                          tint: Color, selected: Bool,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Space.s1) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(selected ? tint : theme.textSecondary)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15)).foregroundStyle(tint)
                    }
                }
                Text(title).font(.appText(14, .bold)).foregroundStyle(theme.text)
                Text(detail).font(.appText(10.5, .medium))
                    .foregroundStyle(theme.subtle)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
            .padding(Space.s3)
            .background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(RoundedRectangle(cornerRadius: Radius.m)
                .stroke(selected ? tint.opacity(0.7) : theme.hairline,
                        lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.pressable)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
