import SwiftUI

extension View {
    func errorAlert(message: Binding<String?>) -> some View {
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
            Button(String(localized: "OK")) {
                message.wrappedValue = nil
            }
        } message: {
            Text(message.wrappedValue ?? String(localized: "Something went wrong."))
        }
    }
}
