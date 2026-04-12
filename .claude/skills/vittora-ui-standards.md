# Vittora UI Standards Skill

Use this skill to validate and implement UI patterns for Vittora. Ensures consistent navigation, layouts, state patterns, and accessibility across iOS, macOS, and iPadOS.

## Overview
This skill defines standards for SwiftUI implementation including navigation patterns, layout principles, state management, adaptive UI, animation, and accessibility requirements.

---

## Navigation Patterns

### Tab-Based Navigation (iOS/iPadOS)
Used for primary feature navigation in apps with 3-5 major sections.

**Implementation:**
```swift
@main
struct VittoraApp: App {
    @State private var selectedTab: AppTab = .dashboard
    
    enum AppTab {
        case dashboard
        case transactions
        case analytics
        case settings
    }
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.pie.fill")
                    }
                    .tag(AppTab.dashboard)
                
                TransactionsView()
                    .tabItem {
                        Label("Transactions", systemImage: "list.bullet")
                    }
                    .tag(AppTab.transactions)
                
                AnalyticsView()
                    .tabItem {
                        Label("Analytics", systemImage: "chart.bar.fill")
                    }
                    .tag(AppTab.analytics)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(AppTab.settings)
            }
        }
    }
}
```

**Requirements:**
- [ ] Maximum 5 tabs visible at once
- [ ] Icons and labels clearly indicate purpose
- [ ] Selected tab visually distinct
- [ ] Preserve state within each tab
- [ ] Smooth transitions between tabs

### Sidebar Navigation (macOS/iPad Split View)
For desktop-first or multi-pane layouts.

**Implementation:**
```swift
struct AppContentView: View {
    @State private var selectedNavItem: NavigationItem? = .dashboard
    
    var body: some View {
        NavigationSplitView {
            List(NavigationItem.allCases, id: \.self, selection: $selectedNavItem) { item in
                NavigationLink(value: item) {
                    Label(item.title, systemImage: item.icon)
                }
            }
            .navigationTitle("Vittora")
        } detail: {
            if let selectedNavItem {
                detailView(for: selectedNavItem)
            } else {
                Text("Select an item")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func detailView(for item: NavigationItem) -> some View {
        switch item {
        case .dashboard:
            DashboardView()
        case .transactions:
            TransactionsView()
        case .analytics:
            AnalyticsView()
        case .settings:
            SettingsView()
        }
    }
}

enum NavigationItem: String, CaseIterable {
    case dashboard, transactions, analytics, settings
    
    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .transactions: "Transactions"
        case .analytics: "Analytics"
        case .settings: "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: "chart.pie.fill"
        case .transactions: "list.bullet"
        case .analytics: "chart.bar.fill"
        case .settings: "gear"
        }
    }
}
```

**Requirements:**
- [ ] List or sidebar shows available sections
- [ ] Detail pane updates with selection
- [ ] Back button or section indicator visible
- [ ] Hierarchy clear and logical
- [ ] Works in split view and full-screen

### NavigationStack for Detail Navigation
All navigation to detail screens uses NavigationStack.

**Implementation:**
```swift
@Observable
class TransactionListViewModel {
    @ObservationIgnored
    var navigationPath = NavigationPath()
    
    var transactions: [TransactionEntity] = []
    
    func navigateToTransaction(_ transaction: TransactionEntity) {
        navigationPath.append(transaction.id)
    }
    
    func navigateBack() {
        navigationPath.removeLast()
    }
}

struct TransactionListView: View {
    @State var viewModel = TransactionListViewModel()
    
    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            List(viewModel.transactions) { transaction in
                NavigationLink(value: transaction.id) {
                    TransactionRowView(transaction: transaction)
                }
            }
            .navigationTitle("Transactions")
            .navigationDestination(for: UUID.self) { transactionID in
                if let transaction = viewModel.transactions.first(where: { $0.id == transactionID }) {
                    TransactionDetailView(transaction: transaction)
                }
            }
        }
    }
}
```

**Requirements:**
- [ ] Use NavigationStack for all multi-level navigation
- [ ] Navigation state observable and persistent
- [ ] Back button works consistently
- [ ] Deep linking supported
- [ ] No NavigationLink without NavigationStack

---

## Layout Principles

### Responsive Spacing
Use consistent spacing scale: 4, 8, 12, 16, 24, 32, 48, 64

**Implementation:**
```swift
struct VSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let base: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: VSpacing.base) {
            HeaderView()
            
            VStack(spacing: VSpacing.sm) {
                CardView()
                CardView()
            }
            .padding(.horizontal, VSpacing.base)
            
            Spacer()
        }
        .padding(VSpacing.lg)
    }
}
```

