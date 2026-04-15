# Vittora iOS/macOS App - Architecture & Development Guide

## Project Overview

**App Name:** Vittora

**Bundle ID:** com.vittora.app

**Platforms:** 
- iOS 18.0+
- macOS 15.0+
- iPadOS 18.0+

**Language:** Swift 6 with strict concurrency enabled

**UI Framework:** SwiftUI with @Observable pattern for reactive state management

**Data Layer:** SwiftData with CloudKit auto-sync capabilities

**Architecture Pattern:** MVVM + Clean Architecture layered approach

**Testing Framework:** Swift Testing framework with structured test suites

**Minimum Xcode Version:** 26.0

---

## Architecture Layers

The application is structured in five distinct architectural layers:

### 1. Foundation Layer
- Core utilities, extensions, and base types
- No business logic dependencies
- Pure Swift stdlib and Apple framework utilities
- Location: `Sources/Foundation/`

### 2. Domain Layer
- Business logic, entities, and use cases
- Independent of UI, networking, and persistence details
- Protocol definitions for repository and service contracts
- Location: `Sources/Domain/`

### 3. Application Layer
- Orchestrates domain logic with data sources
- Implements repositories using concrete data providers
- Implements use cases with dependency coordination
- Location: `Sources/Application/`

### 4. Infrastructure Layer
- Concrete implementations of persistence, networking, and external services
- SwiftData models and migrations
- CloudKit sync configuration and handling
- Location: `Sources/Infrastructure/`

### 5. Presentation Layer
- SwiftUI Views and ViewModels
- @Observable state management
- Navigation coordination
- Location: `Sources/Presentation/`

---

## Architecture Rules

All code must follow these 14 mandatory architecture rules:

1. **Layer Isolation**: Each layer can only depend on layers below it. Presentation → Application → Domain ← Infrastructure. Foundation is a utility layer accessible from all.

2. **Observable Pattern**: All ViewModels must use @Observable. No @StateObject or ObservedObject. Derived values use computed properties or filtered/mapped collections.

3. **SwiftData Models**: All persistent entities must be @Model classes in Infrastructure layer. Use #Unique, #Index, and timestamp properties for tracking changes.

4. **Sendable Compliance**: All data types crossing async boundaries must conform to Sendable. Use actors for mutable shared state.

5. **Async/Await Only**: Use async/await exclusively for concurrency. No callbacks, completion handlers, or Combine publishers for new code.

6. **Predicate Filtering**: Use #Predicate macros for all SwiftData queries. No manual filtering in application code.

7. **NavigationStack Routing**: Use NavigationStack with structured navigation data. All navigation state must be observable and persistent.

8. **Platform-Specific Code**: Use #if os(iOS), #if os(macOS) compiler directives. Maintain separate preview/mock implementations per platform when needed.

9. **Localization First**: All user-facing strings must use String(localized:). No hardcoded strings except identifiers and debug output.

10. **No Third-Party Dependencies**: Use only Apple frameworks and standard library. All features must be built with native APIs.

11. **No Force Unwrapping**: Never use ! operator except in test setup code with comments explaining why. Always use optional binding, coalescence, or guard.

12. **Feature Module Structure**: Features organized in self-contained modules under `Sources/Features/[FeatureName]/`. Each feature can have its own Presentation, Application, and Domain subfolders.

13. **Dependency Injection**: All dependencies passed through initializers or environment. No static singletons or global state except for app-level services.

14. **Error Handling**: Use Result types and custom Error enums. Always handle errors explicitly. Never silently fail or use try?.

---

## Naming Conventions

### Files
- **PascalCase** for all Swift files: `UserProfileView.swift`, `LoginViewModel.swift`
- **snake_case** for resource files: `app_icon.pdf`, `localization_strings.strings`

### Types and Identifiers
- **View Suffix**: All SwiftUI views end with `View` → `UserProfileView`, `LoginView`
- **ViewModel Suffix**: All observable state managers end with `ViewModel` → `LoginViewModel`, `ProfileViewModel`
- **Entity Suffix**: All SwiftData models end with `Entity` → `UserEntity`, `TransactionEntity`
- **Repository Suffix**: All repository implementations end with `Repository` → `UserRepository`, `TransactionRepository`
- **UseCase Suffix**: Domain use cases end with `UseCase` → `LoginUseCase`, `FetchTransactionsUseCase`

### Design System
- **V Prefix**: All design tokens use `V` prefix → `VColor.primary`, `VTypography.headline`, `VSpacing.medium`
- **Grouped Structs**: Design system values grouped in namespace structs: `struct VColor`, `struct VTypography`, `struct VSpacing`

