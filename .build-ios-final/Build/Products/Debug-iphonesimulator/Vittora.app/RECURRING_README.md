# Recurring Transactions Feature

## Quick Start

### Adding Recurring Transactions to a View
```swift
import SwiftUI

struct MyView: View {
    var body: some View {
        NavigationStack {
            RecurringListView()
        }
    }
}
```

### Tracking Subscription Costs
```swift
struct SubscriptionView: View {
    var body: some View {
        NavigationStack {
            SubscriptionTrackerView()
        }
    }
}
```

### Viewing Recurring Rule Details
```swift
RecurringDetailView(ruleID: UUID)
```

## Components

### RecurringListView
Main list of all recurring transactions, grouped by frequency.
- Shows monthly/annual spend summary
- Swipe to pause/delete
- Add button for new rules
- Empty state with CTA

### RecurringFormView
Create or edit a recurring transaction.
- Amount validation
- Frequency picker with custom days support
- Optional end date
- Account selection (required)
- Category, payee, note (optional)

### RecurringDetailView
View complete details of a recurring rule.
- Rule information with icon and amount
- Pause/Resume button
- Edit button
- Upcoming dates preview
- Recent generated transactions

### SubscriptionTrackerView
Dashboard showing all active subscriptions and costs.
- Monthly and annual totals
- List of active subscriptions as cards
- Quick cost analysis

## Use Cases

### Fetch Rules
```swift
let fetchUseCase = FetchRecurringRulesUseCase(repository: recurringRepo)
let all = try await fetchUseCase.execute()
let active = try await fetchUseCase.executeActive()
let dueSoon = try await fetchUseCase.executeDueSoon(within: 7)
```

### Create Rule
```swift
let createUseCase = CreateRecurringRuleUseCase(repository: recurringRepo)
try await createUseCase.execute(
    amount: 29.99,
    frequency: .monthly,
    startDate: .now,
    categoryID: categoryID,
    accountID: accountID,
    payeeID: nil,
    note: "Subscription",
    endDate: nil
)
```

### Pause/Resume
```swift
let pauseResumeUseCase = PauseResumeRuleUseCase(repository: recurringRepo)
try await pauseResumeUseCase.execute(id: ruleID)  // Toggle
try await pauseResumeUseCase.pause(id: ruleID)     // Pause
try await pauseResumeUseCase.resume(id: ruleID)    // Resume
```

### Generate Transactions
```swift
let generateUseCase = GenerateRecurringTransactionsUseCase(
    ruleRepository: recurringRepo,
    transactionRepository: transactionRepo,
    accountRepository: accountRepo
)
let count = try await generateUseCase.execute()
```

### Calculate Costs
```swift
let calculateUseCase = CalculateSubscriptionCostUseCase()
let summary = calculateUseCase.execute(rules: activeRules)
print("Monthly: $\(summary.monthlyCost)")
print("Annual: $\(summary.annualCost)")
print("Count: \(summary.ruleCount)")
```

## ViewModels

### RecurringListViewModel
Manages the main recurring transactions list.

**Properties:**
- `rules: [RecurringRuleEntity]`
- `costSummary: SubscriptionCostSummary?`
- `grouped: [(label: String, rules: [RecurringRuleEntity])]` (computed)

**Methods:**
- `loadRules()` - fetch all rules and calculate cost
- `deleteRule(id:)` - delete and reload
- `togglePause(id:)` - toggle active state

### RecurringFormViewModel
Manages create/edit form state.

**Properties:**
- `amount: String`
- `selectedFrequency: RecurrenceFrequency`
- `startDate: Date`
- `endDate: Date?`
- `hasEndDate: Bool`
- `selectedAccountID: UUID?` (required)
- `selectedCategoryID: UUID?`
- `selectedPayeeID: UUID?`
- `note: String`
- `canSave: Bool` (computed)

**Methods:**
- `loadRule(_:)` - pre-populate for editing
- `save()` - create or update
- `reset()` - clear all fields

### SubscriptionSummaryViewModel
Loads and displays subscription summary.

**Properties:**
- `activeRules: [RecurringRuleEntity]`
- `costSummary: SubscriptionCostSummary?`

**Methods:**
- `load()` - fetch active rules and calculate

## Frequency Support

All frequency types are supported:
- **Daily** - Every day
- **Weekly** - Every 7 days
- **Bi-weekly** - Every 14 days
- **Monthly** - Every month
- **Quarterly** - Every 3 months
- **Yearly** - Every 12 months
- **Custom(days)** - Every N days (user-defined)

## Integration with DependencyContainer

The feature automatically uses repositories from the environment:
```swift
@Environment(\.dependencies) var dependencies

// Access repositories
let recurringRepo = dependencies.recurringRuleRepository
let transactionRepo = dependencies.transactionRepository
let accountRepo = dependencies.accountRepository
let categoryRepo = dependencies.categoryRepository
```

## Background Task Scheduling (iOS only)

Register the background task in your app initialization:
```swift
#if os(iOS)
let generateUseCase = GenerateRecurringTransactionsUseCase(
    ruleRepository: recurringRepo,
    transactionRepository: transactionRepo,
    accountRepository: accountRepo
)
BackgroundTaskScheduler.register(
    modelContainer: modelContainer,
    generateUseCase: generateUseCase
)
BackgroundTaskScheduler.scheduleNextRefresh()
#endif
```

The task will:
1. Run every ~4 hours
2. Generate due recurring transactions
3. Update account balances
4. Advance rule dates
5. Reschedule itself

## Styling

All components use the design system:
- **Colors**: VColors (primary, expense, warning, etc.)
- **Typography**: VTypography (title3, callout, caption2, etc.)
- **Spacing**: VSpacing (lg, md, sm, etc.)
- **Corners**: VSpacing.cornerRadius* (MD, SM, LG)

No custom colors or spacing values - keep it consistent!

## Common Patterns

### Loading Rules on View Appear
```swift
.onAppear {
    if viewModel == nil {
        setupViewModel()
    }
    Task {
        await viewModel?.loadRules()
    }
}
```

### Handling Errors
```swift
if let error = viewModel.error {
    VStack {
        HStack {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
            Text(error).font(VTypography.callout)
            Spacer()
        }
        .padding(VSpacing.md)
        .background(Color.red.opacity(0.1))
        .cornerRadius(VSpacing.cornerRadiusMD)
    }
}
```

### Refresh After Action
```swift
func deleteRule(id: UUID) async {
    try await deleteUseCase.execute(id: id)
    await loadRules()  // Reload after action
}
```

## Testing Notes

When writing tests:
1. Mock RecurringRuleRepository
2. Mock TransactionRepository
3. Mock AccountRepository
4. Test each use case independently
5. Test frequency advancement logic thoroughly
6. Test cost calculation for each frequency type
7. Test form validation
8. Test swipe actions on List

## Architecture Notes

- All use cases are `struct Sendable` (value types)
- All ViewModels are `@Observable @MainActor final class`
- No ObservableObject or @Published anywhere
- Error handling via throws and try/catch
- Date arithmetic uses Calendar for accuracy
- All repositories injected via dependency injection
