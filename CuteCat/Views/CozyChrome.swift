import SwiftUI

enum CozyPalette {
    static let cream = Color(red: 0.99, green: 0.96, blue: 0.92)
    static let warmWhite = Color(red: 0.98, green: 0.97, blue: 0.95)
    static let peach = Color(red: 0.98, green: 0.82, blue: 0.76)
    static let blush = Color(red: 0.96, green: 0.75, blue: 0.78)
    static let rose = Color(red: 0.90, green: 0.55, blue: 0.60)
    static let plum = Color(red: 0.35, green: 0.22, blue: 0.25)
    static let wood = Color(red: 0.55, green: 0.42, blue: 0.35)
    static let moss = Color(red: 0.45, green: 0.62, blue: 0.52)
    static let meadow = Color(red: 0.72, green: 0.85, blue: 0.68)
    static let sky = Color(red: 0.70, green: 0.82, blue: 0.92)
    static let card = Color(red: 1.0, green: 0.98, blue: 0.96)
    static let shadow = Color(red: 0.35, green: 0.22, blue: 0.25).opacity(0.06)

    static var isNight: Bool {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour >= 19 || hour < 6
    }

    static var cardAdaptive: Color {
        isNight ? Color.white.opacity(0.08) : card.opacity(0.85)
    }

    static var shadowAdaptive: Color {
        isNight ? Color.black.opacity(0.2) : shadow
    }

    static var textPrimary: Color {
        isNight ? cream : plum
    }

    static var textSecondary: Color {
        isNight ? cream.opacity(0.6) : wood
    }
}

struct CozyBackground: View {
    var weather: WeatherCondition = .clear

    var body: some View {
        let hour = Calendar.current.component(.hour, from: .now)

        ZStack {
            LinearGradient(
                colors: gradientColors(for: hour, weather: weather),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if !weather.particles.isEmpty {
                WeatherParticleView(particles: weather.particles, isRain: weather == .rain)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
    }

    private func gradientColors(for hour: Int, weather: WeatherCondition) -> [Color] {
        let base: [Color]
        switch hour {
        case 6..<10:
            base = [Color(red: 1.0, green: 0.92, blue: 0.82), CozyPalette.cream]
        case 10..<16:
            base = [CozyPalette.sky.opacity(0.3), CozyPalette.cream]
        case 16..<19:
            base = [Color(red: 1.0, green: 0.85, blue: 0.72), CozyPalette.peach.opacity(0.4)]
        case 19..<22:
            base = [Color(red: 0.25, green: 0.22, blue: 0.35), Color(red: 0.18, green: 0.15, blue: 0.28)]
        default:
            base = [Color(red: 0.12, green: 0.10, blue: 0.20), Color(red: 0.08, green: 0.06, blue: 0.14)]
        }

        switch weather {
        case .rain:
            return base.map { $0.opacity(0.85) }
        case .fog:
            return base.map { $0.opacity(0.7) }
        case .snow:
            return base.map { $0.opacity(0.9) }
        default:
            return base
        }
    }
}

struct WeatherParticleView: View {
    let particles: [String]
    let isRain: Bool

    @State private var items: [ParticleItem] = []

    struct ParticleItem: Identifiable {
        let id = UUID()
        var emoji: String
        var x: CGFloat
        var startY: CGFloat
        var endY: CGFloat
        var duration: Double
        var delay: Double
        var size: CGFloat
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(items) { item in
                    FallingParticle(item: item)
                }
            }
            .onAppear {
                generateParticles(in: geo.size)
            }
        }
    }

    private func generateParticles(in size: CGSize) {
        let count = isRain ? 30 : 15
        items = (0..<count).map { _ in
            ParticleItem(
                emoji: particles.randomElement() ?? "💧",
                x: CGFloat.random(in: 0...size.width),
                startY: CGFloat.random(in: -100 ... -20),
                endY: size.height + 40,
                duration: isRain ? Double.random(in: 1.0...2.0) : Double.random(in: 4.0...8.0),
                delay: Double.random(in: 0...3),
                size: CGFloat.random(in: 10...18)
            )
        }
    }
}

struct FallingParticle: View {
    let item: WeatherParticleView.ParticleItem
    @State private var yOffset: CGFloat = 0

    var body: some View {
        Text(item.emoji)
            .font(.system(size: item.size))
            .position(x: item.x, y: item.startY + yOffset)
            .opacity(0.6)
            .onAppear {
                withAnimation(
                    .linear(duration: item.duration)
                    .delay(item.delay)
                    .repeatForever(autoreverses: false)
                ) {
                    yOffset = item.endY - item.startY
                }
            }
    }
}

struct CozyPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(CozyPalette.cardAdaptive)
                    .shadow(color: CozyPalette.shadowAdaptive, radius: 8, y: 4)
            )
    }
}

struct CozyActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(tint.opacity(CozyPalette.isNight ? 0.15 : 0.08))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(tint.opacity(0.12), lineWidth: 0.5)
                    )

                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(CozyPalette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel(title)
    }
}

struct SoftPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
