# Budgets Feature (PB2) - Architecture Documentation

## Overview
Complete implementation of the Budgets feature module for Vittora iOS/macOS app, following established architecture patterns and design tokens.

## Architecture Compliance

### Swift 6 & Modern SwiftUI
- ✅ All structs marked as `Sendable` for use cases
- ✅ ViewModels: `@Observable @MainActor final class` (NO ObservableObject/Combine)
- ✅ Cross-platform support with `#if os(iOS)` conditionals
- ✅ `Color(hex:)` always used with fallback `?? .blue`
- ✅ `.opacity()` applied as view modifier, not in fill()

### Repository Pattern
All use cases depend on protocol-based repositories from DependencyContainer:
- `budgetRepository: (any BudgetRepository)?`
- `categoryRepository: (any CategoryRepository)?`
- `transactionRepository: (any TransactionRepository)?`

### Design Tokens Used
- **VColors**: primary, safe, warning, danger, background, text levels
- **VTypography**: title2, headline, body, caption variants, amount fonts
- **VSpacing**: sm, md, lg, xl, padding, corner radii
- **VIcons**: standard system icons via SF Symbols

### Components
- **VCard**: Container with shadow and corner radius
- **VProgressBar**: Animated progress with semantic coloring
- **VAmountText**: Currency formatting with type-based coloring
- **VEmptyState**: Empty state with icon and action button
- **Custom**: BudgetCardView, BudgetProgressRing, DailySpendChart

## Directory Structure

```
Features/Budgets/
├── BudgetsFeature.swift          # Main entry point
├── ViewModels/
│   ├── BudgetListViewModel.swift
│   ├── BudgetDetailViewModel.swift
│   └── BudgetFormViewModel.swift
├── Views/
│   ├── BudgetListView.swift
│   ├── BudgetDetailView.swift
│   └── BudgetFormView.swift
├── Components/
│   ├── BudgetCardView.swift
│   ├── BudgetProgressRing.swift
│   ├── DailySpendChart.swift
│   ├── PeriodSelectorView.swift
│   └── BudgetOverviewCard.swift
└── Mocks/
    ├── MockBudgetRepository.swift
    ├── MockCategoryRepository.swift
    └── MockTransactionRepository.swift

Core/Domain/UseCases/
├── FetchBudgetsUseCase.swift
├── CreateBudgetUseCase.swift
├── UpdateBudgetUseCase.swift
├── DeleteBudgetUseCase.swift
├── CalculateBudgetProgressUseCase.swift (→ BudgetProgress)
├── CheckBudgetThresholdUseCase.swift
├── RolloverBudgetUseCase.swift
└── CopyBudgetTemplateUseCase.swift
```

## Use Cases

### FetchBudgetsUseCase
- `execute()` → Fetches active budgets with computed spent
- `executeAll()` → Fetches all budgets (including past)
- Private helper: Calculates spent as sum of expenses in budget's category for its current period
- Uses `BudgetPeriod.dateRange(startingFrom:)` to compute period bounds

### CreateBudgetUseCase
- Validates: amount > 0
- Prevents: duplicate active budgets for category+period
- Error: `VittoraError.validationFailed(...)`

### UpdateBudgetUseCase
- Simple wrapper with amount validation

### DeleteBudgetUseCase
- Deletes by ID

### CalculateBudgetProgressUseCase
- Input: BudgetEntity
- Output: `BudgetProgress` struct
  - `percentage: Double` (0.0 to 1.0+)
  - `daysRemaining: Int`
  - `projectedSpend: Decimal` (daily rate × remaining days)
  - `statusColor: String` ("safe"/"warning"/"danger")
- Thresholds: danger ≥90%, warning ≥75%, safe <75%

### CheckBudgetThresholdUseCase
- Returns budgets at ≥50% progress
- Caller handles notifications

### RolloverBudgetUseCase
- Creates new budget for next period
- Amount = original.amount + (unused if rollover=true) else original.amount

