import CoreLocation
import Foundation

struct CyclixUserProfile: Equatable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let fullName: String
    let phone: String
    let role: String

    init(
        id: String = "",
        email: String = "",
        firstName: String = "",
        lastName: String = "",
        fullName: String = "",
        phone: String = "",
        role: String = ""
    ) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.fullName = fullName
        self.phone = phone
        self.role = role
    }

    init(json: CyclixJSONObject) {
        let fullName = cyclixString(json["fullName"]) ?? ""
        let parts = fullName.split(separator: " ").map(String.init)
        self.id = cyclixString(json["id"]) ?? ""
        self.email = cyclixString(json["email"]) ?? ""
        self.firstName = cyclixString(json["firstName"]) ?? parts.first ?? ""
        self.lastName = cyclixString(json["lastName"]) ?? parts.dropFirst().joined(separator: " ")
        self.fullName = fullName.isEmpty ? [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ") : fullName
        self.phone = cyclixString(json["phone"]) ?? ""
        self.role = cyclixString(json["role"]) ?? ""
    }

    var displayName: String {
        if !fullName.isEmpty { return fullName }
        let composed = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        return composed.isEmpty ? email : composed
    }

    var storageDictionary: CyclixJSONObject {
        [
            "id": id,
            "email": email,
            "firstName": firstName,
            "lastName": lastName,
            "fullName": fullName,
            "phone": phone,
            "role": role
        ]
    }
}

struct CyclixWalletSummary: Equatable {
    let balance: Double
    let currency: String

    init(json: CyclixJSONObject) {
        balance = cyclixDouble(json["balance"]) ?? 0
        currency = cyclixString(json["currency"]) ?? "GTQ"
    }

    var formattedBalance: String {
        cyclixMoney(balance, currencyCode: currency)
    }
}

struct CyclixWalletTransaction: Identifiable, Equatable {
    let id: String
    let type: String
    let description: String
    let amount: Double
    let createdAt: Date?

    init(json: CyclixJSONObject) {
        id = cyclixString(json["id"]) ?? UUID().uuidString
        type = cyclixString(json["type"]) ?? "MOVEMENT"
        description = cyclixString(json["description"]) ?? type
        amount = cyclixDouble(json["amount"]) ?? 0
        createdAt = cyclixDate(json["createdAt"])
    }
}

struct CyclixTripSummary: Identifiable, Equatable {
    let id: String
    let bikeId: String
    let status: String
    let startedAt: Date?
    let endedAt: Date?
    let durationSeconds: Int
    let distanceKm: Double
    let totalAmount: Double?
    let walletChargedAmount: Double?
    let pricingRuleName: String?

    init(json: CyclixJSONObject) {
        id = cyclixString(json["id"]) ?? UUID().uuidString
        bikeId = cyclixString(json["bikeId"]) ?? cyclixString(json["bike_id"]) ?? "-"
        status = (cyclixString(json["status"]) ?? "ACTIVE").uppercased()
        startedAt = cyclixDate(json["startedAt"])
        endedAt = cyclixDate(json["endedAt"]) ?? cyclixDate(json["endTime"]) ?? cyclixDate(json["finishedAt"])
        durationSeconds = cyclixInt(json["durationSeconds"]) ?? 0
        distanceKm = cyclixDouble(json["distanceKm"]) ?? 0
        totalAmount = cyclixDouble(json["totalAmount"])
        walletChargedAmount = cyclixDouble(json["walletChargedAmount"])
        pricingRuleName = cyclixString(json["pricingRuleName"])
    }

    var isActive: Bool {
        ["ACTIVE", "IN_PROGRESS", "STARTED"].contains(status) || endedAt == nil
    }

    var totalToDisplay: Double {
        walletChargedAmount ?? totalAmount ?? 0
    }

    var startedAtText: String {
        guard let startedAt else { return "Sin fecha" }
        return CyclixFormatters.dateTime.string(from: startedAt)
    }

