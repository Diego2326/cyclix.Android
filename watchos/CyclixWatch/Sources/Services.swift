import CoreBluetooth
import CoreLocation
import Foundation

enum CyclixAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case missingToken
    case invalidPayload(String)
    case server(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "No se pudo construir la URL del API."
        case .invalidResponse:
            return "La respuesta del servidor no fue válida."
        case .missingToken:
            return "Tu sesión expiró. Inicia sesión otra vez."
        case let .invalidPayload(message):
            return message
        case let .server(message):
            return message
        }
    }
}

struct CyclixAPI {
    static let baseURL = "https://api.cyclix.site/api/v1"
    private static let tokenKey = "cyclix_watch_token"
    private static let emailKey = "cyclix_watch_email"

    let session: URLSession = .shared
    let defaults: UserDefaults = .standard

    func loadToken() -> String? {
        defaults.string(forKey: Self.tokenKey)
    }

    func loadEmail() -> String {
        defaults.string(forKey: Self.emailKey) ?? ""
    }

    func saveSession(token: String, email: String) {
        defaults.set(token, forKey: Self.tokenKey)
        defaults.set(email, forKey: Self.emailKey)
    }

    func clearSession() {
        defaults.removeObject(forKey: Self.tokenKey)
        defaults.removeObject(forKey: Self.emailKey)
    }

    func login(email: String, password: String) async throws -> String {
        let payload = try await requestJSON(
            path: "/auth/login",
            method: "POST",
            token: nil,
            body: ["email": email, "password": password]
        )

        guard
            let dictionary = payload as? [String: Any],
            let token = CyclixParsers.string(dictionary["token"])
        else {
            throw CyclixAPIError.invalidPayload("El login no devolvió un token válido.")
        }

        saveSession(token: token, email: email)
        return token
    }

    func fetchProfile(token: String) async throws -> CyclixUser {
        let payload = try await requestJSON(path: "/profile/me", token: token)
        guard let dictionary = payload as? [String: Any] else {
            throw CyclixAPIError.invalidPayload("No se pudo leer el perfil del usuario.")
        }
        return CyclixUser(dictionary: dictionary)
    }

    func fetchUsers(token: String) async throws -> [[String: Any]] {
        let payload = try await requestJSON(path: "/get/user", token: token)
        return payload as? [[String: Any]] ?? []
    }

    func fetchWallet(token: String) async throws -> CyclixWallet {
        let payload = try await requestJSON(path: "/wallet/my", token: token)
        guard let dictionary = payload as? [String: Any] else {
            throw CyclixAPIError.invalidPayload("No se pudo leer el wallet.")
        }
        return CyclixWallet(dictionary: dictionary)
    }

    func fetchWalletTransactions(token: String) async throws -> [CyclixWalletTransaction] {
        let payload = try await requestJSON(path: "/wallet/my/transactions", token: token)
        guard let array = payload as? [[String: Any]] else { return [] }
        return array.map(CyclixWalletTransaction.init(dictionary:))
    }

    func fetchTrips(token: String) async throws -> [CyclixTrip] {
        let payload = try await requestJSON(path: "/trips/my", token: token)
        guard let array = payload as? [[String: Any]] else { return [] }
        return array.map(CyclixTrip.init(dictionary:))
    }

    func fetchStations(token: String?) async throws -> [CyclixStation] {
        let payload = try await requestJSON(path: "/puestos/activos", token: token)
        guard let array = payload as? [[String: Any]] else { return [] }
        return array.compactMap(CyclixStation.init(dictionary:))
    }

    func validateZone(token: String, coordinate: CLLocationCoordinate2D, start: Bool) async throws {
        let payload = try await requestJSON(
            path: "/zones/validate",
            method: "POST",
            token: token,
            body: [
                "latitude": coordinate.latitude,
                "longitude": coordinate.longitude,
            ]
        )

        if
            let dictionary = payload as? [String: Any],
            let allowed = dictionary["allowed"] as? Bool,
            allowed == false
        {
            let fallback = start
                ? "No puedes iniciar el viaje fuera de una zona habilitada."
                : "Debes finalizar dentro de una zona habilitada."
            throw CyclixAPIError.server(
                message: CyclixParsers.string(dictionary["message"]) ?? fallback
            )
        }
    }

