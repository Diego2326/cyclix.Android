import SwiftUI

struct CyclixDashboardView: View {
    @EnvironmentObject private var store: CyclixWatchStore

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.profile.displayName.isEmpty ? "Cyclix Watch" : store.profile.displayName)
                        .font(.headline)
                    if !store.profile.email.isEmpty {
                        Text(store.profile.email)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }

            Section("Resumen") {
                CyclixMetricRow(
                    title: "Wallet",
                    value: store.walletSummary?.formattedBalance ?? "Cargando..."
                )

                CyclixMetricRow(
                    title: "Puesto cercano",
                    value: store.nearestStation?.name ?? "Sin dato",
                    subtitle: cyclixDistance(store.nearestStation?.distanceMeters)
                )
            }

            if let trip = store.activeTrip {
                Section("Viaje activo") {
                    NavigationLink {
                        CyclixActiveTripView(trip: trip, bike: store.activeBike)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bicicleta #\(trip.bikeId)")
                                .fontWeight(.semibold)
                            Text("Tiempo: \(trip.elapsedText)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Finalizar viaje", role: .destructive) {
                        Task {
                            await store.finishTrip(trip)
                        }
                    }
                    .disabled(store.isLoading)
                }
            } else {
                Section("Viaje") {
                    NavigationLink("Desbloqueo manual") {
                        CyclixManualUnlockView()
                    }
                }
            }

            Section("Mas") {
                NavigationLink("Wallet") {
                    CyclixWalletView()
                }
                NavigationLink("Historial") {
                    CyclixTripsView()
                }
                NavigationLink("Puestos") {
                    CyclixStationsView()
                }
                NavigationLink("Soporte") {
                    CyclixSupportView()
                }
                NavigationLink("Perfil") {
                    CyclixProfileView()
                }
            }
        }
        .navigationTitle("Cyclix")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await store.refreshDashboard()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }
        }
        .overlay {
            if store.isLoading && store.walletSummary == nil {
                ProgressView()
            }
        }
    }
}

struct CyclixMetricRow: View {
    let title: String
    let value: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
                .lineLimit(2)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct CyclixActiveTripView: View {
    @EnvironmentObject private var store: CyclixWatchStore
    let trip: CyclixTripSummary
    let bike: CyclixBikeSummary?

    @State private var now = Date()

    private var elapsedText: String {
        let startedAt = trip.startedAt ?? now
        return cyclixDuration(now.timeIntervalSince(startedAt))
    }

    var body: some View {
        List {
            Section("Viaje") {
                CyclixMetricRow(title: "Bicicleta", value: bike?.displayName ?? "Bicicleta #\(trip.bikeId)")
                CyclixMetricRow(title: "Tiempo", value: elapsedText)
                CyclixMetricRow(title: "Inicio", value: trip.startedAtText)
                if let bike {
                    CyclixMetricRow(title: "Tarifa de referencia", value: bike.tariffDescription)
                }
            }

            Section {
                Button("Finalizar viaje", role: .destructive) {
                    Task {
                        await store.finishTrip(trip)
                    }
                }
                .disabled(store.isLoading)

                NavigationLink("Reportar soporte") {
                    CyclixSupportView(
                        category: "EMERGENCY",
                        priority: "CRITICAL",
                        bikeID: bike?.id ?? trip.bikeId,
                        tripID: trip.id
                    )
                }
            }
        }
        .navigationTitle("Activo")
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { value in
            now = value
        }
    }
}
