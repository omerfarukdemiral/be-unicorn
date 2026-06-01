import SwiftUI

/// Ayarlar & Profil sayfası — HUD'daki dişli ikonundan açılır.
/// Profil özeti + ses/müzik/titreşim/bildirim + para birimi + "Baştan Başla"
/// (şirket+proje kuruluş ekranına döner). Sade, sleek dark dil.
struct SettingsView: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    @Binding var soundEnabled: Bool
    let onClose: () -> Void

    // Göstermelik/yerel ayarlar (kalıcı UI tercihleri — ekonomiye etki yok).
    @AppStorage("pref.music")   private var musicOn = true
    @AppStorage("pref.haptics") private var hapticsOn = true
    @AppStorage("pref.notifs")  private var notifsOn = true
    @State private var confirmReset = false

    var body: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Space.s4) {
                    header
                    profileCard
                    section("SES & HİS") {
                        toggleRow("Ses efektleri", icon: "speaker.wave.2.fill", isOn: Binding(
                            get: { soundEnabled },
                            set: { _ in soundEnabled = AudioManager.shared.toggle(); Haptics.selection() }))
                        divider
                        toggleRow("Müzik", icon: "music.note", isOn: $musicOn)
                        divider
                        toggleRow("Titreşim", icon: "iphone.radiowaves.left.and.right", isOn: $hapticsOn)
                    }
                    section("OYUN") {
                        // Para birimi seçici şimdilik kapalı — yalnızca dolar (kullanıcı isteği).
                        toggleRow("Bildirimler", icon: "bell.fill", isOn: $notifsOn)
                    }
                    section("HESAP") {
                        resetRow
                    }
                    Text("Unicorn — Garajdan Zirveye · v1.0")
                        .font(.labelText).foregroundStyle(theme.subtle)
                        .padding(.top, Space.s2)
                    Spacer(minLength: Space.s5)
                }
                .padding(.horizontal, Space.s4)
                .padding(.top, Space.s3)
            }
        }
        .alert("Baştan başla?", isPresented: $confirmReset) {
            Button("Vazgeç", role: .cancel) {}
            Button("Baştan Başla", role: .destructive) {
                Haptics.medium(); model.resetToSetup(); onClose()
            }
        } message: {
            Text("Tüm ilerlemen (şirket, ekip, evre, lig) silinir ve yeni şirket kuruluş ekranına dönersin. Bu geri alınamaz.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("Ayarlar").font(.titleL).foregroundStyle(theme.text)
            Spacer()
            Button { Haptics.tap(); onClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.subtle)
                    .frame(width: 32, height: 32)
                    .background(theme.surfaceHigh, in: Circle())
                    .overlay(Circle().stroke(theme.hairline))
            }
            .buttonStyle(.pressable)
        }
        .padding(.top, Space.s2)
    }

    // MARK: Profil kartı

    private var profileCard: some View {
        HStack(spacing: Space.s3) {
            ZStack {
                Circle().fill(theme.accent.opacity(0.18)).frame(width: 52, height: 52)
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(theme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(model.founderMember?.fullName ?? "Kurucu")
                    .font(.appText(16, .bold)).foregroundStyle(theme.text)
                Text(model.companyName.isEmpty ? "—" : model.companyName)
                    .font(.appText(13, .medium)).foregroundStyle(theme.textSecondary)
                Text("\(model.currentStage.name) · \(model.currentLeague.name)")
                    .font(.eyebrow).kerning(0.6).foregroundStyle(theme.accent)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(theme.hairline, lineWidth: 1))
    }

    // MARK: Bölüm sarmalayıcı

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text(title).font(.eyebrow).kerning(1).foregroundStyle(theme.subtle)
                .padding(.leading, Space.s1)
            VStack(spacing: 0) { content() }
                .background(theme.surfaceLow, in: RoundedRectangle(cornerRadius: Radius.m))
                .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(theme.hairline, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle().fill(theme.hairline).frame(height: 1).padding(.leading, 48)
    }

    // MARK: Satırlar

    private func toggleRow(_ label: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Space.s3) {
            iconBadge(icon)
            Text(label).font(.bodyText).foregroundStyle(theme.text)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(theme.accent)
        }
        .padding(.horizontal, Space.s3).padding(.vertical, Space.s3)
    }

    private var resetRow: some View {
        Button { Haptics.tap(); confirmReset = true } label: {
            HStack(spacing: Space.s3) {
                iconBadge("arrow.counterclockwise", tint: Palette.danger)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Baştan Başla").font(.bodyText).foregroundStyle(Palette.danger)
                    Text("Yeni şirket kur — ilerleme silinir")
                        .font(.labelText).foregroundStyle(theme.subtle)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.subtle)
            }
            .padding(.horizontal, Space.s3).padding(.vertical, Space.s3)
        }
        .buttonStyle(.pressable)
    }

    private func iconBadge(_ icon: String, tint: Color? = nil) -> some View {
        let c = tint ?? theme.accent
        return Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(c)
            .frame(width: 30, height: 30)
            .background(c.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.s))
    }
}
