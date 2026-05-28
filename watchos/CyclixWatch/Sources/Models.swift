import CoreLocation
import Foundation

struct CyclixUser: Identifiable, Equatable {
    let id: String
    let fullName: String
    let email: String
    let phone: String
    let role: String

    init(dictionary: [String: Any]) {
        id = CyclixParsers.string(dictionary["id"]) ?? UUID().uuidString
        let fullName = CyclixParsers.string(dictionary["fullName"]) ?? ""
        let firstName = CyclixParsers.string(dictionary["firstName"]) ?? ""
        let lastName = CyclixParsers.string(dictionary["lastName"]) ?? ""

        if !fullName.isEmpty {
            self.fullName = fullName
        } else {
            self.fullName = [firstName, lastName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }

        email = CyclixParsers.string(dictionary["email"]) ?? "Sin correo"
        phone = CyclixParsers.string(dictionary["phone"]) ?? "Sin teléfono"
        role = CyclixParsers.string(dictionary["role"]) ?? "USER"
    }
}

struct CyclixWallet: Equatable {
    let balance: Double
    let currency: String

    init(dictionary: [String: Any]) {
        balance = CyclixParsers.double(dictionary["balance"]) ?? 0
        currency = CyclixParsers.string(dictionary["currency"]) ?? "GTQ"
    }

    var balanceText: String {
        "\(currency) \(balance.formatted(.number.precision(.fractionLength(2))))"
    }
}

struct CyclixWalletTransaction: Identifiable, Equatable {
    let id: String
    let type: String
    let description: String
    let amount: Double
    let createdAt: Date?

    init(dictionary: [String: Any]) {
        id = CyclixParsers.string(dictionary["id"]) ?? UUID().uuidString
        type = CyclixParsers.string(dictionary["type"]) ?? "MOVEMENT"
        description = CyclixParsers.string(dictionary["description"])
            ?? CyclixParsers.string(dictionary["concept"])
            ?? "Movimiento"
        amount = CyclixParsers.double(dictionary["amount"]) ?? 0
        createdAt = CyclixParsers.date(dictionary["createdAt"])
    }

    var amountText: String {
        "GTQ \(amount.formatted(.number.precision(.fractionLength(2))))"
    }
}

struct CyclixTrip: Identifiable, Equatable {
    let id: String
    let bikeId: String
    let status: String
    let startedAt: Date?
    let endedAt: Date?
    let totalAmount: Double?
    let distanceKm: Double?
    let billableMinutes: Int?

    init(dictionary: [String: Any]) {
        id = CyclixParsers.string(dictionary["id"]) ?? UUID().uuidString
        bikeId = CyclixParsers.string(dictionary["bikeId"])
            ?? CyclixParsers.string(dictionary["bike_id"])
            ?? CyclixParsers.string(dictionary["bicicletaId"])
            ?? "?"
        status = CyclixParsers.string(dictionary["status"])
            ?? CyclixParsers.string(dictionary["tripStatus"])
            ?? "UNKNOWN"
        startedAt = CyclixParsers.date(dictionary["startedAt"])
            ?? CyclixParsers.date(dictionary["startTime"])
            ?? CyclixParsers.date(dictionary["createdAt"])
        endedAt = CyclixParsers.date(dictionary["endedAt"])
            ?? CyclixParsers.date(dictionary["finishedAt"])
            ?? CyclixParsers.date(dictionary["endTime"])
        totalAmount = CyclixParsers.double(dictionary["totalAmount"])
            ?? CyclixParsers.double(dictionary["amount"])
            ?? CyclixParsers.double(dictionary["total"])
        distanceKm = CyclixParsers.double(dictionary["distanceKm"])
            ?? CyclixParsers.double(dictionary["distance"])
        billableMinutes = CyclixParsers.int(dictionary["billableMinutes"])
            ?? CyclixParsers.int(dictionary["minutes"])
    }

    var isActive: Bool {
        let normalized = status.uppercased()
        if normalized == "ACTIVE" || normalized == "IN_PROGRESS" || normalized == "ONGOING" || normalized == "STARTED" {
            return true
        }
        return endedAt == nil
    }

