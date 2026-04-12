# Vittora Architecture Validator Skill

Use this skill to validate architectural integrity of Vittora codebase. Ensures layer separation, proper module structure, and Clean Architecture compliance.

## Overview
This skill checks that the codebase maintains proper separation of concerns, follows the five-layer architecture, and prevents architectural degradation.

---

## Layer Dependencies Validation

### Allowed Dependencies
```
Presentation → Application → Domain ↖
              ↘ Infrastructure → Domain
Foundation (accessible from all)
```

### Validation Checklist

#### Presentation Layer
- [ ] Only imports from Application layer (for use cases, repositories)
- [ ] No direct Domain imports
- [ ] No Infrastructure imports except for types passed from Application
- [ ] Views and ViewModels only deal with UI state
- [ ] All business logic delegated to ViewModels
- [ ] ViewModels use @Observable pattern

#### Application Layer
- [ ] Only imports Domain and Foundation
- [ ] Implements repositories defined in Domain
- [ ] Coordinates use cases and repositories
- [ ] No UI-specific code (no SwiftUI imports except for types)
- [ ] No Infrastructure imports except protocol implementations

#### Domain Layer
- [ ] Only imports Foundation
- [ ] Pure business logic with no Apple framework dependencies (except stdlib)
- [ ] Protocol definitions for repositories
- [ ] Entity and value object definitions
- [ ] Use case interfaces and implementations
- [ ] Independent and testable without other layers

#### Infrastructure Layer
- [ ] Only imports Domain and Foundation
- [ ] Concrete implementations of Domain protocols
- [ ] SwiftData models and migrations
- [ ] CloudKit configuration
- [ ] Network request handling
- [ ] No presentation code

#### Foundation Layer
- [ ] Pure utilities and extensions
- [ ] No business logic
- [ ] No Apple framework specific code except stdlib
- [ ] Reusable across all layers

### Import Validation Commands
```bash
# Find invalid imports in Presentation
grep -r "import Infrastructure" Sources/Presentation/

# Find invalid imports in Application
grep -r "import Presentation" Sources/Application/
grep -r "import Infrastructure" Sources/Application/*.swift

# Find invalid imports in Domain
grep -r "import Presentation\|import Application\|import Infrastructure" Sources/Domain/

# Check for circular dependencies
grep -r "import.*" Sources/ | awk -F: '{print $1}' | sort | uniq -d
```

---

## Folder Structure Validation

### Required Directories
```
Sources/
├── Foundation/
│   ├── Extensions/
│   ├── Utilities/
│   └── Types/
├── Domain/
│   ├── Entities/
│   ├── Protocols/
│   ├── UseCases/
│   └── Errors/
├── Application/
│   ├── Repositories/
│   ├── UseCases/
│   └── Coordinators/
├── Infrastructure/
│   ├── Database/
│   │   ├── Models/
│   │   ├── Migrations/
│   │   └── Queries/
│   ├── Networking/
│   ├── CloudKit/
│   └── Persistence/
├── Presentation/
│   ├── Components/
│   ├── Screens/
│   ├── Features/
│   │   ├── [FeatureName]/
│   │   │   ├── Views/
│   │   │   └── ViewModels/
│   └── Shared/
│       ├── DesignSystem/
│       ├── Navigation/
│       └── Utilities/
└── App/
    └── VittoraApp.swift

Tests/
├── Foundation/
├── Domain/
├── Application/
├── Infrastructure/
├── Presentation/
└── [Feature]Tests/
```

### Feature Module Structure
Each feature under `Sources/Features/[FeatureName]/` should have:
```
Features/[FeatureName]/
├── Domain/
│   ├── Entities/
│   ├── Protocols/
│   └── UseCases/
├── Application/
│   └── Repositories/
├── Presentation/
│   ├── Views/
│   └── ViewModels/
└── Tests/
    └── [Feature]Tests.swift
```

### Validation Checklist
- [ ] All source files in Sources/ organized by layer
- [ ] No files directly in Sources/
- [ ] Each feature self-contained in Features/[FeatureName]/
- [ ] Tests mirror source structure
- [ ] Infrastructure models under Database/Models/
- [ ] Views organized by feature, not by type
- [ ] ViewModels co-located with Views
- [ ] Shared components in Presentation/Components/
- [ ] Design system in Presentation/DesignSystem/

---

## Model Integrity Validation

### SwiftData Models
- [ ] All persistent models are @Model classes
- [ ] Models in Infrastructure/Database/Models/
- [ ] Models use #Unique for unique properties
- [ ] Models use #Index on frequently queried properties
- [ ] Timestamp properties for created_at and updated_at
- [ ] No optional types for required data
- [ ] Relationships properly declared with @Relationship

### Domain Entities
- [ ] Domain entities are value types or protocols
- [ ] No @Model decorator on Domain entities
- [ ] Domain entities independent of persistence
- [ ] Mapping layer between Domain and Infrastructure models

### Entity Relationships
- [ ] @Relationship properly scoped (deleteRule where applicable)
- [ ] Inverse relationships defined
- [ ] No circular reference issues
- [ ] Cascade deletes specified where needed

### Validation Checklist
- [ ] Find all @Model classes: `grep -r "@Model" Sources/`
- [ ] All @Model in Infrastructure/Database/Models/: Verify import paths
- [ ] Check timestamp presence: `grep -r "createdAt\|updatedAt" Sources/Infrastructure/`
- [ ] Verify @Relationship usage: `grep -r "@Relationship" Sources/`
- [ ] Check for orphaned models: Review unreferenced @Model classes

