# Vittora System Map

This map helps agents find the right files quickly.

## App Entry and Composition

- App entry: `Vittora/VittoraApp.swift`
- Root content gating: `Vittora/ContentView.swift`
- Dependency wiring: `Vittora/App/Dependencies/DependencyContainer.swift`
- Model container + migration wiring: `Vittora/Core/Data/Persistence/ModelContainerConfig.swift`, `Vittora/Core/Data/Persistence/VittoraMigrationPlan.swift`

## Navigation

- Primary tab navigation: `Vittora/Navigation/AppTabView.swift`
- iPad/macOS split navigation: `Vittora/Navigation/SidebarNavigation.swift`
- Destination routing: `Vittora/Navigation/NavigationDestinationHandler.swift`

## Security and Privacy

- App lock service: `Vittora/Core/Security/AppLockService.swift`
- Biometrics: `Vittora/Core/Security/BiometricService.swift`
- Keychain: `Vittora/Core/Security/KeychainService.swift`
- Encryption: `Vittora/Core/Security/EncryptionService.swift`
- Security audit log: `Vittora/Core/Security/SecurityAuditLogService.swift`
- App lock UI: `Vittora/Features/Security/AppLockView.swift`
- Privacy manifest: `Vittora/PrivacyInfo.xcprivacy`

## Data and Persistence

- SwiftData models: `Vittora/Core/Data/Models/`
- Repository implementations: `Vittora/Core/Data/Repositories/`
- Mapping layer: `Vittora/Core/Data/Mappers/`
- Data management/reset: `Vittora/Core/Data/Persistence/DataManagementService.swift`
- Export: `Vittora/Core/Data/Persistence/DataExportService.swift`

## Sync

- Sync status model/service: `Vittora/Core/Sync/SyncStatusService.swift`
- CloudKit event monitor: `Vittora/Core/Sync/CloudKitSyncMonitor.swift`
- Conflict semantics: `Vittora/Core/Sync/SyncConflictHandler.swift`
- Integrity checks: `Vittora/Core/Sync/SyncIntegrityValidator.swift`
- UI surfaces: `Vittora/Features/Sync/SyncStatusView.swift`, `Vittora/Features/Sync/DataManagementView.swift`

## Tax

- Domain entities: `Vittora/Core/Domain/Entities/TaxEntity.swift`
- Use cases: `Vittora/Core/Domain/UseCases/EstimateTaxUseCase.swift`, `Vittora/Core/Domain/UseCases/CompareTaxRegimesUseCase.swift`
- Calculators: `Vittora/Core/Infrastructure/Tax/IndiaTaxCalculator.swift`, `Vittora/Core/Infrastructure/Tax/USTaxCalculator.swift`
- Persistence: `Vittora/Core/Data/Repositories/SwiftDataTaxProfileRepository.swift`
- UI state: `Vittora/Features/Tax/ViewModels/TaxProfileFormViewModel.swift`

## Documents and Receipts

- Metadata repo: `Vittora/Core/Data/Repositories/SwiftDataDocumentRepository.swift`
- Secure storage service: `Vittora/Core/Data/Infrastructure/EncryptedDocumentStorageService.swift`
- Delete orchestration: `Vittora/Core/Domain/UseCases/DeleteDocumentUseCase.swift`
- Preview/import/list UI: `Vittora/Features/Documents/Views/`

## Recurring Transactions

- Generation use case: `Vittora/Core/Domain/UseCases/GenerateRecurringTransactionsUseCase.swift`
- Rule repository: `Vittora/Core/Data/Repositories/SwiftDataRecurringRuleRepository.swift`
- Background scheduler: `Vittora/Core/Infrastructure/BackgroundTaskScheduler.swift`
- Feature UI: `Vittora/Features/Recurring/`

## Test Entry Points

- Root tests folder: `VittoraTests/`
- Tax tests: `VittoraTests/Features/Tax/`
- Sync tests: `VittoraTests/Core/Sync/`
- Data/document tests: `VittoraTests/Core/Data/`
- Recurring tests: `VittoraTests/Features/Recurring/`
