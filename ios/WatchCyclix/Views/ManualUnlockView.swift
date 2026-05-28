import SwiftUI

struct CyclixManualUnlockView: View {
    @EnvironmentObject private var store: CyclixWatchStore

    let presetBike: CyclixBikeSummary?
    let prefilledIdentifier: String

    @State private var identifier = ""
    @State private var bike: CyclixBikeSummary?
    @State private var pricingRule: CyclixPricingRule?
    @State private var loadingBike = false

    init(presetBike: CyclixBikeSummary? = nil, prefilledIdentifier: String = "") {
        self.presetBike = presetBike
        self.prefilledIdentifier = prefilledIdentifier
    }

    var body: some View {
        List {
            Section("Desbloqueo") {
                Text("watchOS no usa NFC aqui. Ingresa el ID, codigo o URL del QR para iniciar el viaje.")
                    .font(.caption2)

                TextField("ID o codigo", text: $identifier)

                Button {
                    Task {
                        await lookupBike()
                    }
                } label: {
                    if loadingBike {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Buscar bicicleta")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loadingBike)
            }

            if let bike {
                Section("Bicicleta") {
                    CyclixMetricRow(title: "Nombre", value: bike.displayName)
                    CyclixMetricRow(title: "Codigo", value: bike.code.isEmpty ? bike.id : bike.code)
                    CyclixMetricRow(title: "Estado", value: bike.status.isEmpty ? "Sin dato" : bike.status)
                    if !bike.stationName.isEmpty {
                        CyclixMetricRow(title: "Puesto", value: bike.stationName)
                    }
                    CyclixMetricRow(title: "Tarifa", value: pricingRule?.previewText ?? bike.tariffDescription)
                }

                Section {
                    Button("Iniciar viaje") {
                        Task {
                            await store.startTrip(with: bike)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(store.isLoading || (!bike.status.isEmpty && bike.status != "DISPONIBLE"))
                }
            }
        }
        .navigationTitle("Manual")
        .task {
            identifier = prefilledIdentifier
            bike = presetBike
            if pricingRule == nil {
                pricingRule = try? await store.getCurrentPricingRule()
            }
        }
    }

    private func lookupBike() async {
        loadingBike = true
        defer { loadingBike = false }

        do {
            bike = try await store.lookupBike(identifier: identifier)
            if pricingRule == nil {
                pricingRule = try? await store.getCurrentPricingRule()
            }
        } catch {
            store.present(error, title: "Bicicleta no encontrada")
        }
    }
}