    func createTrip(token: String, bikeId: String, coordinate: CLLocationCoordinate2D) async throws -> CyclixTrip {
        let payload = try await requestJSON(
            path: "/trips",
            method: "POST",
            token: token,
            body: [
                "bikeId": Int(bikeId) ?? bikeId,
                "startLatitude": coordinate.latitude,
                "startLongitude": coordinate.longitude,
            ]
        )

        guard let dictionary = payload as? [String: Any] else {
            throw CyclixAPIError.invalidPayload("No se pudo registrar el viaje.")
        }

        return CyclixTrip(dictionary: dictionary)
    }

    func finishTrip(token: String, tripId: String, coordinate: CLLocationCoordinate2D) async throws {
        _ = try await requestJSON(
            path: "/trips/\(tripId)/finish",
            method: "PUT",
            token: token,
            body: [
                "endLatitude": coordinate.latitude,
                "endLongitude": coordinate.longitude,
            ]
        )
    }

    func createEmergencyTicket(
        token: String,
        title: String,
        description: String,
        bikeId: String?,
        tripId: String?
    ) async throws {
        let normalizedBikeId = bikeId.flatMap { value -> Any? in
            Int(value) ?? value
        }
        let normalizedTripId = tripId.flatMap { value -> Any? in
            Int(value) ?? value
        }

        _ = try await requestJSON(
            path: "/support/tickets",
            method: "POST",
            token: token,
            body: [
                "category": "EMERGENCY",
                "priority": "CRITICAL",
                "title": title,
                "description": description,
                "bikeId": normalizedBikeId as Any,
                "tripId": normalizedTripId as Any,
            ].compactMapValues { value in
                if value is NSNull { return nil }
                return value
            }
        )
    }

    private func requestJSON(
        path: String,
        method: String = "GET",
        token: String? = nil,
        body: [String: Any]? = nil
    ) async throws -> Any {
        guard let url = URL(string: Self.baseURL + path) else {
            throw CyclixAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CyclixAPIError.invalidResponse
        }

        let json = data.isEmpty ? nil : try JSONSerialization.jsonObject(with: data)

        if (200 ..< 300).contains(http.statusCode) {
            if let dictionary = json as? [String: Any], dictionary.keys.contains("success") {
                if (dictionary["success"] as? Bool) == true {
                    return dictionary["data"] ?? [:]
                }
                throw CyclixAPIError.server(
                    message: CyclixParsers.string(dictionary["message"]) ?? "La API rechazó la solicitud."
                )
            }
            return json ?? [:]
        }

        if let dictionary = json as? [String: Any] {
            let message = CyclixParsers.string(dictionary["message"])
                ?? CyclixParsers.string(dictionary["error"])
                ?? CyclixParsers.string(dictionary["detail"])
                ?? "Error \(http.statusCode) al comunicarse con Cyclix."
            throw CyclixAPIError.server(message: message)
        }

        throw CyclixAPIError.server(message: "Error \(http.statusCode) al comunicarse con Cyclix.")
    }
}

final class WatchLocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestCurrentLocation() async -> CLLocationCoordinate2D? {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        if status == .denied || status == .restricted {
            return nil
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            continuation?.resume(returning: nil)
            continuation = nil
        } else if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.last?.coordinate)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: manager.location?.coordinate)
        continuation = nil
    }
}

