import Foundation

struct CyclixWatchAPI {
    static let baseURL = URL(string: "https://api.cyclix.site/api/v1")!

    let sessionStore: CyclixWatchSessionStore

    func login(email: String, password: String) async throws -> CyclixUserProfile {
        let payload = try await request(
            path: "/auth/login",
            method: "POST",
            body: ["email": email, "password": password],
            authorized: false
        )

        guard let json = cyclixMap(payload),
              let token = cyclixString(json["token"])
        else {
            throw CyclixWatchError.message("Respuesta de login invalida.")
        }

        let profile = try await resolveProfile(email: email, token: token)
        sessionStore.save(token: token, email: email, profile: profile)
        return profile
    }

    func fetchProfile() async throws -> CyclixUserProfile {
        let json = try await request(path: "/profile/me")
        guard let map = cyclixMap(json) else {
            throw CyclixWatchError.invalidResponse
        }
        let baseProfile = CyclixUserProfile(json: map)

        if let email = cyclixString(map["email"]) ?? sessionStore.email {
            let merged = try await mergeUserDetails(for: email, token: try requireToken(), profile: baseProfile)
            sessionStore.save(profile: merged)
            return merged
        }

        sessionStore.save(profile: baseProfile)
        return baseProfile
    }

    func getWallet() async throws -> CyclixWalletSummary {
        guard let json = cyclixMap(try await request(path: "/wallet/my")) else {
            throw CyclixWatchError.invalidResponse
        }
        return CyclixWalletSummary(json: json)
    }

    func getWalletTransactions() async throws -> [CyclixWalletTransaction] {
        let items = cyclixMapArray(try await request(path: "/wallet/my/transactions"))
        return items.map(CyclixWalletTransaction.init)
    }

    @discardableResult
    func topUpWallet(amount: Double, paymentMethod: String) async throws -> CyclixWalletSummary {
        _ = try await request(
            path: "/wallet/my/top-up",
            method: "POST",
            body: ["amount": amount, "paymentMethod": paymentMethod]
        )
        return try await getWallet()
    }

    func getMyTrips() async throws -> [CyclixTripSummary] {
        let trips = cyclixMapArray(try await request(path: "/trips/my"))
        return trips.map(CyclixTripSummary.init)
    }

    func getStations() async throws -> [CyclixStationSummary] {
        let stations = cyclixMapArray(try await request(path: "/puestos/activos"))
        return stations.map { CyclixStationSummary(json: $0) }
    }

    func getBikesByStation(_ stationID: String) async throws -> [CyclixBikeSummary] {
        let bikes = cyclixMapArray(try await request(path: "/bicicletas/puesto/\(stationID)/disponibles"))
        return bikes.map(CyclixBikeSummary.init)
    }

    func getBike(by identifier: String) async throws -> CyclixBikeSummary {
        let bikeID = cyclixBikeIdentifier(from: identifier)
        let path = bikeID.hasPrefix("CYCLIX-BICI-")
            ? "/bicicletas/qr/\(bikeID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bikeID)"
            : "/bicicletas/\(bikeID)"
        guard let json = cyclixMap(try await request(path: path)) else {
            throw CyclixWatchError.invalidResponse
        }
        return CyclixBikeSummary(json: json)
    }

    func createTrip(bikeID: String, latitude: Double, longitude: Double) async throws -> CyclixTripSummary {
        guard let json = cyclixMap(
            try await request(
                path: "/trips",
                method: "POST",
                body: [
                    "bikeId": Int(bikeID) ?? bikeID,
                    "startLatitude": latitude,
                    "startLongitude": longitude
                ]
            )
        ) else {
            throw CyclixWatchError.invalidResponse
        }
        return CyclixTripSummary(json: json)
    }

    func finishTrip(tripID: String, latitude: Double, longitude: Double) async throws -> CyclixTripSummary {
        guard let json = cyclixMap(
            try await request(
                path: "/trips/\(tripID)/finish",
                method: "PUT",
                body: [
                    "endLatitude": latitude,
                    "endLongitude": longitude
                ]
            )
        ) else {
            throw CyclixWatchError.invalidResponse
        }
        return CyclixTripSummary(json: json)
    }

    func validateZone(latitude: Double, longitude: Double, start: Bool) async throws {
        guard let json = cyclixMap(
            try await request(
                path: "/zones/validate",
                method: "POST",
                body: [
                    "latitude": latitude,
                    "longitude": longitude
                ]
            )
        ) else {
            throw CyclixWatchError.invalidResponse
        }

        if cyclixBool(json["allowed"]) == false {
            let fallback = start
                ? "No puedes iniciar fuera de una zona habilitada."
                : "Debes finalizar dentro de una zona habilitada."
            throw CyclixWatchError.message(cyclixString(json["message"]) ?? fallback)
        }
    }