### Safe Area Handling
Always respect safe areas on notched devices.

```swift
struct DetailView: View {
    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            
            VStack {
                TopBar()
                
                ScrollView {
                    VStack {
                        // Content inside safe area
                    }
                    .padding(.horizontal)
                }
                
                BottomBar()
            }
            .ignoresSafeArea(edges: .bottom) // For tab bar
        }
    }
}
```

### Container vs Content
Clear distinction between container layouts and content views.

```swift
// Container: handles layout structure
struct DashboardView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: VSpacing.lg) {
                WalletSummaryCard()
                RecentTransactionsList()
                QuickActionButtons()
            }
            .padding(.horizontal)
        }
    }
}

// Content: self-contained reusable component
struct TransactionRowView: View {
    let transaction: TransactionEntity
    
    var body: some View {
        HStack(spacing: VSpacing.md) {
            Image(systemName: transaction.icon)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.body)
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(transaction.amount, format: .currency(code: "USD"))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(transaction.amount > 0 ? .green : .red)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}
```

**Checklist:**
- [ ] Consistent spacing from VSpacing scale
- [ ] Safe areas respected
- [ ] Container/content separation clear
- [ ] Padding applied at appropriate level
- [ ] Layouts adaptive to screen size

---

## State Patterns

### Empty State
When no data available.

```swift
struct TransactionListView: View {
    @State var viewModel = TransactionListViewModel()
    
    var body: some View {
        ZStack {
            if viewModel.transactions.isEmpty {
                EmptyStateView(
                    icon: "list.bullet",
                    title: String(localized: "No Transactions"),
                    message: String(localized: "You haven't made any transactions yet."),
                    action: ("Get Started", {
                        // Handle action
                    })
                )
            } else {
                transactionList
            }
        }
        .task {
            await viewModel.loadTransactions()
        }
    }
    
    var transactionList: some View {
        List {
            ForEach(viewModel.transactions, id: \.id) { transaction in
                TransactionRowView(transaction: transaction)
            }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let action: (String, () -> Void)?
    
    var body: some View {
        VStack(spacing: VSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            VStack(spacing: VSpacing.sm) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let (buttonText, handler) = action {
                Button(action: handler) {
                    Text(buttonText)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

### Loading State
During data fetch operations.

```swift
struct TransactionListView: View {
    @State var viewModel = TransactionListViewModel()
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                VStack(spacing: VSpacing.base) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading transactions...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.transactions.isEmpty {
                EmptyStateView(...)
            } else {
                transactionList
            }
        }
        .task {
            await viewModel.loadTransactions()
        }
    }
    
    var transactionList: some View {
        List {
            ForEach(viewModel.transactions, id: \.id) { transaction in
                TransactionRowView(transaction: transaction)
                    .redacted(reason: viewModel.isRefreshing ? .placeholder : [])
            }
        }
    }
}
```

### Error State
When operation fails.

```swift
struct TransactionListView: View {
    @State var viewModel = TransactionListViewModel()
    
    var body: some View {
        ZStack {
            if let error = viewModel.error {
                ErrorStateView(
                    error: error,
                    retryAction: {
                        Task {
                            await viewModel.loadTransactions()
                        }
                    }
                )
            } else if viewModel.isLoading {
                loadingView
            } else if viewModel.transactions.isEmpty {
                EmptyStateView(...)
            } else {
                transactionList
            }
        }
        .task {
            await viewModel.loadTransactions()
        }
    }
}