final class BLEBikeUnlockService: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager!
    private var config = BLEBikeConfiguration.default
    private var operationContinuation: CheckedContinuation<Void, Error>?
    private var timeoutTask: Task<Void, Never>?
    private var pendingBikeId = ""
    private var pendingCommand = Data()
    private var commandCharacteristic: CBCharacteristic?
    private var activePeripheral: CBPeripheral?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func unlockBike(id bikeId: String, configuration: BLEBikeConfiguration) async throws {
        try await sendCommand(
            bikeId: bikeId,
            command: configuration.unlockCommand,
            configuration: configuration
        )
    }

    func lockBike(id bikeId: String, configuration: BLEBikeConfiguration) async throws {
        try await sendCommand(
            bikeId: bikeId,
            command: configuration.lockCommand,
            configuration: configuration
        )
    }

    private func sendCommand(
        bikeId: String,
        command: Data,
        configuration: BLEBikeConfiguration
    ) async throws {
        guard operationContinuation == nil else {
            throw CyclixAPIError.server(message: "Ya hay una operación BLE en curso.")
        }

        guard central.state == .poweredOn else {
            throw CyclixAPIError.server(
                message: "Bluetooth no está disponible. Activa Bluetooth en el reloj."
            )
        }

        config = configuration
        pendingBikeId = bikeId.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingCommand = command
        commandCharacteristic = nil
        activePeripheral = nil

        try await withCheckedThrowingContinuation { continuation in
            operationContinuation = continuation
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                self?.finish(with: CyclixAPIError.server(message: "Tiempo agotado buscando la bicicleta por BLE."))
            }
            central.scanForPeripherals(
                withServices: [CBUUID(string: configuration.serviceUUID)],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        }
    }

    private func finish(with error: Error?) {
        central.stopScan()
        timeoutTask?.cancel()
        timeoutTask = nil

        if let peripheral = activePeripheral {
            central.cancelPeripheralConnection(peripheral)
        }

        let continuation = operationContinuation
        operationContinuation = nil
        commandCharacteristic = nil
        activePeripheral = nil

        if let error {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume()
        }
    }

    private func matchingPeripheralName(_ peripheral: CBPeripheral) -> Bool {
        let name = (peripheral.name ?? "").uppercased()
        if !pendingBikeId.isEmpty, name.contains(pendingBikeId.uppercased()) {
            return true
        }
        return name.hasPrefix(config.peripheralNamePrefix.uppercased())
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn, operationContinuation != nil {
            finish(with: CyclixAPIError.server(message: "Bluetooth no está disponible en este momento."))
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard matchingPeripheralName(peripheral) else { return }
        activePeripheral = peripheral
        peripheral.delegate = self
        central.stopScan()
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([CBUUID(string: config.serviceUUID)])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        finish(with: error ?? CyclixAPIError.server(message: "No se pudo conectar con la bicicleta."))
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            finish(with: error)
            return
        }

        guard let service = peripheral.services?.first(where: {
            $0.uuid == CBUUID(string: config.serviceUUID)
        }) else {
            finish(with: CyclixAPIError.server(message: "La bicicleta no expone el servicio BLE esperado."))
            return
        }

        peripheral.discoverCharacteristics([CBUUID(string: config.commandCharacteristicUUID)], for: service)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            finish(with: error)
            return
        }

        guard let characteristic = service.characteristics?.first(where: {
            $0.uuid == CBUUID(string: config.commandCharacteristicUUID)
        }) else {
            finish(with: CyclixAPIError.server(message: "No se encontró la característica BLE de comando."))
            return
        }

        commandCharacteristic = characteristic
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.write)
            ? .withResponse
            : .withoutResponse

        peripheral.writeValue(pendingCommand, for: characteristic, type: writeType)
        if writeType == .withoutResponse {
            finish(with: nil)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            finish(with: error)
        } else {
            finish(with: nil)
        }
    }
}

@MainActor
final class CyclixWatchStore: ObservableObject {
    @Published var isBootstrapping = true
    @Published var isRefreshing = false
    @Published var isAuthenticating = false
    @Published var isUnlocking = false
    @Published var isFinishingTrip = false
    @Published var isSendingSupport = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var token: String?
    @Published var savedEmail = ""
    @Published var user: CyclixUser?
    @Published var wallet: CyclixWallet?
    @Published var walletTransactions: [CyclixWalletTransaction] = []
    @Published var trips: [CyclixTrip] = []
    @Published var stations: [CyclixStation] = []
    @Published var activeTrip: CyclixTrip?
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var bleStatusText = "Listo para desbloquear"

    let bleConfiguration = BLEBikeConfiguration.default

    private let api = CyclixAPI()
    private let locationManager = WatchLocationManager()
    private let bleService = BLEBikeUnlockService()

