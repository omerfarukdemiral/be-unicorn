import SwiftUI

/// Büyük overlay/hero anları için minimal, sleek SwiftUI Path/Shape illüstrasyonları.
/// Aurora dark üzerinde tutarlı; asset gerektirmez. Her biri accent rengi alır
/// (mevcut Theme.accent ile entegre olur — evreye göre değişir).
///
/// Kullanım:
///   MountainPathHero(accent: theme.accent)
///   UnicornHero(accent: Palette.unicorn)
///   MedalHero(accent: Palette.gold)
///   FundingCheckHero(accent: theme.accent)
///   HorizonChartHero(accent: theme.accent)

// MARK: - StarShape yardımcısı (5-köşeli yıldız)

struct StarShape: Shape {
    var points: Int = 5
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = min(rect.width, rect.height) / 2
        let innerR = outerR * 0.45
        let step = .pi / Double(points)
        for i in 0..<(points * 2) {
            let r = (i % 2 == 0) ? outerR : innerR
            let angle = -Double.pi / 2 + Double(i) * step
            let pt = CGPoint(x: center.x + CGFloat(cos(angle)) * r,
                             y: center.y + CGFloat(sin(angle)) * r)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - 1) MountainPathHero — Onboarding "Garajdan Zirveye"

/// İki katmanlı stilize dağ + tepe noktasına çıkan kesik patika + zirve yıldızı.
/// Yükseliş/yolculuk metaforu.
struct MountainPathHero: View {
    let accent: Color
    let size: CGFloat
    init(accent: Color, size: CGFloat = 96) { self.accent = accent; self.size = size }

    var body: some View {
        Canvas { ctx, _ in
            // Arka dağ (büyük, koyu accent)
            var back = Path()
            back.move(to: CGPoint(x: 0.05 * size, y: 0.92 * size))
            back.addLine(to: CGPoint(x: 0.42 * size, y: 0.22 * size))
            back.addLine(to: CGPoint(x: 0.74 * size, y: 0.92 * size))
            back.closeSubpath()
            ctx.fill(back, with: .color(accent.opacity(0.32)))

            // Ön dağ (gradient accent)
            var front = Path()
            front.move(to: CGPoint(x: 0.28 * size, y: 0.92 * size))
            front.addLine(to: CGPoint(x: 0.62 * size, y: 0.42 * size))
            front.addLine(to: CGPoint(x: 0.96 * size, y: 0.92 * size))
            front.closeSubpath()
            ctx.fill(front, with: .linearGradient(
                Gradient(colors: [accent, accent.opacity(0.55)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size)
            ))

            // Kar şapkası (ön dağ tepesi)
            var snow = Path()
            snow.move(to: CGPoint(x: 0.55 * size, y: 0.50 * size))
            snow.addLine(to: CGPoint(x: 0.62 * size, y: 0.42 * size))
            snow.addLine(to: CGPoint(x: 0.69 * size, y: 0.50 * size))
            snow.addQuadCurve(to: CGPoint(x: 0.55 * size, y: 0.50 * size),
                              control: CGPoint(x: 0.62 * size, y: 0.55 * size))
            snow.closeSubpath()
            ctx.fill(snow, with: .color(.white.opacity(0.85)))

            // Çıkış patikası (kesik çizgi)
            var path = Path()
            path.move(to: CGPoint(x: 0.10 * size, y: 0.86 * size))
            path.addQuadCurve(to: CGPoint(x: 0.30 * size, y: 0.62 * size),
                              control: CGPoint(x: 0.14 * size, y: 0.74 * size))
            path.addQuadCurve(to: CGPoint(x: 0.40 * size, y: 0.30 * size),
                              control: CGPoint(x: 0.38 * size, y: 0.46 * size))
            ctx.stroke(path, with: .color(.white.opacity(0.65)),
                       style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [3, 4]))
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topLeading) {
            // Zirve yıldızı (arka dağ tepesinde, küçük glow ile)
            StarShape()
                .fill(.white)
                .frame(width: 14, height: 14)
                .shadow(color: accent.opacity(0.6), radius: 6)
                .offset(x: 0.36 * size, y: 0.15 * size)
        }
    }
}

// MARK: - 2) UnicornHero — Win

/// Stilize unicorn başı + boynuz + yele. "Tek boynuz" zaferi.
struct UnicornHero: View {
    let accent: Color
    let size: CGFloat
    init(accent: Color = Palette.unicorn, size: CGFloat = 110) { self.accent = accent; self.size = size }