struct ErrorStateView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: VSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            VStack(spacing: VSpacing.sm) {
                Text("Something went wrong")
                    .font(.headline)
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: VSpacing.base) {
                Button("Dismiss") { }
                    .buttonStyle(.secondary)
                
                Button("Retry") {
                    retryAction()
                }
                .buttonStyle(.primary)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

**Checklist:**
- [ ] Empty state shown when no data
- [ ] Loading skeleton or spinner during fetch
- [ ] Error message with retry option on failure
- [ ] Smooth transitions between states
- [ ] States clearly distinguishable

---

## Adaptive UI

### Platform-Specific Layouts
```swift
struct DashboardView: View {
    var body: some View {
        #if os(iOS)
        iphoneLayout
        #elseif os(macOS)
        macosLayout
        #endif
    }
    
    var iphoneLayout: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VSpacing.lg) {
                    WalletCard()
                    TransactionsList()
                    QuickActions()
                }
                .padding()
            }
            .navigationTitle("Dashboard")
        }
    }
    
    var macosLayout: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                // Sidebar items
            }
        } detail: {
            ScrollView {
                HStack(spacing: VSpacing.lg) {
                    VStack { WalletCard() }
                    VStack { TransactionsList() }
                    VStack { QuickActions() }
                }
                .padding()
            }
        }
    }
}
```

### Size Classes
```swift
struct AdaptiveGridView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var columns: [GridItem] {
        let count = horizontalSizeClass == .compact ? 2 : 4
        return Array(repeating: GridItem(.flexible()), count: count)
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: VSpacing.base) {
            ForEach(0..<12, id: \.self) { index in
                CardView()
            }
        }
    }
}
```

**Checklist:**
- [ ] iPad layouts utilize horizontal space
- [ ] macOS uses sidebar or split view
- [ ] iPhone uses single-column layout
- [ ] Rotation handled gracefully
- [ ] Text sizes adjusted for platform

---

## Animation & Motion

### Transition Animations
```swift
struct ContentView: View {
    @State private var showingDetail = false
    
    var body: some View {
        ZStack {
            if !showingDetail {
                listView
                    .transition(.move(edge: .trailing))
            }
            
            if showingDetail {
                detailView
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingDetail)
    }
}
```

### Interactive Animations
```swift
struct InteractiveCardView: View {
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {}) {
            VStack {
                Text("Card Title")
            }
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .brightness(isPressed ? -0.1 : 0)
        }
        .pressEvents(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
        .animation(.easeOut(duration: 0.2), value: isPressed)
    }
}
```

**Checklist:**
- [ ] Animations support accessibility (not disabled)
- [ ] Duration under 400ms for UI transitions
- [ ] Springy feel for interactive elements
- [ ] Loading spinners smooth and continuous
- [ ] Gesture animations responsive

---

## Accessibility (A11y)

### VoiceOver Support
```swift
struct TransactionRowView: View {
    let transaction: TransactionEntity
    
    var body: some View {
        HStack {
            Image(systemName: transaction.icon)
            VStack(alignment: .leading) {
                Text(transaction.title)
                Text(transaction.date, style: .date)
            }
            Spacer()
            Text(transaction.amount, format: .currency(code: "USD"))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(transaction.title)")
        .accessibilityValue("\(transaction.amount) on \(transaction.date)")
        .accessibilityHint(transaction.amount > 0 ? "Income" : "Expense")
    }
}
```

### Color Contrast
- [ ] Text contrast ratio minimum 4.5:1 (normal text)
- [ ] Contrast ratio minimum 3:1 (large text)
- [ ] Not relying solely on color to convey information

### Dynamic Type
```swift
struct AccessibleTextView: View {
    var body: some View {
        VStack {
            Text("Headline")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text("Body text that wraps to multiple lines")
                .font(.body)
                .lineLimit(3)
        }
    }
}
```

### Touch Targets
- [ ] Minimum 44pt x 44pt touch target (iOS)
- [ ] Minimum 48pt x 48pt touch target (Android parity)
- [ ] Sufficient spacing between interactive elements

**A11y Checklist:**
- [ ] All interactive elements have accessibility labels
- [ ] Color not only information carrier
- [ ] Dynamic Type supported
- [ ] Minimum touch target sizes met
- [ ] VoiceOver friendly element grouping

---

## Design System Integration

### Color Tokens
```swift
struct VColor {
    // Primary colors
    static let primary = Color(red: 0.1, green: 0.5, blue: 0.9)
    static let primaryDark = Color(red: 0.08, green: 0.4, blue: 0.7)
    
    // Semantic colors
    static let success = Color(red: 0.2, green: 0.8, blue: 0.3)
    static let warning = Color(red: 1.0, green: 0.7, blue: 0.2)
    static let error = Color(red: 0.9, green: 0.2, blue: 0.2)
    
    // Neutral
    static let background = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.1, alpha: 1) : .white })
    static let surface = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.15, alpha: 1) : UIColor(white: 0.95, alpha: 1) })
    
    // Aliases for intent
    static let text = Color.primary
    static let textSecondary = Color.secondary
}
```

### Typography
```swift
struct VTypography {
    static let headline = Font.system(size: 28, weight: .bold, design: .default)
    static let title = Font.system(size: 24, weight: .semibold, design: .default)
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
}
```

---

## When to Use This Skill

- Implementing new screens or features
- Reviewing UI for consistency
- Ensuring platform-appropriate design
- Adding accessibility features
- Validating state patterns
- Troubleshooting navigation issues
- Design system documentation

