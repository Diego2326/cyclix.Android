import CoreLocation
import Foundation

typealias CyclixJSONObject = [String: Any]

struct CyclixWatchAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

enum CyclixWatchError: LocalizedError {
    case invalidResponse
    case missingToken
    case message(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "La respuesta del servidor no es valida."
        case .missingToken:
            return "No hay una sesion activa."
        case .message(let message):
            return message
        }
    }
}

enum CyclixFormatters {
    static let money: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "GTQ"
        formatter.currencySymbol = "Q"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_GT")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_GT")
        formatter.timeStyle = .short
        return formatter
    }()
}

func cyclixString(_ value: Any?) -> String? {
    guard let value else { return nil }
    let text = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : text
}

func cyclixInt(_ value: Any?) -> Int? {
    if let value = value as? Int { return value }
    if let value = value as? Double { return Int(value) }
    if let text = cyclixString(value) { return Int(text) }
    return nil
}

func cyclixDouble(_ value: Any?) -> Double? {
    if let value = value as? Double { return value }
    if let value = value as? Int { return Double(value) }
    if let value = value as? NSNumber { return value.doubleValue }
    if let text = cyclixString(value) {
        return Double(text.replacingOccurrences(of: ",", with: "."))
    }
    return nil
}

func cyclixBool(_ value: Any?) -> Bool? {
    if let value = value as? Bool { return value }
    if let value = cyclixString(value) {
        return ["true", "1", "yes", "si"].contains(value.lowercased())
    }
    return nil
}

func cyclixMap(_ value: Any?) -> CyclixJSONObject? {
    if let value = value as? CyclixJSONObject { return value }
    if let value = value as? [String: String] { return value }
    if let value = value as? [AnyHashable: Any] {
        var mapped: CyclixJSONObject = [:]
        for (key, val) in value {
            if let key = key as? String {
                mapped[key] = val
            }
        }
        return mapped.isEmpty ? nil : mapped
    }
    return nil
}

func cyclixMapArray(_ value: Any?) -> [CyclixJSONObject] {
    guard let array = value as? [Any] else { return [] }
    return array.compactMap { cyclixMap($0) }
}

func cyclixDate(_ value: Any?) -> Date? {
    guard let text = cyclixString(value) else { return nil }
    return ISO8601DateFormatter.full.date(from: text)
        ?? ISO8601DateFormatter.fractional.date(from: text)
        ?? CyclixFallbackDateFormatter.shared.date(from: text)
}

func cyclixCoordinate(from station: CyclixStationSummary) -> CLLocationCoordinate2D? {
    guard let latitude = station.latitude, let longitude = station.longitude else {
        return nil
    }
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
}

func cyclixMoney(_ value: Double, currencyCode: String = "GTQ") -> String {
    CyclixFormatters.money.currencyCode = currencyCode
    CyclixFormatters.money.currencySymbol = currencyCode == "GTQ" ? "Q" : currencyCode + " "
    return CyclixFormatters.money.string(from: NSNumber(value: value)) ?? "\(currencyCode) \(value)"
}

func cyclixDuration(_ duration: TimeInterval) -> String {
    let totalSeconds = max(Int(duration), 0)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
}

func cyclixDistance(_ meters: Double?) -> String {
    guard let meters else { return "Sin ubicacion" }
    if meters < 1000 {
        return "\(Int(meters.rounded())) m"
    }
    return String(format: "%.1f km", meters / 1000)
}

func cyclixBikeIdentifier(from raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return trimmed }

    if let url = URL(string: trimmed), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
        let queryItems = components.queryItems ?? []
        if let match = queryItems.first(where: { ["bikeId", "bike", "id"].contains($0.name) }),
           let value = match.value,
           !value.isEmpty {
            return value
        }

        if let lastPath = components.path.split(separator: "/").last, !lastPath.isEmpty {
            return String(lastPath)
        }
    }

    return trimmed
}

extension ISO8601DateFormatter {
    static let full: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

enum CyclixFallbackDateFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
