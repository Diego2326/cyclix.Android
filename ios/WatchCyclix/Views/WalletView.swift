import SwiftUI

struct CyclixWalletView: View {
    @EnvironmentObject private var store: CyclixWatchStore
    @State private var selectedAmount = 25.0
    @State private var selectedMethod = "CARD"

    private let amounts = [25.0, 50.0, 100.0, 150.0]
    private let methods = [
        ("CARD", "Tarjeta"),
        ("TRANSFER", "Transferencia"),
        ("CASH", "Prueba")
    ]

    var body: some View {
        List {
            Section("Saldo") {
                Text(store.walletSummary?.formattedBalance ?? "Cargando...")
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Section("Recarga") {
                Picker("Monto", selection: $selectedAmount) {
                    ForEach(amounts, id: \.self) { amount in
                        Text(cyclixMoney(amount)).tag(amount)
                    }
                }

                Picker("Metodo", selection: $selectedMethod) {
                    ForEach(methods, id: \.0) { method in
                        Text(method.1).tag(method.0)
                    }
                }

                Button("Recargar saldo") {
                    Task {
                        await store.topUpWallet(amount: selectedAmount, paymentMethod: selectedMethod)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(store.isLoading)
            }

            Section("Movimientos") {
                if store.walletTransactions.isEmpty {
                    Text("Aun no hay movimientos.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.walletTransactions) { tx in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.description)
                                .fontWeight(.semibold)
                            Text("\(tx.type) · \(tx.createdAt.map(CyclixFormatters.dateTime.string(from:)) ?? "Sin fecha")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(cyclixMoney(tx.amount, currencyCode: store.walletSummary?.currency ?? "GTQ"))
                                .font(.caption)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Wallet")
        .task {
            await store.loadWalletDetails()
        }
    }
}
