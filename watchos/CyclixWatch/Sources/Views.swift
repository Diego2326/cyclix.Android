import CoreLocation
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: CyclixWatchStore

    var body: some View {
        Group {
            if store.isBootstrapping {
                ProgressView("Cargando Cyclix...")
            } else if store.isLoggedIn {
                DashboardView()
            } else {
                LoginView()
            }
        }
        .alert("Cyclix", isPresented: alertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? store.successMessage ?? "")
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil || store.successMessage != nil },
            set: { isPresented in
                if !isPresented {
                    store.errorMessage = nil
                    store.successMessage = nil
                }
            }
        )
    }
}

struct LoginView: View {
    @EnvironmentObject private var store: CyclixWatchStore
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "bicycle.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.green)
                    Text("Cyclix Watch")
                        .font(.headline)
                    Text("Accede al mismo API del sistema principal.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            Section("Sesión") {
                TextField("Correo", text: $email)
                    .autocorrectionDisabled()
                SecureField("Contraseña", text: $password)
            }

            Section {
                Button {
                    Task {
                        await store.login(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                    }
                } label: {
                    if store.isAuthenticating {
                        ProgressView()
                    } else {
                        Text("Entrar")
                    }
                }
                .disabled(store.isAuthenticating)
            }
        }
        .onAppear {
            email = store.savedEmail
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: CyclixWatchStore

    var body: some View {
        NavigationStack {
            List {
                if let user = store.user {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.fullName.isEmpty ? "Usuario Cyclix" : user.fullName)
                                .font(.headline)
                            Text(user.role)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Resumen") {
                    infoRow(
                        title: "Wallet",
                        value: store.wallet?.balanceText ?? "Cargando..."
                    )
                    infoRow(
                        title: "Estación cercana",
                        value: store.sortedStations.first?.name ?? "Sin datos",
                        detail: store.sortedStations.first?.distanceText(from: store.currentLocation)
                    )
                    if let trip = store.activeTrip {
                        infoRow(
                            title: "Viaje activo",
                            value: trip.title,
                            detail: trip.durationText
                        )
                    }
                }

                Section("Acciones") {
                    if store.activeTrip == nil {
                        NavigationLink("Desbloquear bicicleta") {
                            UnlockView()
                        }
                    } else {
                        NavigationLink("Ver viaje activo") {
                            RideView()
                        }
                    }
                    NavigationLink("Wallet") {
                        WalletView()
                    }
                    NavigationLink("Estaciones") {
                        StationsView()
                    }
                    NavigationLink("Historial") {
                        TripsHistoryView()
                    }
                    NavigationLink("Perfil") {
                        ProfileView()
                    }
                    NavigationLink("Soporte") {
                        SupportView()
                    }
                }

                if store.bleConfiguration.isPlaceholderConfiguration {
                    Section("BLE") {
                        Text("Configura UUIDs y comandos reales en BLEBikeConfiguration antes de producción.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Cyclix")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salir") {
                        store.logout()
                    }
                }
            }
            .refreshable {
                await store.refresh()
            }
        }
    }