    var elapsedText: String {
        let duration: TimeInterval
        if durationSeconds > 0 {
            duration = TimeInterval(durationSeconds)
        } else if let startedAt {
            duration = Date().timeIntervalSince(startedAt)
        } else {
            duration = 0
        }
        return cyclixDuration(duration)
    }
}

struct CyclixStationSummary: Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
    let availableCapacity: Int
    let totalCapacity: Int
    let latitude: Double?
    let longitude: Double?
    let distanceMeters: Double?

    init(json: CyclixJSONObject, distanceMeters: Double? = nil) {
        id = cyclixString(json["id"]) ?? UUID().uuidString
        name = cyclixString(json["nombre"]) ?? cyclixString(json["name"]) ?? "Puesto"
        address = cyclixString(json["direccion"]) ?? cyclixString(json["address"]) ?? ""
        availableCapacity = cyclixInt(json["capacidadDisponible"]) ?? cyclixInt(json["availableCapacity"]) ?? 0
        totalCapacity = cyclixInt(json["capacidadTotal"]) ?? cyclixInt(json["totalCapacity"]) ?? 0
        latitude = cyclixDouble(json["latitud"]) ?? cyclixDouble(json["latitude"])
        longitude = cyclixDouble(json["longitud"]) ?? cyclixDouble(json["longitude"])
        self.distanceMeters = distanceMeters
    }

    func with(distanceMeters: Double?) -> CyclixStationSummary {
        CyclixStationSummary(
            json: [
                "id": id,
                "nombre": name,
                "direccion": address,
                "capacidadDisponible": availableCapacity,
                "capacidadTotal": totalCapacity,
                "latitud": latitude as Any,
                "longitud": longitude as Any
            ],
            distanceMeters: distanceMeters
        )
    }
}

struct CyclixBikeSummary: Identifiable, Equatable {
    let id: String
    let code: String
    let brand: String
    let model: String
    let color: String
    let type: String
    let status: String
    let stationName: String
    let hourlyPrice: Double

    init(json: CyclixJSONObject) {
        let station = cyclixMap(json["puesto"])
        id = cyclixString(json["id"]) ?? cyclixString(json["codigo"]) ?? "0"
        code = cyclixString(json["codigo"]) ?? ""
        brand = cyclixString(json["marca"]) ?? ""
        model = cyclixString(json["modelo"]) ?? ""
        color = cyclixString(json["color"]) ?? ""
        type = cyclixString(json["tipo"]) ?? ""
        status = cyclixString(json["estado"]) ?? ""
        stationName = cyclixString(station?["nombre"]) ?? ""
        hourlyPrice = cyclixDouble(json["precioPorHora"]) ?? 60
    }

    var displayName: String {
        let label = [brand, model].filter { !$0.isEmpty }.joined(separator: " ")
        return label.isEmpty ? "Bicicleta #\(id)" : label
    }

    var tariffDescription: String {
        let perMinute = hourlyPrice / 60
        return "Q\(String(format: "%.2f", hourlyPrice))/h · Q\(String(format: "%.2f", perMinute))/min"
    }
}

struct CyclixSupportTicket: Identifiable, Equatable {
    let id: String
    let title: String
    let category: String
    let priority: String
    let status: String

    init(json: CyclixJSONObject) {
        id = cyclixString(json["id"]) ?? UUID().uuidString
        title = cyclixString(json["title"]) ?? "Ticket"
        category = cyclixString(json["category"]) ?? "OTHER"
        priority = cyclixString(json["priority"]) ?? "MEDIUM"
        status = cyclixString(json["status"]) ?? "OPEN"
    }
}

struct CyclixPricingRule: Equatable {
    let name: String
    let baseFare: Double
    let includedMinutes: Int
    let extraFarePerBlock: Double
    let extraBlockMinutes: Int
    let active: Bool
    let priority: Int
    let startDate: Date?
    let endDate: Date?
    let startTime: String
    let endTime: String
    let daysOfWeek: [Int]

