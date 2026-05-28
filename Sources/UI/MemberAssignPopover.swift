import SwiftUI

/// Bir takım üyesinin proje atamasını değiştiren tekrar-kullanılabilir popover.
/// Roster satırındaki proje rozetine tıklanınca açılır; üyeyi başka projeye atar
/// ya da boşa alır. Şirket içi kaynak yönetimi hissi — kim neye çalışıyor görünür ve değiştirilebilir.
struct MemberAssignPopover: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    let memberID: UUID
    var onDismiss: () -> Void

    private var member: TeamMember? { model.members.first(where: { $0.id == memberID }) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            header
            Divider().overlay(theme.hairline)
            ScrollView {
                VStack(spacing: 4) {
                    // "Boşa al" — proje-bağımsız çalışsın.
                    unassignRow
                    ForEach(model.projects) { project in
                        projectRow(project)
                    }
                }
            }
            .frame(maxHeight: 280)
        }
        .padding(Space.s3)
        .frame(width: 240)
        .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(theme.hairline))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("ATA").font(.eyebrow).kerning(0.8).foregroundStyle(theme.subtle)
            if let m = member {
                Text(m.fullName).font(.appText(13, .bold)).foregroundStyle(theme.text)
                    .lineLimit(1)
                Text(Balance.departments[m.deptIndex].name)
                    .font(.numberXS).foregroundStyle(theme.subtle)
            }
        }
    }

    private var unassignRow: some View {
        let isSelected = member?.assignedProjectID == nil
        return Button {
            Haptics.selection()
            model.assign(memberID: memberID, toProject: nil)
            onDismiss()
        } label: {
            HStack(spacing: Space.s2) {
                Image(systemName: "circle.dotted")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.subtle)
                    .frame(width: 22)
                Text("Boşa al")
                    .font(.appText(12, .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.horizontal, Space.s2).padding(.vertical, 6)
            .background(isSelected ? theme.accent.opacity(0.08) : Color.clear,
                        in: RoundedRectangle(cornerRadius: Radius.s))
        }
        .buttonStyle(.pressable)
    }

    private func projectRow(_ project: ProjectState) -> some View {
        let isSelected = member?.assignedProjectID == project.id
        let cat = Balance.projectCategory(project.category)
        let teamSize = model.teamSize(forProject: project.id)
        return Button {
            Haptics.selection()
            model.assign(memberID: memberID, toProject: project.id)
            onDismiss()
        } label: {
            HStack(spacing: Space.s2) {
                Image(systemName: cat?.icon ?? "shippingbox.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(project.isLive ? theme.accent : theme.textSecondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(project.name).font(.appText(12, .semibold)).foregroundStyle(theme.text)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(project.isLive ? "YAYINDA" : "GELİŞTİRME")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(project.isLive ? Palette.success : theme.accent)
                        Text("· \(teamSize) kişi")
                            .font(.numberXS).foregroundStyle(theme.subtle)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.horizontal, Space.s2).padding(.vertical, 6)
            .background(isSelected ? theme.accent.opacity(0.08) : Color.clear,
                        in: RoundedRectangle(cornerRadius: Radius.s))
        }
        .buttonStyle(.pressable)
    }
}
