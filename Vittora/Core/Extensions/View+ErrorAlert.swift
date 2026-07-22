import SwiftUI
import VittoraCore

extension View {
    func errorAlert(message: Binding<String?>) -> some View {
        errorAlert(message: message) {
            Button(String(localized: "OK")) {
                message.wrappedValue = nil
            }
        }
    }

    func errorAlert<Actions: View>(
        message: Binding<String?>,
        @ViewBuilder actions: @escaping () -> Actions
    ) -> some View {
        alert(
            String(localized: "Error"),
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented {
                        message.wrappedValue = nil
                    }
                }
            )
        ) {
            actions()
        } message: {
            Text(message.wrappedValue ?? String(localized: "Something went wrong."))
        }
    }
}
