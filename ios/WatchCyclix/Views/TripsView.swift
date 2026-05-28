import SwiftUI

struct CyclixTripsView: View {
    @EnvironmentObject private var store: CyclixWatchStore

    var body: some View {
        List {
            if store.trips.isEmpty {
                Text("Todavia no hay viajes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.trips) { trip in
                    NavigationLink {
                        CyclixTripDetailView(trip: trip, bike: trip.id == store.activeTrip?.id ? store.activeBike : nil)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bicicleta #\(trip.bikeId)")
                                .fontWeight(.semibold)
                            Text("\(trip.status) · \(trip.startedAtText)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Total: \(cyclixMoney(trip.totalToDisplay))")
                                .font(.caption)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Historial")
        .task {
            await store.loadTrips()
        }
    }
}

struct CyclixTripDetailView: View {
    @EnvironmentObject private var store: CyclixWatchStore
    let trip: CyclixTripSummary
    let bike: CyclixBikeSummary?

    var body: some View {
        List {
            Section("Resumen") {
                CyclixMetricRow(title: "Bicicleta", value: bike?.displayName ?? "Bicicleta #\(trip.bikeId)")
                CyclixMetricRow(title: "Estado", value: trip.status)
                CyclixMetricRow(title: "Inicio", value: trip.startedAtText)
                CyclixMetricRow(title: "Duracion", value: trip.elapsedText)
                CyclixMetricRow(title: "Distancia", value: String(format: "%.2f km", trip.distanceKm))
                CyclixMetricRow(title: "Total", value: cyclixMoney(trip.totalToDisplay))
                if let pricing = trip.pricingRuleName {
                    CyclixMetricRow(title: "Tarifa", value: pricing)
                }
            }

            if trip.isActive {
                Section {
                    Button("Finalizar viaje", role: .destructive) {
                        Task {
                            await store.finishTrip(trip)
                        }
                    }
                    .disabled(store.isLoading)
                }
            }
        }
        .navigationTitle("Viaje")
    }
}
