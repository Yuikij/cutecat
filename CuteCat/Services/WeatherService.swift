import Foundation

enum WeatherCondition: String, Sendable {
    case clear
    case cloudy
    case rain
    case snow
    case fog

    var particles: [String] {
        switch self {
        case .clear: []
        case .cloudy: ["☁️"]
        case .rain: ["💧", "💧", "💧"]
        case .snow: ["❄️", "❄️", "✨"]
        case .fog: ["🌫️"]
        }
    }

    var label: String {
        switch self {
        case .clear: "晴"
        case .cloudy: "多云"
        case .rain: "雨"
        case .snow: "雪"
        case .fog: "雾"
        }
    }

    var icon: String {
        switch self {
        case .clear: "☀️"
        case .cloudy: "⛅"
        case .rain: "🌧️"
        case .snow: "🌨️"
        case .fog: "🌫️"
        }
    }
}