### Extensions
- **Extension Naming**: Extensions organized by feature in file `Type+Feature.swift`
  - Example: `View+Navigation.swift`, `String+Formatting.swift`, `Date+Localization.swift`

### Constants and Identifiers
- **Constants**: UPPER_SNAKE_CASE for compile-time constants
- **Identifiers**: "identifier.type.feature" format for string identifiers (navigation, model keys)

---

## Commit Convention

All commits must follow the Conventional Commits format:

**Format:**
```
type(scope): description

Longer explanation if needed (max 72 chars per line).

Co-Authored-By: Your Name <your.email@example.com>
```

**Types:**
- `feat`: New feature or capability
- `fix`: Bug fix or issue resolution
- `refactor`: Code restructuring without feature changes
- `perf`: Performance improvement
- `test`: Adding or updating tests
- `docs`: Documentation changes
- `chore`: Build, dependency, or configuration changes
- `style`: Code style or formatting (whitespace, semicolons, etc.)

**Scope:**
- Feature name or layer: `auth`, `dashboard`, `persistence`, `foundation`

**Examples:**
```
feat(auth): add biometric login with face id support
fix(dashboard): correct balance calculation rounding error
test(persistence): add migration tests for v2 schema
refactor(foundation): extract date formatting utilities
```

All commits must include the `Co-Authored-By` trailer.

---

## Test Conventions

All tests must follow Swift Testing framework patterns:

### Structure
- Mirror source structure: `Tests/[Layer]/[Feature]/`
- Test files named: `[TypeUnderTest]Tests.swift`
- One primary @Suite per test file with @Test methods

### Test Writing
```swift
@Suite("UserViewModel Tests")
struct UserViewModelTests {
    
    @Test("updates user profile on save")
    func updateProfileOnSave() async throws {
        // Arrange
        let viewModel = UserViewModel(repository: MockUserRepository())
        
        // Act
        try await viewModel.saveProfile(name: "John")
        
        // Assert
        #expect(viewModel.isSaved == true)
        #expect(viewModel.user.name == "John")
    }
    
    @Test("handles repository errors gracefully")
    func handlesRepositoryErrors() async throws {
        let repository = MockUserRepository()
        repository.shouldFail = true
        let viewModel = UserViewModel(repository: repository)
        
        try await viewModel.saveProfile(name: "Jane")
        
        #expect(viewModel.error != nil)
    }
}
```

### Best Practices
- Use `#expect` for assertions (not custom matchers)
- Name tests as complete sentences describing behavior
- Organize tests: Arrange → Act → Assert
- Mock all dependencies; never use real services
- Use `@Test` attribute with descriptive labels
- Group related tests in @Suite with meaningful names
- Test async code with async test functions
- Use `throws` in test signature for error cases

---

## Build Commands

### Build for iOS Simulator
```bash
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  -destination 'generic/platform=iOS Simulator' \
  build
```

### Build for macOS
```bash
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  -destination 'generic/platform=macOS' \
  build
```

### Run Tests
```bash
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  test
```

### Build & Test iOS Simulator
```bash
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build test
```

### Clean Build Artifacts
```bash
rm -rf .build
xcodebuild -scheme Vittora clean
```

---

## Key File Locations

- **Project File:** `Vittora.xcodeproj`
- **Source Root:** `Sources/`
- **Tests:** `Tests/`
- **Build Artifacts:** `.build/`
- **Architecture Guide:** `AGENTS.md` (this file)
- **Skills Directory:** `.Codex/skills/`

---

## Quick Reference

| Component | Pattern | Location |
|-----------|---------|----------|
| View | SwiftUI with @Observable ViewModel | `Sources/Presentation/[Feature]/` |
| ViewModel | @Observable class | `Sources/Presentation/[Feature]/` |
| Entity | @Model class with SwiftData | `Sources/Infrastructure/Database/Models/` |
| Repository | Protocol + Implementation | `Sources/Application/Repositories/` |
| UseCase | Business logic orchestrator | `Sources/Domain/UseCases/` |
| Test | Swift Testing @Suite | `Tests/[Layer]/[Feature]/` |

---

## Getting Started

1. Ensure Xcode 26.0+ is installed
2. Verify Swift 6 strict concurrency in build settings
3. Review architecture layers and layer dependencies
4. Follow naming conventions for consistency
5. Use the skills in `.Codex/skills/` for guidance on specific tasks
6. All new features must follow MVVM + Clean Architecture pattern
7. Write tests alongside implementation using Swift Testing
8. Commit using Conventional Commits format with Co-Authored-By trailer

