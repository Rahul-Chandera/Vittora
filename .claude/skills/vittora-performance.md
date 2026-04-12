# Vittora Performance Skill

Use this skill to optimize Vittora's performance. Covers list performance, query efficiency, rendering optimization, and memory management with measurement strategies.

## Overview
This skill provides performance optimization guidelines and measurement techniques to ensure Vittora runs smoothly across iOS, macOS, and iPadOS devices.

---

## List Performance

### LazyVGrid & LazyVStack
Lazy containers prevent rendering off-screen content.

```swift
struct TransactionGridView: View {
    let transactions: [TransactionEntity]
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(transactions, id: \.id) { transaction in
                TransactionCardView(transaction: transaction)
            }
        }
    }
}
```

### Explicit IDs in ForEach
Always provide explicit id parameter for stable identity.

```swift
// ❌ WRONG - Identity based on position
ForEach(transactions) { transaction in
    TransactionRowView(transaction: transaction)
}

// ✓ CORRECT - Stable identity
ForEach(transactions, id: \.id) { transaction in
    TransactionRowView(transaction: transaction)
}
```

### List Row Optimization
```swift
struct OptimizedListView: View {
    let transactions: [TransactionEntity]
    
    var body: some View {
        List {
            ForEach(transactions, id: \.id) { transaction in
                TransactionRowView(transaction: transaction)
                    // Prevent row recreation on parent refresh
                    .id(transaction.id)
                    // Disable separators if not needed
                    .listRowSeparator(.hidden)
            }
        }
        // Improve rendering performance
        .listStyle(.plain)
    }
}

// Keep row view simple
struct TransactionRowView: View {
    let transaction: TransactionEntity
    
    var body: some View {
        HStack(spacing: 12) {
            // Simple views, no heavy computations
            Image(systemName: transaction.icon)
            Text(transaction.title)
            Spacer()
            Text(transaction.amount, format: .currency(code: "USD"))
        }
        .padding(.vertical, 8)
    }
}
```

### Pagination for Large Lists
```swift
@Observable
class TransactionListViewModel {
    var transactions: [TransactionEntity] = []
    var hasMore: Bool = true
    private var currentPage: Int = 0
    private let pageSize: Int = 50
    
    func loadMore() async throws {
        let predicate = #Predicate<TransactionEntity> { _ in true }
        let descriptor = FetchDescriptor<TransactionEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchOffset = currentPage * pageSize
        descriptor.fetchLimit = pageSize
        
        let newTransactions = try modelContext.fetch(descriptor)
        transactions.append(contentsOf: newTransactions)
        
        hasMore = newTransactions.count == pageSize
        currentPage += 1
    }
}

struct TransactionListView: View {
    @State var viewModel = TransactionListViewModel()
    
    var body: some View {
        List {
            ForEach(viewModel.transactions, id: \.id) { transaction in
                TransactionRowView(transaction: transaction)
                    .onAppear {
                        // Load more when approaching end
                        if transaction.id == viewModel.transactions.last?.id && viewModel.hasMore {
                            Task {
                                try await viewModel.loadMore()
                            }
                        }
                    }
            }
        }
    }
}
```