### CopyBudgetTemplateUseCase
- Copies budgets from one period to another with matching period type
- Resets spent to 0

## ViewModels

### BudgetListViewModel
- **State**:
  - `budgets: [BudgetEntity]`
  - `budgetProgress: [UUID: BudgetProgress]`
  - `overallSpent/Spent: Decimal`
  - `selectedPeriod: BudgetPeriod` (filterable)
  - `isLoading`, `error: String?`
- **Computed**:
  - `overallProgress: Double` (safe div-by-zero handling)
- **Methods**:
  - `loadBudgets()` async
  - `deleteBudget(id:) async`

### BudgetDetailViewModel
- **State**:
  - `budget: BudgetEntity?`
  - `progress: BudgetProgress?`
  - `category: CategoryEntity?`
  - `recentTransactions: [TransactionEntity]`
  - `isLoading`, `error: String?`
- **Methods**:
  - `loadBudget(id:) async` → calculates spent, fetches category, loads recent 5 transactions

### BudgetFormViewModel
- **State**:
  - `amount: String` (decimal input)
  - `selectedPeriod: BudgetPeriod`
  - `selectedCategoryID: UUID?`
  - `rollover: Bool`
  - `startDate: Date`
  - `isEditing: Bool`, `editingID: UUID?`
  - `error: String?`
- **Computed**:
  - `canSave: Bool` → amount > 0
- **Methods**:
  - `loadBudget(_ entity:)` → populates form for editing
  - `save() async throws` → create or update
  - `reset()` → clears form

## Views

### BudgetListView
- **Navigation**: `NavigationStack` with `NavigationDestination`
- **Content**:
  - `BudgetOverviewCard` → total budget/spent/remaining
  - `PeriodSelectorView` → filter by period
  - List of `BudgetCardView` for each budget
  - Swipe-to-delete action
- **Toolbar**: "+" button opens sheet with `BudgetFormView`
- **Empty State**: `VEmptyState` when no budgets
- **List Style**:
  - iOS: `.insetGrouped`
  - macOS: `.inset`

### BudgetDetailView
- **Navigation**: `NavigationStack` for edit flow
- **Content**:
  - `BudgetProgressRing` (large, centered)
  - Category name + period
  - Amount details card (budget/spent/remaining)
  - Period info card
  - `DailySpendChart` (if transactions exist)
  - Recent transactions list (5 most recent)
- **Toolbar**: "✏️" button opens edit sheet

### BudgetFormView
- **Navigation**: Embedded `NavigationStack`
- **Form Sections**:
  1. Amount (decimal input with $ prefix)
  2. Period (PeriodSelectorView)
  3. Category (NavigationLink to CategoryPicker from PA2)
  4. Options (Rollover toggle)
  5. Start Date (DatePicker)
- **Mode**: Create or Edit (auto-detected from `editingBudget` param)
- **Navigation**: CategoryPicker for expense categories only
- **Toolbar**: Cancel / Save buttons

## Components

### BudgetCardView
- **Props**:
  - `budget: BudgetEntity`
  - `progress: BudgetProgress?`
  - `category: CategoryEntity?`
- **Layout**:
  - Category icon circle + name + period
  - `VProgressBar` compact (no labels)
  - Spent / Remaining / Progress text row
  - Status color (safe/warning/danger)

### BudgetProgressRing
- **Props**:
  - `progress: Double` (0.0 to 1.0+)
  - `size: CGFloat`
  - `animated: Bool`
- **Features**:
  - Circular arc with semantic gradient
  - Center percentage text
  - Status label (On Track / Warning / Critical / Over Budget)
  - Responsive color changes

### DailySpendChart
- **Props**:
  - `transactions: [TransactionEntity]`
  - `dailyBudgetAverage: Decimal`
- **Features**:
  - Swift Charts bar chart (X: day, Y: amount)
  - Reference line at daily budget average
  - Color coding: safe/warning/danger based on overspend
  - Empty state with icon