    @ViewBuilder
    private func infoRow(title: String, value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.bold())
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct UnlockView: View {
    @EnvironmentObject private var store: CyclixWatchStore
    @State private var bikeId = ""

    var body: some View {
        List {
            Section("Bicicleta") {
                TextField("ID de bicicleta", text: $bikeId)
                if let trip = store.activeTrip {
                    Text("Ya tienes un viaje activo con \(trip.title).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("BLE") {
                Text(store.bleStatusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    Task {
                        await store.unlockBikeAndStartTrip(bikeId: bikeId)
                    }
                } label: {
                    if store.isUnlocking {
                        ProgressView()
                    } else {
                        Text("Escanear y desbloquear")
                    }
                }
                .disabled(store.isUnlocking || store.activeTrip != nil)
            }

            Section("Cómo funciona") {
                Text("1. Valida la zona actual.\n2. Busca la bici por BLE.\n3. Envía comando de desbloqueo.\n4. Registra el viaje en el API.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Desbloquear")
    }
}

struct RideView: View {
    @EnvironmentObject private var store: CyclixWatchStore
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            if let trip = store.activeTrip {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(trip.title)
                            .font(.headline)
                        Text(elapsedText(for: trip))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        Text("Estado: \(trip.status)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Acciones") {
                    Button {
                        Task {
                            await store.finishActiveTrip(requireBLELock: true)
                        }
                    } label: {
                        if store.isFinishingTrip {
                            ProgressView()
                        } else {
                            Text("Bloquear y finalizar")
                        }
                    }

                    Button("Finalizar sin BLE") {
                        Task {
                            await store.finishActiveTrip(requireBLELock: false)
                        }
                    }
                    .disabled(store.isFinishingTrip)
                }

                Section("Nota") {
                    Text("Usa el cierre BLE cuando el hardware real lo soporte. Si una bici no expone BLE, puedes cerrar solo el viaje.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Text("No hay un viaje activo.")
                }
            }
        }
        .navigationTitle("Viaje")
        .onReceive(timer) { date in
            now = date
        }
    }

    private func elapsedText(for trip: CyclixTrip) -> String {
        guard let start = trip.startedAt else { return "00:00" }
        return CyclixFormatters.duration(now.timeIntervalSince(start))
    }
}

struct WalletView: View {
    @EnvironmentObject private var store: CyclixWatchStore

    var body: some View {
        List {
            Section("Saldo") {
                Text(store.wallet?.balanceText ?? "Sin datos")
                    .font(.headline)
            }

            Section("Movimientos") {
                if store.walletTransactions.isEmpty {
                    Text("No hay movimientos recientes.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.walletTransactions.prefix(8)) { transaction in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(transaction.description)
                                .font(.footnote.weight(.semibold))
                            Text(transaction.amountText)
                                .font(.caption)
                            if let createdAt = transaction.createdAt {
                                Text(createdAt, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Wallet")
    }
}

struct StationsView: View {
    @EnvironmentObject private var store: CyclixWatchStore

    var body: some View {
        List {
            if store.sortedStations.isEmpty {
                Section {
                    Text("No hay estaciones cargadas.")
                }
            } else {
                ForEach(store.sortedStations) { station in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(station.name)
                            .font(.footnote.weight(.semibold))
                        Text(station.address)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(station.distanceText(from: store.currentLocation))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let available = station.availableSlots, let total = station.totalSlots {
                            Text("Disponibles: \(available)/\(total)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Estaciones")
    }
}

struct TripsHistoryView: View {
    @EnvironmentObject private var store: CyclixWatchStore

    var body: some View {
        List {
            if store.trips.isEmpty {
                Section {
                    Text("No hay viajes registrados.")
                }
            } else {
                ForEach(store.trips.filter { !$0.isActive }.prefix(10)) { trip in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(trip.title)
                            .font(.footnote.weight(.semibold))
                        Text("Duración: \(trip.durationText)")
                            .font(.caption2)
                        Text("Total: \(trip.totalText)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Historial")
    }
}

struct ProfileView: View {
    @EnvironmentObject private var store: CyclixWatchStore

    var body: some View {
        List {
            if let user = store.user {
                Section("Usuario") {
                    dataRow("Nombre", user.fullName.isEmpty ? "No disponible" : user.fullName)
                    dataRow("Correo", user.email)
                    dataRow("Teléfono", user.phone)
                    dataRow("Rol", user.role)
                }
            } else {
                Section {
                    Text("No se pudo cargar el perfil.")
                }
            }
        }
        .navigationTitle("Perfil")
    }

    @ViewBuilder
    private func dataRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.weight(.semibold))
        }
    }
}

struct SupportView: View {
    @EnvironmentObject private var store: CyclixWatchStore
    @State private var selectedIssue = CyclixIssuePreset.quickIssues.first!
    @State private var note = ""

    var body: some View {
        List {
            Section("Motivo") {
                Picker("Incidencia", selection: $selectedIssue) {
                    ForEach(CyclixIssuePreset.quickIssues) { issue in
                        Text(issue.title).tag(issue)
                    }
                }
                Text(selectedIssue.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Detalle") {
                TextField("Nota breve", text: $note)
            }

            Section {
                Button {
                    Task {
                        await store.sendEmergencyTicket(issue: selectedIssue, note: note)
                    }
                } label: {
                    if store.isSendingSupport {
                        ProgressView()
                    } else {
                        Text("Enviar a soporte")
                    }
                }
            }
        }
        .navigationTitle("Soporte")
    }
}