**List Performance Checklist:**
- [ ] ForEach uses explicit id parameters
- [ ] Row views kept simple (under 30ms render time)
- [ ] Large lists use LazyVStack/LazyVGrid
- [ ] Pagination implemented for 100+ item lists
- [ ] No heavy computations in row views
- [ ] View identities stable (don't change between renders)

---

## Query Efficiency

### Query Optimization
```swift
// ❌ WRONG - Fetches all, filters in Swift
func getRecentExpenses() throws -> [TransactionEntity] {
    let descriptor = FetchDescriptor<TransactionEntity>()
    let all = try modelContext.fetch(descriptor)
    return all.filter { $0.amount < 0 && $0.date > Date().addingTimeInterval(-86400 * 7) }
}

// ✓ CORRECT - Filters at database level
func getRecentExpenses() throws -> [TransactionEntity] {
    let predicate = #Predicate<TransactionEntity> { transaction in
        transaction.amount < 0 &&
        transaction.date > Date().addingTimeInterval(-86400 * 7)
    }
    let descriptor = FetchDescriptor<TransactionEntity>(predicate: predicate)
    return try modelContext.fetch(descriptor)
}
```

### Index on Frequently Queried Properties
```swift
@Model
final class TransactionEntity {
    @Attribute(.unique) var id: UUID
    @Attribute(.indexed) var date: Date
    @Attribute(.indexed) var accountID: UUID
    @Attribute(.indexed) var status: TransactionStatus
    
    var amount: Decimal
    var description: String
}
```

### Query Limits
```swift
func getLatestTransactions(limit: Int = 100) throws -> [TransactionEntity] {
    let descriptor = FetchDescriptor<TransactionEntity>(
        sortBy: [SortDescriptor(\.date, order: .reverse)]
    )
    descriptor.fetchLimit = limit
    return try modelContext.fetch(descriptor)
}
```

### Batch Operations
```swift
// ❌ SLOW - Multiple saves
func updateMultipleTransactions(_ ids: [UUID]) throws {
    for id in ids {
        let predicate = #Predicate<TransactionEntity> { $0.id == id }
        if let transaction = try modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
            transaction.syncState = "synced"
            try modelContext.save() // Save each individually
        }
    }
}

// ✓ FAST - Single save
func updateMultipleTransactions(_ ids: [UUID]) throws {
    for id in ids {
        let predicate = #Predicate<TransactionEntity> { $0.id == id }
        if let transaction = try modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
            transaction.syncState = "synced"
        }
    }
    try modelContext.save() // Save all at once
}
```

**Query Efficiency Checklist:**
- [ ] Filters applied in #Predicate, not in Swift
- [ ] Frequently queried properties indexed
- [ ] Fetch limits applied for large result sets
- [ ] Batch saves instead of individual saves
- [ ] Complex queries profiled for performance
- [ ] Join operations minimized

---

## Chart & Graph Rendering

### Efficient Data Aggregation
```swift
@Observable
class DashboardViewModel {
    var monthlyData: [MonthlyAggregate] = []
    
    func loadMonthlyChart() async throws {
        // Aggregate at database level (SwiftData)
        let calendar = Calendar.current
        let now = Date()
        var aggregates: [MonthlyAggregate] = []
        
        for monthOffset in 0..<12 {
            let startOfMonth = calendar.date(byAdding: .month, value: -monthOffset, to: now)!
            let startOfDay = calendar.startOfDay(for: startOfMonth)
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfDay)!
            
            let predicate = #Predicate<TransactionEntity> { transaction in
                transaction.date >= startOfDay &&
                transaction.date < endOfMonth &&
                transaction.amount > 0
            }
            
            let descriptor = FetchDescriptor<TransactionEntity>(predicate: predicate)
            let transactions = try modelContext.fetch(descriptor)
            
            let total = transactions.reduce(Decimal.zero) { $0 + $1.amount }
            aggregates.append(MonthlyAggregate(month: startOfMonth, total: total))
        }
        
        monthlyData = aggregates
    }
}
```

### Simple Chart Rendering
```swift
import Charts

struct ChartView: View {
    let data: [MonthlyAggregate]
    
    var body: some View {
        Chart {
            ForEach(data, id: \.month) { aggregate in
                BarMark(
                    x: .value("Month", aggregate.month, unit: .month),
                    y: .value("Amount", aggregate.total)
                )
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month().year())
            }
        }
    }
}
```

### Avoid Expensive Calculations in Views
```swift
// ❌ WRONG - Recalculates on every render
struct ExpensiveChartView: View {
    let transactions: [TransactionEntity]
    
    var body: some View {
        Chart {
            // Computing sum every render
            ForEach(transactions.filter { $0.amount < 0 }, id: \.id) { transaction in
                BarMark(x: .value("Date", transaction.date), y: .value("Amount", transaction.amount))
            }
        }
    }
}

// ✓ CORRECT - Computed once in ViewModel
@Observable
class ChartViewModel {
    var chartData: [ChartDataPoint] = []
    
    func loadData() async throws {
        let predicate = #Predicate<TransactionEntity> { $0.amount < 0 }
        let descriptor = FetchDescriptor<TransactionEntity>(predicate: predicate)
        let expenses = try modelContext.fetch(descriptor)
        
        chartData = expenses.map { expense in
            ChartDataPoint(date: expense.date, amount: abs(expense.amount))
        }
    }
}
```

**Chart Performance Checklist:**
- [ ] Data aggregated in repository, not view
- [ ] Chart data cached and updated selectively
- [ ] Complex calculations in ViewModel
- [ ] Large datasets paginated or sampled
- [ ] Animation disabled on large datasets
- [ ] Charts refreshed only when needed

---

## Image & Document Loading

### Async Image Loading
```swift
struct UserAvatarView: View {
    let userID: UUID
    let imageURL: URL
    
    var body: some View {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case .empty:
                Image(systemName: "person.crop.circle")
                    .foregroundColor(.gray)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.red)
            @unknown default:
                EmptyView()
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
    }
}
```

### Image Caching
```swift
@Observable
class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    @ObservationIgnored
    private let cache = NSCache<NSString, UIImage>()
    
    func loadImage(from url: URL) async -> UIImage? {
        let cacheKey = url.lastPathComponent as NSString
        
        // Return cached image if available
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        // Load from network
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                cache.setObject(image, forKey: cacheKey)
                return image
            }
        } catch {
            print("Failed to load image: \(error)")
        }
        
        return nil
    }
}
```

### Thumbnail Loading for Documents
```swift
@Observable
class DocumentViewModel {
    var thumbnails: [UUID: UIImage] = [:]
    
    func loadDocumentThumbnail(for documentID: UUID, fileURL: URL) async {
        let size = CGSize(width: 100, height: 100)
        
        if let image = await generateThumbnail(from: fileURL, size: size) {
            await MainActor.run {
                thumbnails[documentID] = image
            }
        }
    }
    
    private func generateThumbnail(from url: URL, size: CGSize) async -> UIImage? {
        do {
            let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: 1, representationTypes: .all)
            let thumbnail = try await QLThumbnailGenerator.shared.generateRepresentations(for: request).first
            return thumbnail?.uiImage
        } catch {
            print("Failed to generate thumbnail: \(error)")
            return nil
        }
    }
}
```

**Image & Document Checklist:**
- [ ] Images loaded asynchronously with AsyncImage
- [ ] Image cache prevents reload
- [ ] Large documents loaded in background
- [ ] Placeholder shown during load
- [ ] Memory limits respected (cache size limits)
- [ ] Failed loads handled gracefully

---

## Memory Management

### Avoid Circular References
```swift
// ❌ WRONG - Potential memory leak
class TransactionViewModel {
    let repository: TransactionRepository
    
    func loadTransactions() async {
        // self captured strongly
        let transactions = try? await repository.fetchTransactions()
        self.transactions = transactions
    }
}

// ✓ CORRECT - Weak capture
@Observable
class TransactionViewModel {
    let repository: TransactionRepository
    
    func loadTransactions() async {
        do {
            let transactions = try await repository.fetchTransactions()
            self.transactions = transactions
        } catch {
            print("Failed to load: \(error)")
        }
    }
}
```

### Task Cancellation
```swift
@Observable
class SearchViewModel {
    var searchResults: [TransactionEntity] = []
    
    @ObservationIgnored
    private var searchTask: Task<Void, Never>?
    
    func search(term: String) {
        // Cancel previous search
        searchTask?.cancel()
        
        searchTask = Task {
            do {
                let results = try await performSearch(term: term)
                
                // Check if cancelled before updating
                if !Task.isCancelled {
                    self.searchResults = results
                }
            } catch {
                if !Task.isCancelled {
                    print("Search failed: \(error)")
                }
            }
        }
    }
    
    private func performSearch(term: String) async throws -> [TransactionEntity] {
        let predicate = #Predicate<TransactionEntity> { transaction in
            transaction.description.localizedCaseInsensitiveContains(term)
        }
        let descriptor = FetchDescriptor<TransactionEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }
}
```

### Memory Warning Response
```swift
import UIKit

@Observable
class AppViewModel {
    var isMemoryLow: Bool = false
    
    func setupMemoryWarning() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isMemoryLow = true
            self?.clearCaches()
        }
    }
    
    private func clearCaches() {
        ImageCacheManager.shared.clearCache()
        isMemoryLow = false
    }
}
```

**Memory Management Checklist:**
- [ ] No strong circular references
- [ ] Tasks cancelled when view dismissed
- [ ] Large data structures released properly
- [ ] Memory warnings trigger cache clearing
- [ ] Background tasks don't accumulate
- [ ] Closure captures use weak self where needed

---

## Startup Performance

### Lazy View Initialization
```swift
struct AppView: View {
    @State private var showDashboard = false
    
    var body: some View {
        ZStack {
            if showDashboard {
                DashboardView() // Deferred until needed
                    .transition(.opacity)
            } else {
                SplashScreen()
            }
        }
        .task {
            // Quick initial load
            await loadEssentialData()
            showDashboard = true
            
            // Heavy loading in background
            await loadOptionalData()
        }
    }
    
    private func loadEssentialData() async {
        // Just what's needed for first screen
    }
    
    private func loadOptionalData() async {
        // Defer heavier operations
    }
}
```

### Background Data Loading
```swift
@Observable
class AppViewModel {
    var userData: UserEntity?
    
    func initializeApp() async {
        // Load essentials synchronously
        await loadUserData()
        
        // Load heavy data in background
        Task(priority: .background) {
            await syncOfflineChanges()
            await loadOptionalData()
        }
    }
}
```

**Startup Checklist:**
- [ ] Heavy operations deferred from app launch
- [ ] Initial screen shows in <1 second
- [ ] Database init doesn't block UI
- [ ] CloudKit sync happens in background
- [ ] First view hierarchy keeps it simple

---

## Performance Measurement with os_signpost

### Mark Important Operations
```swift
import os

let logger = Logger(subsystem: "com.vittora.app", category: "performance")

@Observable
class TransactionListViewModel {
    var transactions: [TransactionEntity] = []
    
    func loadTransactions(for accountID: UUID) async throws {
        let signpostID = OSSignpostID(log: logger)
        os_signpost(.begin, log: logger, name: "Load Transactions", signpostID: signpostID)
        
        defer {
            os_signpost(.end, log: logger, name: "Load Transactions", signpostID: signpostID)
        }
        
        let predicate = #Predicate<TransactionEntity> { $0.accountID == accountID }
        let descriptor = FetchDescriptor<TransactionEntity>(predicate: predicate)
        transactions = try modelContext.fetch(descriptor)
    }
}
```

### Measure Query Performance
```swift
func measureQueryPerformance() {
    let signpostID = OSSignpostID(log: logger)
    
    os_signpost(.begin, log: logger, name: "Query", signpostID: signpostID, "query_type: fetch_by_date")
    
    let predicate = #Predicate<TransactionEntity> { _ in true }
    let descriptor = FetchDescriptor<TransactionEntity>(predicate: predicate)
    let _ = try modelContext.fetch(descriptor)
    
    os_signpost(.end, log: logger, name: "Query", signpostID: signpostID)
}
```

### View Instruments in Xcode
1. Scheme → Edit Scheme → Run → Diagnostics → check "Metal API Validation"
2. Profile → System Trace or Core Animation
3. Look for timing information in Instruments

**Measurement Checklist:**
- [ ] Key operations marked with os_signpost
- [ ] Database queries profiled
- [ ] View render times measured
- [ ] Image loading times tracked
- [ ] Startup time monitored
- [ ] Memory usage under 50MB baseline

---

## Performance Targets

| Metric | Target | Critical |
|--------|--------|----------|
| App Launch | <1.5s | <3s |
| List Scroll (60 FPS) | 16ms per frame | - |
| Query Execution | <100ms | <500ms |
| View Render | <16ms | <33ms |
| Image Load | <500ms | <2s |
| Memory Baseline | <30MB | <50MB |
| Chart Render | <200ms | <500ms |

---

## When to Use This Skill

- Optimizing slow list performance
- Improving app startup time
- Reducing memory usage
- Profiling database queries
- Fixing janky animations
- Improving responsiveness
- Measuring performance improvements
- Identifying performance bottlenecks

