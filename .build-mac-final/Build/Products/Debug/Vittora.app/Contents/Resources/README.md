# Budgets Feature Module (PB2)

Complete implementation of the Budgets feature for the Vittora iOS/macOS app.

## Quick Start

### Main Entry Point
```swift
import Vittora

// In your app's tab view or navigation:
BudgetsFeature()
```

### Key Classes

#### ViewModels
- **BudgetListViewModel**: Manages list of budgets with filtering by period
- **BudgetDetailViewModel**: Loads individual budget with category and recent transactions
- **BudgetFormViewModel**: Handles create/edit budget forms

#### Views
- **BudgetListView**: Main list with period selector and add button
- **BudgetDetailView**: Detailed view with progress ring, charts, and transactions
- **BudgetFormView**: Form for creating/editing budgets

#### Components
- **BudgetCardView**: Card displaying budget with progress bar
- **BudgetProgressRing**: Circular progress indicator with percentage
- **DailySpendChart**: Bar chart of daily spending vs budget average
- **PeriodSelectorView**: Period filter (weekly/monthly/quarterly/yearly)
- **BudgetOverviewCard**: Summary card showing total budget/spent/remaining

## Use Cases

All use cases are in `Core/Domain/UseCases/`:

### Core Operations
- **FetchBudgetsUseCase**: Load active or all budgets with computed spent amounts
- **CreateBudgetUseCase**: Create new budget with validation
- **UpdateBudgetUseCase**: Update existing budget
- **DeleteBudgetUseCase**: Delete budget by ID

### Analytics & Insights
- **CalculateBudgetProgressUseCase**: Compute progress metrics (spent, remaining, percentage, projected spend)
- **CheckBudgetThresholdUseCase**: Identify budgets near or over limits

### Advanced Operations
- **RolloverBudgetUseCase**: Create next period budget with optional rollover of unused amount
- **CopyBudgetTemplateUseCase**: Copy budgets from one period to another

## Data Models

### BudgetEntity
```swift
struct BudgetEntity: Identifiable {
    let id: UUID
    var amount: Decimal
    var spent: Decimal
    var period: BudgetPeriod
    var startDate: Date
    var rollover: Bool
    var categoryID: UUID?
    
    var remaining: Decimal { amount - spent }
    var progress: Double { spent / amount }
    var isOverBudget: Bool { spent > amount }
}
```

### BudgetPeriod
```swift
enum BudgetPeriod: String, CaseIterable {
    case weekly, monthly, quarterly, yearly
}
```

### BudgetProgress
```swift
struct BudgetProgress: Sendable {
    let budget: BudgetEntity
    let spent: Decimal
    let remaining: Decimal
    let percentage: Double
    let daysRemaining: Int
    let projectedSpend: Decimal
    let statusColor: String  // "safe" / "warning" / "danger"
}
```

## Architecture Highlights

### Swift 6 Modern Patterns
- All use cases are `Sendable struct`
- ViewModels use `@Observable @MainActor final class`
- No Combine or ObservableObject

### Cross-Platform
- iOS: Segmented period picker, insetGrouped list style
- macOS: Chip-based period selector, inset list style

### Design System Integration
- **VColors**: Primary, safe, warning, danger semantic colors
- **VTypography**: Title, body, caption, amount-specific fonts
- **VSpacing**: Consistent spacing scale (sm, md, lg, xl)
- **Components**: VCard, VProgressBar, VAmountText, VEmptyState

### Dependency Injection
Uses `@Environment(\.dependencies)` for access to:
- `budgetRepository`
- `categoryRepository`
- `transactionRepository`

### Error Handling
```swift
throw VittoraError.validationFailed("Budget amount must be > 0")
throw VittoraError.notFound("Budget not found")
```

## Common Tasks

### Create a Budget
```swift
let useCase = CreateBudgetUseCase(budgetRepository: repository)
try await useCase.execute(
    amount: 1000,
    period: .monthly,
    categoryID: groceriesCategoryID,
    rollover: true,
    startDate: Date()
)
```

### Load Budgets with Progress
```swift
let fetchUseCase = FetchBudgetsUseCase(budgetRepository, transactionRepository)
let progressUseCase = CalculateBudgetProgressUseCase()

let budgets = try await fetchUseCase.execute()
for budget in budgets {
    let progress = progressUseCase.execute(budget: budget)
    print("\(budget.amount) spent \(progress.percentage)%")
}
```

### Check Budget Status
```swift
let checkUseCase = CheckBudgetThresholdUseCase()
let atRisk = checkUseCase.execute(budgets: budgets)  // >= 50%
// Trigger notifications for at-risk budgets
```

### Rollover Budget
```swift
let rolloverUseCase = RolloverBudgetUseCase(budgetRepository: repository)
let nextMonthStart = Date().addingTimeInterval(86400 * 30)
try await rolloverUseCase.execute(budgetID: budgetID, newStartDate: nextMonthStart)
```

## Navigation

Budget routes are defined in `NavigationDestination`:
```swift
case budgetDetail(id: UUID)  // Navigate to detail view
case addBudget               // Open add/edit sheet
```

Example usage:
```swift
NavigationLink(value: NavigationDestination.budgetDetail(id: budget.id)) {
    BudgetCardView(...)
}
```

## Testing

### Mock Repositories
Mock implementations available in `Features/Budgets/Mocks/`:
- `MockBudgetRepository`
- `MockCategoryRepository`
- `MockTransactionRepository`

Use in previews:
```swift
#Preview {
    BudgetListView()
        .environment(\.dependencies, DependencyContainer())
}
```

## Performance Considerations

1. **Spent Calculation**: Computed on-demand per budget (filters transactions in period)
2. **Caching**: BudgetProgress cached in `BudgetListViewModel.budgetProgress` dict
3. **Batch Operations**: Use `BulkOperationsUseCase` for multiple deletions
4. **Pagination**: Recent transactions limited to 5 in detail view

## Future Roadmap

- [ ] Budget templates library
- [ ] Recurring budget schedules
- [ ] Multi-currency support
- [ ] Budget alerts/notifications
- [ ] Export to PDF/Excel
- [ ] Budget vs actual comparison reports
- [ ] Seasonal budget adjustments
- [ ] Shared budgets (multi-user)

## File Organization

```
Features/Budgets/
├── BudgetsFeature.swift          # Main entry point
├── ViewModels/                   # State management
├── Views/                        # Screen UIs
├── Components/                   # Reusable views
├── Mocks/                        # Test doubles
├── README.md                     # This file
└── ARCHITECTURE.md               # Detailed architecture

Core/Domain/UseCases/
├── FetchBudgetsUseCase.swift
├── CreateBudgetUseCase.swift
├── UpdateBudgetUseCase.swift
├── DeleteBudgetUseCase.swift
├── CalculateBudgetProgressUseCase.swift
├── CheckBudgetThresholdUseCase.swift
├── RolloverBudgetUseCase.swift
└── CopyBudgetTemplateUseCase.swift
```

## Related Features

- **PA2 - Categories**: Provides category picker and category entities
- **TA3 - Transactions**: Provides transaction data for spent calculation
- **Accounts**: Account context for transaction filtering

## Questions?

Refer to:
1. `ARCHITECTURE.md` - Detailed design and patterns
2. Component previews - See UI examples
3. Use case implementations - See business logic
4. Mock repositories - See data examples