### PeriodSelectorView
- **Binding**: `selectedPeriod: BudgetPeriod`
- **iOS**: Segmented picker
- **macOS**: Horizontal chip row with selection state
- **Cases**: .weekly, .monthly, .quarterly, .yearly

### BudgetOverviewCard
- **Props**:
  - `spent: Decimal`
  - `budget: Decimal`
  - `progress: Double`
- **Layout**:
  - Header: Total Budget + Progress %
  - `VProgressBar` compact
  - Stats: Spent / Remaining (with remaining color coding)
  - Status color by progress threshold

## Navigation

### NavigationDestination Cases
- `.budgetDetail(id: UUID)` → BudgetDetailView
- `.addBudget` → BudgetFormView (sheet)

### Flow
1. BudgetListView (home)
   - Tap "+" → sheet BudgetFormView (create)
   - Tap budget → NavigationLink → BudgetDetailView
2. BudgetDetailView
   - Tap "✏️" → sheet BudgetFormView (edit)
3. BudgetFormView (sheet)
   - Category navigation (NavigationLink to CategoryPicker)

## Error Handling

### VittoraError Usage
- `.validationFailed(String)` ← Amount invalid, duplicate budget
- `.notFound(String)` ← Budget/category not found during rollover
- All use cases throw on validation failure
- ViewModels catch and display in `error: String?` property

## Testing & Mocks

### Mock Repositories
- `MockBudgetRepository` → Returns sample budgets
- `MockCategoryRepository` → Returns expense + income categories
- `MockTransactionRepository` → Returns sample transactions

### Preview Support
- All components have `#Preview` blocks
- Use mock repositories in previews
- Full view previews with mock dependencies

## Key Implementation Details

### Date Range Calculation
```swift
BudgetPeriod.dateRange(startingFrom: Date) -> ClosedRange<Date>
```
- Weekly: +6 days
- Monthly: +1 month -1 second
- Quarterly: +3 months -1 second
- Yearly: +1 year -1 second

### Spent Calculation
```
TransactionFilter(
    dateRange: budget.period.dateRange(startingFrom: startDate),
    types: Set([.expense]),
    categoryIDs: budget.categoryID.map { Set([$0]) }
)
transactions.reduce(0) { $0 + $1.amount }
```

### Cross-Platform Styling
```swift
#if os(iOS)
.listStyle(.insetGrouped)
#else
.listStyle(.inset)
#endif
```

### Color from Hex
```swift
Color(hex: category.colorHex) ?? .blue
```
Always provides fallback.

## Dependencies

### External
- SwiftUI (iOS 17+, macOS 14+)
- SwiftData (existing)
- Charts (for DailySpendChart)

### Internal
- Core entities (BudgetEntity, CategoryEntity, TransactionEntity, etc.)
- Repository protocols (BudgetRepository, CategoryRepository, TransactionRepository)
- Design system (VColors, VTypography, VSpacing, VIcons, VCard, VProgressBar, VAmountText, VEmptyState)
- Extensions (Color+Hex, Date+Formatting, ConditionalModifier)

## Future Enhancements

1. **Notifications**: CheckBudgetThresholdUseCase → Local notifications
2. **Recurring Budgets**: Auto-create budgets on schedule
3. **Multi-Currency**: Support different currencies per budget
4. **Budget Insights**: Analytics on spending patterns
5. **Categories by Period**: Different budget limits per category per period
6. **Excel Export**: Budget history export

## Validation Checklist

- ✅ Sendable structs for use cases
- ✅ @Observable @MainActor ViewModels (no Combine)
- ✅ Cross-platform list styles
- ✅ Color hex with fallbacks
- ✅ Opacity as view modifier
- ✅ VColors, VTypography, VSpacing, VIcons used
- ✅ VCard, VProgressBar, VAmountText components used
- ✅ NavigationDestination for routing
- ✅ DependencyContainer integration
- ✅ Error handling with VittoraError
- ✅ Comprehensive previews
- ✅ Mock repositories for testing
- ✅ Consistent naming conventions
- ✅ Documentation for each module