    var isLoggedIn: Bool {
        token?.isEmpty == false
    }

    var sortedStations: [CyclixStation] {
        stations.sorted { lhs, rhs in
            (lhs.distance(from: currentLocation) ?? .greatestFiniteMagnitude) <
                (rhs.distance(from: currentLocation) ?? .greatestFiniteMagnitude)
        }
    }

    private func capture<T>(_ operation: @escaping () async throws -> T) async -> Result<T, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }

    func bootstrap() async {
        savedEmail = api.loadEmail()
        token = api.loadToken()
        defer { isBootstrapping = false }

        guard token != nil else { return }
        await refresh()
    }

    func login(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Correo y contraseña son obligatorios."
            return
        }

        isAuthenticating = true
        clearMessages()
        do {
            let token = try await api.login(email: email, password: password)
            self.token = token
            savedEmail = email
            successMessage = "Sesión iniciada."
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
        isAuthenticating = false
    }

    func logout() {
        api.clearSession()
        token = nil
        user = nil
        wallet = nil
        walletTransactions = []
        trips = []
        stations = []
        activeTrip = nil
        currentLocation = nil
        savedEmail = ""
        clearMessages()
    }

    func refresh() async {
        guard let token else { return }
        isRefreshing = true
        clearMessages()

        async let profileResult = capture { [self] in
            try await self.api.fetchProfile(token: token)
        }
        async let usersResult = capture { [self] in
            try await self.api.fetchUsers(token: token)
        }
        async let walletResult = capture { [self] in
            try await self.api.fetchWallet(token: token)
        }
        async let transactionsResult = capture { [self] in
            try await self.api.fetchWalletTransactions(token: token)
        }
        async let tripsResult = capture { [self] in
            try await self.api.fetchTrips(token: token)
        }
        async let stationsResult = capture { [self] in
            try await self.api.fetchStations(token: token)
        }
        async let locationResult = capture { [self] in
            await self.locationManager.requestCurrentLocation()
        }

        let (
            loadedProfileResult,
            loadedUsersResult,
            loadedWalletResult,
            loadedTransactionsResult,
            loadedTripsResult,
            loadedStationsResult,
            loadedLocationResult
        ) = await (
            profileResult,
            usersResult,
            walletResult,
            transactionsResult,
            tripsResult,
            stationsResult,
            locationResult
        )

        var partialFailures: [String] = []

        switch loadedProfileResult {
        case let .success(profile):
            let mergedProfile = mergeProfile(profileResult: profile, usersResult: loadedUsersResult)
            user = mergedProfile
        case let .failure(error):
            partialFailures.append("perfil")
            if user == nil {
                errorMessage = error.localizedDescription
            }
        }

        switch loadedWalletResult {
        case let .success(wallet):
            self.wallet = wallet
        case .failure:
            partialFailures.append("wallet")
        }

        switch loadedTransactionsResult {
        case let .success(transactions):
            self.walletTransactions = transactions
        case .failure:
            partialFailures.append("movimientos")
        }

        switch loadedTripsResult {
        case let .success(loadedTrips):
            self.trips = loadedTrips.sorted {
                ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast)
            }
            self.activeTrip = self.trips.first(where: \.isActive)
        case .failure:
            partialFailures.append("viajes")
        }

        switch loadedStationsResult {
        case let .success(loadedStations):
            self.stations = loadedStations
        case .failure:
            partialFailures.append("estaciones")
        }

        switch loadedLocationResult {
        case let .success(coordinate):
            currentLocation = coordinate
        case .failure:
            partialFailures.append("ubicación")
        }

        if !partialFailures.isEmpty, errorMessage == nil {
            errorMessage = "Se cargó la app parcialmente. Faltó: \(partialFailures.joined(separator: ", "))."
        }

        isRefreshing = false
    }

    func unlockBikeAndStartTrip(bikeId: String) async {
        guard let token else {
            errorMessage = CyclixAPIError.missingToken.localizedDescription
            return
        }
        guard activeTrip == nil else {
            errorMessage = "Ya tienes un viaje activo."
            return
        }

        let trimmedBikeId = bikeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBikeId.isEmpty else {
            errorMessage = "Escribe el ID de la bicicleta."
            return
        }

        isUnlocking = true
        clearMessages()

        do {
            bleStatusText = "Obteniendo ubicación..."
            guard let coordinate = await locationManager.requestCurrentLocation() else {
                throw CyclixAPIError.server(message: "Permite la ubicación en el reloj para iniciar el viaje.")
            }
            currentLocation = coordinate

            bleStatusText = "Validando zona..."
            try await api.validateZone(token: token, coordinate: coordinate, start: true)

            bleStatusText = "Buscando bicicleta..."
            try await bleService.unlockBike(id: trimmedBikeId, configuration: bleConfiguration)

            bleStatusText = "Registrando viaje..."
            let trip = try await api.createTrip(
                token: token,
                bikeId: trimmedBikeId,
                coordinate: coordinate
            )

            activeTrip = trip
            trips.insert(trip, at: 0)
            successMessage = "Bicicleta desbloqueada."
            bleStatusText = "Desbloqueo completado"
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
            bleStatusText = "No se pudo desbloquear"
        }

        isUnlocking = false
    }

    func finishActiveTrip(requireBLELock: Bool) async {
        guard let token, let activeTrip else {
            errorMessage = "No hay un viaje activo."
            return
        }

        isFinishingTrip = true
        clearMessages()

        do {
            guard let coordinate = await locationManager.requestCurrentLocation() else {
                throw CyclixAPIError.server(message: "Permite la ubicación en el reloj para finalizar el viaje.")
            }
            currentLocation = coordinate

            try await api.validateZone(token: token, coordinate: coordinate, start: false)

            if requireBLELock {
                bleStatusText = "Bloqueando bicicleta..."
                try await bleService.lockBike(id: activeTrip.bikeId, configuration: bleConfiguration)
            }

            bleStatusText = "Cerrando viaje..."
            try await api.finishTrip(token: token, tripId: activeTrip.id, coordinate: coordinate)
            successMessage = requireBLELock
                ? "Viaje finalizado y bicicleta bloqueada."
                : "Viaje finalizado."
            bleStatusText = "Viaje cerrado"
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
            bleStatusText = "No se pudo finalizar"
        }

        isFinishingTrip = false
    }

    func sendEmergencyTicket(issue: CyclixIssuePreset, note: String) async {
        guard let token else {
            errorMessage = CyclixAPIError.missingToken.localizedDescription
            return
        }

        isSendingSupport = true
        clearMessages()

        let description = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? issue.description
            : "\(issue.description)\n\nDetalle: \(note.trimmingCharacters(in: .whitespacesAndNewlines))"

        do {
            try await api.createEmergencyTicket(
                token: token,
                title: issue.title,
                description: description,
                bikeId: activeTrip?.bikeId,
                tripId: activeTrip?.id
            )
            successMessage = "Aviso enviado a soporte."
        } catch {
            errorMessage = error.localizedDescription
        }

        isSendingSupport = false
    }

    private func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    private func mergeProfile(
        profileResult: CyclixUser,
        usersResult: Result<[[String: Any]], Error>
    ) -> CyclixUser {
        guard case let .success(users) = usersResult else { return profileResult }

        let normalizedEmail = profileResult.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matchedUser = users.first { user in
            let email = CyclixParsers.string(user["email"])?.lowercased()
            let id = CyclixParsers.string(user["id"])
            return email == normalizedEmail || id == profileResult.id
        }

        guard let matchedUser else { return profileResult }

        let mergedDictionary: [String: Any] = [
            "id": matchedUser["id"] ?? profileResult.id,
            "fullName": matchedUser["fullName"] ?? profileResult.fullName,
            "firstName": matchedUser["firstName"] ?? "",
            "lastName": matchedUser["lastName"] ?? "",
            "email": matchedUser["email"] ?? profileResult.email,
            "phone": matchedUser["phone"] ?? profileResult.phone,
            "role": matchedUser["role"] ?? profileResult.role,
        ]

        return CyclixUser(dictionary: mergedDictionary)
    }
}
