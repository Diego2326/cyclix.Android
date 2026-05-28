import SwiftUI

struct CyclixProfileView: View {
    @EnvironmentObject private var store: CyclixWatchStore

    var body: some View {
        List {
            Section("Cuenta") {
                CyclixMetricRow(title: "Nombre", value: store.profile.displayName)
                CyclixMetricRow(title: "Correo", value: store.profile.email.isEmpty ? "Sin correo" : store.profile.email)
                if !store.profile.phone.isEmpty {
                    CyclixMetricRow(title: "Telefono", value: store.profile.phone)
                }
                if !store.profile.role.isEmpty {
                    CyclixMetricRow(title: "Rol", value: store.profile.role)
                }
            }

            Section {
                Button("Actualizar perfil") {
                    Task {
                        await store.refreshDashboard()
                    }
                }
                .disabled(store.isLoading)

                Button("Cerrar sesion", role: .destructive) {
                    store.logout()
                }
            }
        }
        .navigationTitle("Perfil")
    }
}
