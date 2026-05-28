import SwiftUI

struct CyclixLoginView: View {
    @EnvironmentObject private var store: CyclixWatchStore
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "bicycle.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)

                Text("CYCLIX")
                    .font(.headline)
                    .fontWeight(.heavy)

                TextField("Correo", text: $email)
                    .textContentType(.emailAddress)

                SecureField("Clave", text: $password)
                    .textContentType(.password)

                Button {
                    Task {
                        await store.login(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                    }
                } label: {
                    if store.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Entrar")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(store.isLoading)
            }
            .padding()
        }
    }
}