---

## Test Coverage Validation

### Test Structure
- [ ] Tests mirror source structure exactly
- [ ] Test file names: `[TypeUnderTest]Tests.swift`
- [ ] One @Suite per test file
- [ ] Tests use Swift Testing framework (@Test, #expect)

### Test Organization
- [ ] Domain logic tested without infrastructure
- [ ] Repositories tested with mock data sources
- [ ] ViewModels tested with mock repositories
- [ ] Views tested with mock ViewModels
- [ ] Integration tests separate from unit tests

### Coverage Requirements
- [ ] Domain entities have tests (100% coverage)
- [ ] Use cases have tests (80%+ coverage)
- [ ] Repository interfaces tested (100% coverage)
- [ ] ViewModel logic tested (80%+ coverage)
- [ ] Critical business logic fully tested

### Validation Checklist
```bash
# Check test file existence
find Tests/ -name "*Tests.swift" | wc -l

# Verify @Suite usage
grep -r "@Suite" Tests/

# Check Swift Testing format
grep -r "@Test" Tests/

# Find untested code
# (Run with test coverage reports)
xcodebuild -scheme Vittora -configuration Debug test -enableCodeCoverage YES
```

---

## Cross-Feature Import Validation

### Rules
- [ ] No direct imports between feature folders
- [ ] Cross-feature communication through Application layer contracts
- [ ] Shared utilities in Foundation layer
- [ ] Shared UI components in Presentation/Components/

### Validation
```bash
# Find cross-feature imports
grep -r "import.*Features\.\[" Sources/Features/ | grep -v "self"

# Verify all public APIs go through Application
grep -r "public" Sources/Features/*/Domain/ | head -20

# Check for indirect feature coupling
grep -r "enum.*Case" Sources/Features/*/Application/
```

### Allowed Patterns
- Feature imports Foundation (utility code)
- Feature imports shared Presentation.Components
- Feature imports shared Presentation.DesignSystem
- Features coordinate through Application.Coordinators

---

## Architecture Violation Detection

### Common Violations

**Violation 1: Presentation imports Infrastructure**
```swift
// ❌ WRONG
import Presentation
import Infrastructure // Invalid

class UserViewModel {
    let database: SwiftDataDatabase // Direct DB access
}
```

**Violation 2: Domain has Side Effects**
```swift
// ❌ WRONG
// Domain/UseCases/LoginUseCase.swift
func login() {
    print("Logging in...") // Logging is side effect
    UserDefaults.standard.set(true, forKey: "isLoggedIn") // Storage side effect
}
```

**Violation 3: Skipping Repository Pattern**
```swift
// ❌ WRONG
class UserViewModel {
    @Query var users: [UserEntity] // Direct SwiftData access
}
```

**Violation 4: Cross-Feature Direct Import**
```swift
// ❌ WRONG in Features/Dashboard/
import Features.Analytics // Direct cross-feature import
```

### Validation Script
```bash
#!/bin/bash
# Check for architecture violations

echo "=== Checking Layer Dependencies ==="
echo "Presentation importing Infrastructure:"
grep -r "import Infrastructure" Sources/Presentation/ && echo "VIOLATION" || echo "OK"

echo "Application importing Presentation:"
grep -r "import Presentation" Sources/Application/ && echo "VIOLATION" || echo "OK"

echo "Domain importing Infrastructure/Application:"
grep -r "import Infrastructure\|import Application" Sources/Domain/ && echo "VIOLATION" || echo "OK"

echo "=== Checking SwiftData Access ==="
echo "Direct SwiftData in Presentation:"
grep -r "@Query\|@Environment(\.modelContext)" Sources/Presentation/ && echo "VIOLATION" || echo "OK"

echo "=== Checking Feature Isolation ==="
echo "Cross-feature imports:"
grep -r "import Features\." Sources/Features/*/ | grep -v "self" && echo "POTENTIAL VIOLATION" || echo "OK"
```

---

## Architectural Debt Assessment

### Metrics to Track
1. **Layer Violation Count**: Direct rule violations
2. **Cross-Feature Coupling**: Inappropriate dependencies
3. **Test Coverage**: Percentage of code with tests
4. **Code Duplication**: Repeated logic across layers
5. **Complex Classes**: Files exceeding 300 lines

### Thresholds
- ✓ Excellent: 0 violations, 0 cross-feature couplings, 80%+ coverage
- ⚠ Good: 0-2 violations (with clear mitigation plan), 70%+ coverage
- ✗ Poor: 3+ violations, high cross-feature coupling, <70% coverage

---

## When to Use This Skill

- After major refactoring efforts
- During code review for architectural changes
- Before release to verify integrity
- When onboarding developers
- During architectural design reviews
- To identify technical debt hotspots
- Before planning next feature implementation

## Quick Validation Commands

```bash
# Full architecture audit
swift build 2>&1 | grep -i "error\|warning" | head -20

# Check imports
find Sources -name "*.swift" -exec grep -l "import" {} \;

# Count files per layer
echo "Foundation:" && find Sources/Foundation -name "*.swift" | wc -l
echo "Domain:" && find Sources/Domain -name "*.swift" | wc -l
echo "Application:" && find Sources/Application -name "*.swift" | wc -l
echo "Infrastructure:" && find Sources/Infrastructure -name "*.swift" | wc -l
echo "Presentation:" && find Sources/Presentation -name "*.swift" | wc -l

# Run tests
xcodebuild -scheme Vittora test 2>&1 | tail -50
```

