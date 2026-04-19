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
}

struct CozyBackground: View {
    var body: some View {
        let hour = Calendar.current.component(.hour, from: .now)

        LinearGradient(
            colors: gradientColors(for: hour),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func gradientColors(for hour: Int) -> [Color] {
        switch hour {
        case 6..<10:
            return [Color(red: 1.0, green: 0.92, blue: 0.82), CozyPalette.cream]
        case 10..<16:
            return [CozyPalette.sky.opacity(0.3), CozyPalette.cream]
        case 16..<19:
            return [Color(red: 1.0, green: 0.85, blue: 0.72), CozyPalette.peach.opacity(0.4)]
        case 19..<22:
            return [Color(red: 0.25, green: 0.22, blue: 0.35), Color(red: 0.18, green: 0.15, blue: 0.28)]
        default:
            return [Color(red: 0.12, green: 0.10, blue: 0.20), Color(red: 0.08, green: 0.06, blue: 0.14)]
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
                    .fill(CozyPalette.card.opacity(0.92))
                    .shadow(color: CozyPalette.shadow, radius: 8, y: 4)
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
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(tint.opacity(0.12))
                    )

                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(CozyPalette.plum)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(CozyPalette.card.opacity(0.85))
                    .shadow(color: CozyPalette.shadow, radius: 4, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
