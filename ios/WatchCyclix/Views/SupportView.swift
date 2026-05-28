import SwiftUI

struct CyclixSupportView: View {
    @EnvironmentObject private var store: CyclixWatchStore

    let category: String
    let priority: String
    let bikeID: String?
    let tripID: String?

    @State private var selectedCategory: String
    @State private var selectedPriority: String
    @State private var title = ""
    @State private var description = ""

    private let categories = ["BIKE", "APP", "PAYMENT", "ACCOUNT", "TRIP", "EMERGENCY", "OTHER"]
    private let priorities = ["LOW", "MEDIUM", "HIGH", "CRITICAL"]

    init(
        category: String = "APP",
        priority: String = "MEDIUM",
        bikeID: String? = nil,
        tripID: String? = nil
    ) {
        self.category = category
        self.priority = priority
        self.bikeID = bikeID
        self.tripID = tripID
        _selectedCategory = State(initialValue: category)
        _selectedPriority = State(initialValue: priority)
    }

    var body: some View {
        List {
            Section("Nuevo ticket") {
                Picker("Categoria", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { item in
                        Text(item).tag(item)
                    }
                }

                Picker("Prioridad", selection: $selectedPriority) {
                    ForEach(priorities, id: \.self) { item in
                        Text(item).tag(item)
                    }
                }

                TextField("Titulo", text: $title)
                TextField("Descripcion", text: $description, axis: .vertical)

                Button("Enviar ticket") {
                    Task {
                        await store.createTicket(
                            category: selectedCategory,
                            priority: selectedPriority,
                            title: title,
                            description: description,
                            bikeID: bikeID ?? store.activeBike?.id,
                            tripID: tripID ?? store.activeTrip?.id
                        )
                        title = ""
                        description = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(store.isLoading)
            }

            Section("Mis tickets") {
                if store.tickets.isEmpty {
                    Text("No tienes tickets aun.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.tickets) { ticket in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ticket.title)
                                .fontWeight(.semibold)
                            Text("\(ticket.category) · \(ticket.priority) · \(ticket.status)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Soporte")
        .task {
            await store.loadTickets()
        }
    }
}
