import CoreLocation
import Foundation

@MainActor
final class CyclixWatchStore: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isBootstrapping = true
    @Published var isLoading = false
    @Published var profile = CyclixUserProfile()
    @Published var walletSummary: CyclixWalletSummary?
    @Published var walletTransactions: [CyclixWalletTransaction] = []
    @Published var trips: [CyclixTripSummary] = []
    @Published var stations: [CyclixStationSummary] = []
    @Published var stationBikes: [CyclixBikeSummary] = []
    @Published var selectedStationID: String?
    @Published var tickets: [CyclixSupportTicket] = []
    @Published var activeTrip: CyclixTripSummary?
    @Published var activeBike: CyclixBikeSummary?
    @Published var nearestStation: CyclixStationSummary?
    @Published var alert: CyclixWatchAlert?

    private let sessionStore = CyclixWatchSessionStore()
    private let locationProvider = CyclixWatchLocationProvider()
    private var bootstrapped = false

    private var api: CyclixWatchAPI {
        CyclixWatchAPI(sessionStore: sessionStore)
    }

    init() {
        hydrateFromSession()
    }

    func bootstrapIfNeeded() async {
        guard !bootstrapped else { return }
        bootstrapped = true
        isBootstrapping = false

        guard isAuthenticated else { return }
        await refreshDashboard()
    }

    func login(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            alert = CyclixWatchAlert(title: "Faltan datos", message: "Escribe correo y clave.")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            profile = try await api.login(email: email, password: password)
            isAuthenticated = true
            await refreshDashboard()
        } catch {
            present(error, title: "No se pudo iniciar sesion")
        }
    }

    func logout() {
        sessionStore.clear()
        isAuthenticated = false
        profile = CyclixUserProfile()
        walletSummary = nil
        walletTransactions = []
        trips = []
        stations = []
        stationBikes = []
        selectedStationID = nil
        tickets = []
        activeTrip = nil
        activeBike = nil
        nearestStation = nil
    }

    func refreshDashboard() async {
        guard isAuthenticated else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let walletTask = api.getWallet()
            async let tripsTask = api.getMyTrips()
            async let stationsTask = api.getStations()
            async let profileTask = api.fetchProfile()

            let wallet = try await walletTask
            let trips = try await tripsTask
            let rawStations = try await stationsTask
            let profile = try await profileTask

            self.profile = profile
            walletSummary = wallet
            self.trips = trips.sorted(by: tripSort)
            activeTrip = self.trips.first(where: \.isActive)
            stations = await decorateStationsWithDistance(rawStations)
            nearestStation = stations.first

            if let activeTrip {
                activeBike = try? await api.getBike(by: activeTrip.bikeId)
            } else {
                activeBike = nil
            }
        } catch {
            present(error, title: "No se pudo cargar Cyclix")
        }
    }

    func loadWalletDetails() async {
        guard isAuthenticated else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let walletTask = api.getWallet()
            async let txTask = api.getWalletTransactions()
            walletSummary = try await walletTask
            walletTransactions = try await txTask
        } catch {
            present(error, title: "Wallet no disponible")
        }
    }

    func topUpWallet(amount: Double, paymentMethod: String) async {
        guard amount > 0 else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            walletSummary = try await api.topUpWallet(amount: amount, paymentMethod: paymentMethod)
            walletTransactions = try await api.getWalletTransactions()
            alert = CyclixWatchAlert(title: "Recarga enviada", message: "El saldo se actualizo correctamente.")
        } catch {
            present(error, title: "No se pudo recargar")
        }
    }

    func loadTrips() async {
        guard isAuthenticated else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedTrips = try await api.getMyTrips().sorted(by: tripSort)
            trips = loadedTrips
            activeTrip = loadedTrips.first(where: \.isActive)
            if let activeTrip {
                activeBike = try? await api.getBike(by: activeTrip.bikeId)
            } else {
                activeBike = nil
            }
        } catch {
            present(error, title: "No se pudo cargar el historial")
        }
    }

    func loadStations() async {
        guard isAuthenticated else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedStations = try await api.getStations()
            stations = await decorateStationsWithDistance(loadedStations)
            nearestStation = stations.first
        } catch {
            present(error, title: "No se pudieron cargar los puestos")
        }
    }

    func selectStation(_ station: CyclixStationSummary) async {
        selectedStationID = station.id
        isLoading = true
        defer { isLoading = false }

        do {
            stationBikes = try await api.getBikesByStation(station.id)
        } catch {
            present(error, title: "No se pudieron cargar las bicicletas")
        }
    }

    func loadTickets() async {
        guard isAuthenticated else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            tickets = try await api.getMyTickets()
        } catch {
            present(error, title: "Soporte no disponible")
        }
    }

    func createTicket(
        category: String,
        priority: String,
        title: String,
        description: String,
        bikeID: String?,
        tripID: String?
    ) async {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            alert = CyclixWatchAlert(title: "Faltan datos", message: "Escribe titulo y descripcion.")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            if category == "BIKE", let bikeID, !bikeID.isEmpty {
                try await api.createFailureReport(
                    bikeID: bikeID,
                    tripID: tripID,
                    priority: priority,
                    title: title,
                    description: description
                )
            } else {
                try await api.createTicket(
                    category: category,
                    priority: priority,
                    title: title,
                    description: description,
                    bikeID: bikeID,
                    tripID: tripID
                )
            }

            tickets = try await api.getMyTickets()
            alert = CyclixWatchAlert(title: "Ticket creado", message: "Soporte recibio tu reporte.")
        } catch {
            present(error, title: "No se pudo crear el ticket")
        }
    }

    func lookupBike(identifier: String) async throws -> CyclixBikeSummary {
        try await api.getBike(by: identifier)
    }

    func getCurrentPricingRule() async throws -> CyclixPricingRule? {
        try await api.getCurrentPricingRule()
    }

    func startTrip(with bike: CyclixBikeSummary) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let coordinate = await locationProvider.currentCoordinateOrFallback()
            try await api.validateZone(latitude: coordinate.latitude, longitude: coordinate.longitude, start: true)
            let trip = try await api.createTrip(
                bikeID: bike.id,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            activeTrip = trip
            activeBike = bike
            trips.insert(trip, at: 0)
            walletSummary = try? await api.getWallet()
            alert = CyclixWatchAlert(title: "Viaje iniciado", message: "Bicicleta #\(bike.id) desbloqueada sin NFC.")
        } catch {
            present(error, title: "No se pudo iniciar el viaje")
        }
    }

    func finishActiveTrip() async {
        guard let activeTrip else { return }
        await finishTrip(activeTrip)
    }

    func finishTrip(_ trip: CyclixTripSummary) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let coordinate = await locationProvider.currentCoordinateOrFallback()
            try await api.validateZone(latitude: coordinate.latitude, longitude: coordinate.longitude, start: false)
            let finished = try await api.finishTrip(
                tripID: trip.id,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )

            if let index = trips.firstIndex(where: { $0.id == finished.id }) {
                trips[index] = finished
            } else {
                trips.insert(finished, at: 0)
            }
            activeTrip = nil
            activeBike = nil
            walletSummary = try? await api.getWallet()
            alert = CyclixWatchAlert(title: "Viaje finalizado", message: "El cobro se reflejara en tu wallet.")
        } catch {
            present(error, title: "No se pudo finalizar")
        }
    }

    func present(_ error: Error, title: String = "Error") {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        alert = CyclixWatchAlert(title: title, message: message)
    }

    private func hydrateFromSession() {
        isAuthenticated = sessionStore.hasSession
        profile = sessionStore.profile ?? CyclixUserProfile(email: sessionStore.email ?? "")
        isBootstrapping = false
    }

    private func decorateStationsWithDistance(_ stations: [CyclixStationSummary]) async -> [CyclixStationSummary] {
        let current = await locationProvider.currentCoordinateOrFallback()
        let currentLocation = CLLocation(latitude: current.latitude, longitude: current.longitude)

        return stations
            .map { station in
                guard let coordinate = cyclixCoordinate(from: station) else { return station }
                let stationLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                return station.with(distanceMeters: currentLocation.distance(from: stationLocation))
            }
            .sorted { ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude) }
    }

    private var tripSort: (CyclixTripSummary, CyclixTripSummary) -> Bool {
        { lhs, rhs in
            let leftDate = lhs.startedAt ?? .distantPast
            let rightDate = rhs.startedAt ?? .distantPast
            return leftDate > rightDate
        }
    }
}