    var title: String {
        "Bici #\(bikeId)"
    }

    var durationText: String {
        let start = startedAt ?? Date()
        let end = endedAt ?? Date()
        return CyclixFormatters.duration(end.timeIntervalSince(start))
    }

    var totalText: String {
        guard let totalAmount else { return "Pendiente" }
        return "GTQ \(totalAmount.formatted(.number.precision(.fractionLength(2))))"
    }
}

struct CyclixStation: Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let availableSlots: Int?
    let totalSlots: Int?

    init?(dictionary: [String: Any]) {
        guard
            let id = CyclixParsers.string(dictionary["id"]),
            let name = CyclixParsers.string(dictionary["name"] ?? dictionary["nombre"]),
            let latitude = CyclixParsers.double(dictionary["latitud"] ?? dictionary["latitude"]),
            let longitude = CyclixParsers.double(dictionary["longitud"] ?? dictionary["longitude"])
        else {
            return nil
        }

        self.id = id
        self.name = name
        address = CyclixParsers.string(dictionary["direccion"] ?? dictionary["address"]) ?? "Sin dirección"
        self.latitude = latitude
        self.longitude = longitude
        availableSlots = CyclixParsers.int(dictionary["capacidadDisponible"] ?? dictionary["availableCapacity"])
        totalSlots = CyclixParsers.int(dictionary["capacidadTotal"] ?? dictionary["totalCapacity"])
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(from coordinate: CLLocationCoordinate2D?) -> CLLocationDistance? {
        guard let coordinate else { return nil }
        let station = CLLocation(latitude: latitude, longitude: longitude)
        let user = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return station.distance(from: user)
    }

    func distanceText(from coordinate: CLLocationCoordinate2D?) -> String {
        guard let distance = distance(from: coordinate) else { return "Sin ubicación" }
        if distance < 1000 {
            return "\(Int(distance.rounded())) m"
        }
        return "\(String(format: "%.1f", distance / 1000)) km"
    }
}

struct CyclixIssuePreset: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String

    static let quickIssues: [CyclixIssuePreset] = [
        CyclixIssuePreset(
            id: "lock",
            title: "Bloqueo no responde",
            description: "La bicicleta no respondió al intento de desbloqueo o bloqueo desde el reloj."
        ),
        CyclixIssuePreset(
            id: "brake",
            title: "Problema mecánico",
            description: "La bicicleta presenta un problema mecánico y necesito asistencia."
        ),
        CyclixIssuePreset(
            id: "zone",
            title: "Zona inválida",
            description: "La app indicó que estoy fuera de una zona permitida y necesito soporte."
        ),
    ]
}

struct BLEBikeConfiguration {
    let serviceUUID: String
    let commandCharacteristicUUID: String
    let peripheralNamePrefix: String
    let unlockCommand: Data
    let lockCommand: Data

    static let `default` = BLEBikeConfiguration(
        serviceUUID: "FFF0",
        commandCharacteristicUUID: "FFF1",
        peripheralNamePrefix: "CYCLIX",
        unlockCommand: Data("UNLOCK".utf8),
        lockCommand: Data("LOCK".utf8)
    )

    var isPlaceholderConfiguration: Bool {
        serviceUUID == "FFF0" && commandCharacteristicUUID == "FFF1"
    }
}

enum CyclixParsers {
    static func string(_ value: Any?) -> String? {
        guard let value else { return nil }
        let string = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
        return string.isEmpty ? nil : string
    }

    static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        return Int(string(value) ?? "")
    }

    static func double(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        return Double(string(value) ?? "")
    }

    static func date(_ value: Any?) -> Date? {
        guard let string = string(value) else { return nil }
        return CyclixFormatters.iso8601Fractional.date(from: string)
            ?? CyclixFormatters.iso8601.date(from: string)
    }
}

enum CyclixFormatters {
    static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func duration(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = max(Int(timeInterval), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