    init(json: CyclixJSONObject) {
        name = cyclixString(json["name"]) ?? "Tarifa vigente"
        baseFare = cyclixDouble(json["baseFare"]) ?? 0
        includedMinutes = cyclixInt(json["includedMinutes"]) ?? 0
        extraFarePerBlock = cyclixDouble(json["extraFarePerBlock"]) ?? 0
        extraBlockMinutes = cyclixInt(json["extraBlockMinutes"]) ?? 0
        active = cyclixBool(json["active"]) ?? true
        priority = cyclixInt(json["priority"]) ?? 0
        startDate = cyclixDate(json["startDate"])
        endDate = cyclixDate(json["endDate"])
        startTime = cyclixString(json["startTime"]) ?? ""
        endTime = cyclixString(json["endTime"]) ?? ""
        daysOfWeek = CyclixPricingRule.decodeDays(json["daysOfWeek"])
    }

    var previewText: String {
        "\(cyclixMoney(baseFare)) incluye \(includedMinutes) min · Extra \(cyclixMoney(extraFarePerBlock)) / \(extraBlockMinutes) min"
    }

    func matches(now: Date = Date()) -> Bool {
        guard active else { return false }

        if let startDate, now < Calendar.current.startOfDay(for: startDate) {
            return false
        }

        if let endDate {
            let dayAfterEnd = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? endDate
            if now >= dayAfterEnd {
                return false
            }
        }

        if !daysOfWeek.isEmpty {
            let weekday = Calendar.current.component(.weekday, from: now)
            if !daysOfWeek.contains(weekday) {
                return false
            }
        }

        if !startTime.isEmpty || !endTime.isEmpty {
            let currentMinutes = Self.minutesSinceMidnight(for: now)
            if let startMinutes = Self.minutes(from: startTime),
               let endMinutes = Self.minutes(from: endTime) {
                if startMinutes <= endMinutes {
                    guard currentMinutes >= startMinutes && currentMinutes <= endMinutes else {
                        return false
                    }
                } else {
                    guard currentMinutes >= startMinutes || currentMinutes <= endMinutes else {
                        return false
                    }
                }
            }
        }

        return true
    }

    private static func decodeDays(_ value: Any?) -> [Int] {
        guard let raw = value else { return [] }
        if let days = raw as? [Int] { return days }
        if let days = raw as? [String] {
            return days.compactMap {
                if let number = Int($0) { return number }
                return weekdayMap[$0.uppercased()]
            }
        }
        if let text = cyclixString(raw) {
            return text
                .split(separator: ",")
                .compactMap { item in
                    let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let number = Int(trimmed) { return number }
                    return weekdayMap[trimmed.uppercased()]
                }
        }
        return []
    }

    private static func minutes(from value: String) -> Int? {
        let parts = value.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1])
        else {
            return nil
        }
        return hour * 60 + minute
    }

    private static func minutesSinceMidnight(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private static let weekdayMap: [String: Int] = [
        "SUNDAY": 1,
        "DOMINGO": 1,
        "MONDAY": 2,
        "LUNES": 2,
        "TUESDAY": 3,
        "MARTES": 3,
        "WEDNESDAY": 4,
        "MIERCOLES": 4,
        "MIÉRCOLES": 4,
        "THURSDAY": 5,
        "JUEVES": 5,
        "FRIDAY": 6,
        "VIERNES": 6,
        "SATURDAY": 7,
        "SABADO": 7,
        "SÁBADO": 7
    ]
}

struct CyclixDashboardSummary: Equatable {
    let wallet: CyclixWalletSummary?
    let activeTrip: CyclixTripSummary?
    let activeBike: CyclixBikeSummary?
    let nearestStation: CyclixStationSummary?
}