    var body: some View {
        ZStack {
            // Sade radyal aura
            Circle()
                .fill(LinearGradient(colors: [accent.opacity(0.28), .clear],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size, height: size)

            // Baş silüeti (yumuşak yatık)
            Canvas { ctx, _ in
                var head = Path()
                head.move(to: CGPoint(x: 0.28 * size, y: 0.86 * size))
                head.addQuadCurve(to: CGPoint(x: 0.18 * size, y: 0.55 * size),
                                  control: CGPoint(x: 0.14 * size, y: 0.74 * size))
                head.addQuadCurve(to: CGPoint(x: 0.40 * size, y: 0.32 * size),
                                  control: CGPoint(x: 0.16 * size, y: 0.38 * size))
                head.addLine(to: CGPoint(x: 0.50 * size, y: 0.04 * size))      // horn tip
                head.addLine(to: CGPoint(x: 0.58 * size, y: 0.32 * size))      // horn base
                head.addQuadCurve(to: CGPoint(x: 0.80 * size, y: 0.50 * size),
                                  control: CGPoint(x: 0.72 * size, y: 0.30 * size))
                head.addQuadCurve(to: CGPoint(x: 0.84 * size, y: 0.74 * size),
                                  control: CGPoint(x: 0.88 * size, y: 0.60 * size))
                head.addQuadCurve(to: CGPoint(x: 0.62 * size, y: 0.92 * size),
                                  control: CGPoint(x: 0.82 * size, y: 0.90 * size))
                head.addLine(to: CGPoint(x: 0.28 * size, y: 0.86 * size))
                head.closeSubpath()
                ctx.fill(head, with: .linearGradient(
                    Gradient(colors: [accent, accent.opacity(0.7)]),
                    startPoint: CGPoint(x: size * 0.5, y: 0),
                    endPoint: CGPoint(x: size * 0.5, y: size)
                ))

                // Boynuz şeritleri
                var horn = Path()
                horn.move(to: CGPoint(x: 0.485 * size, y: 0.13 * size))
                horn.addLine(to: CGPoint(x: 0.520 * size, y: 0.18 * size))
                horn.move(to: CGPoint(x: 0.495 * size, y: 0.22 * size))
                horn.addLine(to: CGPoint(x: 0.540 * size, y: 0.27 * size))
                ctx.stroke(horn, with: .color(.white.opacity(0.75)), lineWidth: 1.4)

                // Yele (akışkan iki kıvrım)
                var mane1 = Path()
                mane1.move(to: CGPoint(x: 0.34 * size, y: 0.46 * size))
                mane1.addQuadCurve(to: CGPoint(x: 0.20 * size, y: 0.66 * size),
                                   control: CGPoint(x: 0.22 * size, y: 0.50 * size))
                mane1.addQuadCurve(to: CGPoint(x: 0.30 * size, y: 0.82 * size),
                                   control: CGPoint(x: 0.18 * size, y: 0.78 * size))
                ctx.stroke(mane1, with: .color(.white.opacity(0.55)), lineWidth: 2)

                var mane2 = Path()
                mane2.move(to: CGPoint(x: 0.40 * size, y: 0.52 * size))
                mane2.addQuadCurve(to: CGPoint(x: 0.28 * size, y: 0.68 * size),
                                   control: CGPoint(x: 0.30 * size, y: 0.55 * size))
                ctx.stroke(mane2, with: .color(.white.opacity(0.30)), lineWidth: 1.4)
            }
            .frame(width: size, height: size)

            // Göz (beyaz pupilli)
            ZStack {
                Circle().fill(.white).frame(width: 6, height: 6)
                Circle().fill(.black.opacity(0.85)).frame(width: 3, height: 3)
            }
            .offset(x: 0.08 * size, y: -0.02 * size)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 3) MedalHero — Season Finale

/// Madalya: kurdele V + altın disk + iç yıldız.
struct MedalHero: View {
    let accent: Color
    let size: CGFloat
    init(accent: Color = Palette.gold, size: CGFloat = 96) { self.accent = accent; self.size = size }

    var body: some View {
        ZStack {
            // Kurdele (V şeklinde, accent renk)
            Canvas { ctx, _ in
                var ribbon = Path()
                ribbon.move(to: CGPoint(x: 0.28 * size, y: 0.06 * size))
                ribbon.addLine(to: CGPoint(x: 0.50 * size, y: 0.58 * size))
                ribbon.addLine(to: CGPoint(x: 0.72 * size, y: 0.06 * size))
                ribbon.addLine(to: CGPoint(x: 0.62 * size, y: 0.06 * size))
                ribbon.addLine(to: CGPoint(x: 0.50 * size, y: 0.40 * size))
                ribbon.addLine(to: CGPoint(x: 0.38 * size, y: 0.06 * size))
                ribbon.closeSubpath()
                ctx.fill(ribbon, with: .linearGradient(
                    Gradient(colors: [accent.opacity(0.85), accent.opacity(0.55)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size * 0.6)
                ))
            }
            .frame(width: size, height: size)

            // Madalya diski (altın, hafif gölge)
            Circle()
                .fill(LinearGradient(colors: [Palette.gold, Palette.gold.opacity(0.65)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 0.56 * size, height: 0.56 * size)
                .overlay(
                    Circle().stroke(.white.opacity(0.4), lineWidth: 1.5)
                )
                .offset(y: 0.18 * size)
                .shadow(color: Palette.gold.opacity(0.35), radius: 8, y: 2)

            // İç yıldız
            StarShape()
                .fill(.white.opacity(0.92))
                .frame(width: 0.22 * size, height: 0.22 * size)
                .offset(y: 0.18 * size)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 4) FundingCheckHero — Funding Round

/// Yatırım çeki: hafif eğik beyaz kağıt + $ + onay mührü + imza çizgileri.
struct FundingCheckHero: View {
    let accent: Color
    let size: CGFloat
    init(accent: Color, size: CGFloat = 96) { self.accent = accent; self.size = size }

    var body: some View {
        ZStack {
            // Arka radyal
            Circle()
                .fill(LinearGradient(colors: [accent.opacity(0.20), .clear],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size, height: size)

            // Çek kağıdı
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [.white.opacity(0.96), .white.opacity(0.78)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 0.78 * size, height: 0.48 * size)
                .overlay(
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("$")
                                .font(.system(size: 0.22 * size, weight: .black, design: .rounded))
                                .foregroundStyle(accent)
                            Spacer()
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 0.14 * size, weight: .bold))
                                .foregroundStyle(Palette.gold)
                        }
                        Capsule().fill(accent.opacity(0.6)).frame(height: 3)
                        Capsule().fill(.black.opacity(0.18)).frame(height: 2).frame(maxWidth: 0.50 * size)
                        Capsule().fill(.black.opacity(0.18)).frame(height: 2).frame(maxWidth: 0.36 * size)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                )
                .rotationEffect(.degrees(-6))
                .shadow(color: .black.opacity(0.22), radius: 8, y: 3)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 5) HorizonChartHero — Bankruptcy / Post-Mortem

/// Sakin yatay çizgi + iniş+toparlanan grafik + ufukta küçük yeni-başlangıç noktası.
/// Suçlayıcı değil; "düştü, ufukta yeniden başlangıç" hissi.
struct HorizonChartHero: View {
    let accent: Color
    let size: CGFloat
    init(accent: Color, size: CGFloat = 96) { self.accent = accent; self.size = size }

    var body: some View {
        Canvas { ctx, _ in
            // Yumuşak ufuk gradyanı (warning-amber → siyah)
            var bg = Path()
            bg.addEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
            ctx.fill(bg, with: .linearGradient(
                Gradient(colors: [Palette.warning.opacity(0.22), .clear]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size)
            ))

            // Ufuk çizgisi
            var horizon = Path()
            horizon.move(to: CGPoint(x: 0.08 * size, y: 0.66 * size))
            horizon.addLine(to: CGPoint(x: 0.92 * size, y: 0.66 * size))
            ctx.stroke(horizon, with: .color(.white.opacity(0.30)), lineWidth: 1)

            // Düşen-toparlanan grafik çizgisi
            var chart = Path()
            chart.move(to: CGPoint(x: 0.12 * size, y: 0.28 * size))
            chart.addCurve(to: CGPoint(x: 0.55 * size, y: 0.62 * size),
                           control1: CGPoint(x: 0.22 * size, y: 0.32 * size),
                           control2: CGPoint(x: 0.40 * size, y: 0.62 * size))
            chart.addQuadCurve(to: CGPoint(x: 0.88 * size, y: 0.50 * size),
                               control: CGPoint(x: 0.72 * size, y: 0.66 * size))
            ctx.stroke(chart, with: .linearGradient(
                Gradient(colors: [Palette.warning, accent.opacity(0.85)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: size, y: 0)
            ), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            // Yeniden başlangıç noktası (sağ-üstte)
            Circle()
                .fill(accent)
                .frame(width: 10, height: 10)
                .shadow(color: accent.opacity(0.55), radius: 5)
                .offset(x: -0.08 * size, y: 0.42 * size)
        }
    }
}