    func getMyTickets() async throws -> [CyclixSupportTicket] {
        let tickets = cyclixMapArray(try await request(path: "/support/tickets/my"))
        return tickets.map(CyclixSupportTicket.init)
    }

    func createTicket(
        category: String,
        priority: String,
        title: String,
        description: String,
        bikeID: String?,
        tripID: String?
    ) async throws {
        var body: CyclixJSONObject = [
            "category": category,
            "priority": priority,
            "title": title,
            "description": description
        ]
        if let bikeID, !bikeID.isEmpty { body["bikeId"] = Int(bikeID) ?? bikeID }
        if let tripID, !tripID.isEmpty { body["tripId"] = Int(tripID) ?? tripID }

        _ = try await request(path: "/support/tickets", method: "POST", body: body)
    }

    func createFailureReport(
        bikeID: String,
        tripID: String?,
        priority: String,
        title: String,
        description: String
    ) async throws {
        var body: CyclixJSONObject = [
            "bikeId": Int(bikeID) ?? bikeID,
            "priority": priority,
            "title": title,
            "description": description
        ]
        if let tripID, !tripID.isEmpty { body["tripId"] = Int(tripID) ?? tripID }
        _ = try await request(path: "/support/failure-reports", method: "POST", body: body)
    }

    func getCurrentPricingRule() async throws -> CyclixPricingRule? {
        let rules = cyclixMapArray(try await request(path: "/admin/pricing/rules")).map(CyclixPricingRule.init)
        guard !rules.isEmpty else { return nil }

        let now = Date()
        let matches = rules.filter { $0.matches(now: now) }.sorted { $0.priority > $1.priority }
        return matches.first ?? rules.first
    }

    private func resolveProfile(email: String, token: String) async throws -> CyclixUserProfile {
        let baseProfile = try await fetchProfile(token: token)
        return try await mergeUserDetails(for: email, token: token, profile: baseProfile)
    }

    private func mergeUserDetails(for email: String, token: String, profile: CyclixUserProfile) async throws -> CyclixUserProfile {
        do {
            let payload = try await request(path: "/get/user", token: token)
            let users = cyclixMapArray(payload)
            if let user = users.first(where: { cyclixString($0["email"]) == email }) {
                return CyclixUserProfile(json: profile.storageDictionary.merging(user, uniquingKeysWith: { _, new in new }))
            }
        } catch {
            return profile
        }
        return profile
    }

    private func fetchProfile(token: String) async throws -> CyclixUserProfile {
        guard let json = cyclixMap(try await request(path: "/profile/me", token: token)) else {
            throw CyclixWatchError.invalidResponse
        }
        return CyclixUserProfile(json: json)
    }

    private func request(
        path: String,
        method: String = "GET",
        body: CyclixJSONObject? = nil,
        authorized: Bool = true
    ) async throws -> Any {
        let token = authorized ? try requireToken() : nil
        return try await request(path: path, method: method, body: body, token: token)
    }

    private func request(
        path: String,
        method: String = "GET",
        body: CyclixJSONObject? = nil,
        token: String?
    ) async throws -> Any {
        let url = Self.baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CyclixWatchError.invalidResponse
        }

        let decoded: Any?
        if data.isEmpty {
            decoded = nil
        } else {
            decoded = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        }

        if (200..<300).contains(httpResponse.statusCode) {
            if let json = cyclixMap(decoded), json.keys.contains("success") {
                if cyclixBool(json["success"]) == true {
                    return json["data"] as Any
                }
                throw CyclixWatchError.message(cyclixString(json["message"]) ?? "La API rechazo la solicitud.")
            }
            return decoded as Any
        }

        if let json = cyclixMap(decoded) {
            let message = cyclixString(json["message"])
                ?? cyclixString(json["error"])
                ?? cyclixString(json["detail"])
                ?? "Error \(httpResponse.statusCode)"
            throw CyclixWatchError.message(message)
        }

        throw CyclixWatchError.message("Error \(httpResponse.statusCode) al comunicarse con Cyclix.")
    }

    private func requireToken() throws -> String {
        guard let token = sessionStore.token, !token.isEmpty else {
            throw CyclixWatchError.missingToken
        }
        return token
    }
}
