import SwiftUI

extension View {
    /// Present a fullscreen modal sheet.
    ///
    /// - Parameters:
    ///   - isPresented: Binding to control sheet presentation
    ///   - content: Content to display in the sheet
    func fullScreenModal<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            content()
        }
    }

    /// Conditionally navigate using NavigationLink.
    ///
    /// - Parameters:
    ///   - isActive: Binding to control navigation state
    ///   - destination: Destination view
    func navigate<Destination: View>(
        isActive: Binding<Bool>,
        @ViewBuilder to destination: @escaping () -> Destination
    ) -> some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                self

                NavigationLink(
                    isActive: isActive,
                    destination: destination
                ) {
                    EmptyView()
                }
                .hidden()
            }
        }
    }

    /// Apply toolbar appearance styling.
    func styledToolbar() -> some View {
        self.toolbarBackground(VColors.secondaryBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }

    /// Add a custom back button.
    ///
    /// - Parameter action: Action to perform when back button is tapped
    func customBackButton(action: @escaping () -> Void) -> some View {
        self.navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: action) {
                        HStack(spacing: VSpacing.xs) {
                            Image(systemName: VIcons.Actions.back)
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(VTypography.body)
                        }
                        .foregroundColor(VColors.primary)
                    }
                }
            }
    }

    /// Add a custom close button (X icon).
    ///
    /// - Parameter action: Action to perform when close button is tapped
    func customCloseButton(action: @escaping () -> Void) -> some View {
        self.toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: action) {
                    Image(systemName: VIcons.Actions.close)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(VColors.textSecondary)
                }
            }
        }
    }

    /// Add a loading overlay while async operation is in progress.
    ///
    /// - Parameters:
    ///   - isLoading: Binding controlling overlay visibility
    ///   - message: Optional loading message
    func loadingOverlay(
        isLoading: Binding<Bool>,
        message: String = "Loading..."
    ) -> some View {
        ZStack {
            self

            if isLoading.wrappedValue {
                VStack(spacing: VSpacing.md) {
                    ProgressView()
                        .tint(VColors.primary)

                    Text(message)
                        .font(VTypography.body)
                        .foregroundColor(VColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VColors.background.opacity(0.4))
            }
        }
    }

    /// Add an alert with custom styling.
    ///
    /// - Parameters:
    ///   - isPresented: Binding to control alert presentation
    ///   - title: Alert title
    ///   - message: Alert message
    ///   - primaryAction: Primary button label and action
    ///   - secondaryAction: Optional secondary button action
    func customAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        primaryActionLabel: String,
        primaryAction: @escaping () -> Void,
        secondaryActionLabel: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) -> some View {
        self.alert(title, isPresented: isPresented) {
            Button(primaryActionLabel, action: primaryAction)
            if let label = secondaryActionLabel {
                Button(label, action: secondaryAction ?? {})
            }
        } message: {
            Text(message)
        }
    }
}

// MARK: - Navigation State Management
class NavigationState: ObservableObject {
    @Published var path: NavigationPath = NavigationPath()

    func push<V: Hashable>(_ value: V) {
        path.append(value)
    }

    func pop() {
        path.removeLast()
    }

    func popToRoot() {
        path.removeLast(path.count)
    }
}
