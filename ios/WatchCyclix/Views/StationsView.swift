import SwiftUI

struct CyclixStationsView: View {
    @EnvironmentObject private var store: CyclixWatchStore

    var body: some View {
        List {
            if store.stations.isEmpty {
                Text("No hay puestos activos.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.stations) { station in
                    VStack(alignment: .leading, spacing: 4) {
                        Button {
                            Task {
                                await store.selectStation(station)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(station.name)
                                    .fontWeight(.semibold)
                                Text(cyclixDistance(station.distanceMeters))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if !station.address.isEmpty {
                                    Text(station.address)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text("Disponibles: \(station.availableCapacity)/\(station.totalCapacity)")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        if store.selectedStationID == station.id {
                            if store.stationBikes.isEmpty {
                                Text("Sin bicis disponibles.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(store.stationBikes) { bike in
                                    NavigationLink {
                                        CyclixManualUnlockView(presetBike: bike, prefilledIdentifier: bike.id)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(bike.displayName)
                                            Text("#\(bike.id) · \(bike.tariffDescription)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Puestos")
        .task {
            await store.loadStations()
        }
    }
}
