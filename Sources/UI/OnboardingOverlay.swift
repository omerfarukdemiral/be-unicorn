import SwiftUI

/// İlk açılış: oyunu 3 adımda tanıtır.
struct OnboardingOverlay: View {
    @ObservedObject var model: GameModel
    var theme: Theme
    @State private var step = 0

    /// Adım başlığı ve açıklaması — her adım tek cümle + ikon.
    private let steps: [(String, String, String)] = [
        (Icons.Screen.onboard0, "Garajdan Zirveye", "Bir startup kurdun. Hedefin: $1 milyar değerlemeye ulaşıp Unicorn olmak."),
        (Icons.Screen.onboard1, "Ekibini Büyüt",    "Mühendis, pazarlamacı, satışçı işe al. Her çalışan maaş ister — nakdini izle."),
        (Icons.Screen.onboard2, "Kararlar Seni Bekler", "Yatırımcılar, krizler, basın... Doğru kararlar seni zirveye taşır."),
        ("trophy.fill",         "Lig & Çeyrek",     "Her çeyrek performansın puanlanır; iyi oyna, Garaj Ligi'nden Unicorn Ligi'ne yüksel."),
        ("target",              "Günlük Hedef & Streak", "Her gün küçük bir hedefi tamamla, streak'ini büyüt ve seriyi koparma."),
        ("flag.checkered",      "Haftalık Sprint",  "Haftalık sprintte rakiplerinle yarış, ilk sırada bitirip ödül kap."),
        ("square.grid.3x3.fill", "Ofis Krokisi",    "Ofisini koltuk ve eşyalarla döşe; her yerleşim ekibine küçük bonuslar verir.")
    ]

    var body: some View {
        ZStack {
            // Taban + evre accent'inden çok hafif üst gradient.
            Color(hex: "14161F").ignoresSafeArea()
            LinearGradient(colors: [theme.accent.opacity(0.1), .clear],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
            VStack(spacing: Space.s5) {
                Spacer()
                // Her adım için büyük SF Symbol hero ikonu
                Image(systemName: steps[step].0)
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(theme.accent)
                    .symbolEffect(.pulse)
                    .padding(.bottom, Space.s1)
                    .id(step)
                    .transition(.scale.combined(with: .opacity))
                Text(steps[step].1).font(.appNumber(26, .heavy))
                    .foregroundStyle(theme.text)
                Text(steps[step].2).font(.bodyL)
                    .foregroundStyle(theme.textSecondary).multilineTextAlignment(.center)
                    .padding(.horizontal, Space.s6)
                Spacer()
                HStack(spacing: Space.s1) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Capsule().fill(i == step ? theme.accent : theme.textQuaternary)
                            .frame(width: i == step ? 20 : 8, height: 8)
                            .animation(Motion.smooth, value: step)
                    }
                }
                Button {
                    Haptics.tap()
                    if step < steps.count - 1 { withAnimation(Motion.snappy) { step += 1 } }
                    else { model.completeOnboarding() }
                } label: {
                    HStack(spacing: Space.s2) {
                        Text(step < steps.count - 1 ? "Devam" : "Şirketi Kur")
                        if step == steps.count - 1 {
                            Image(systemName: "arrow.right.circle.fill")
                        }
                    }
                    .font(.bodyL)
                    .modifier(AppButton.primary(theme))
                }
                .buttonStyle(.pressable)
                .padding(.horizontal, Space.s5).padding(.bottom, Space.s6)
            }
        }
    }
}
