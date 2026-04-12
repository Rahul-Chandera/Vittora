# Vittora Code Review Skill

Use this skill to perform comprehensive code reviews of Vittora iOS/macOS app changes. Check across multiple dimensions to ensure code quality and architectural integrity.

## Overview
This skill provides structured checklists for reviewing code changes against Vittora's architecture, Swift 6 compliance, SwiftUI best practices, performance requirements, and security standards.

## How to Use
- Point to changed files or branches to review
- Follow the checklist sections below
- Provide feedback with specific file references and line numbers
- Suggest improvements grounded in the 14 architecture rules and naming conventions

---

## Architecture Compliance Checklist

### Layer Dependencies
- [ ] Presentation layer only imports Application and Foundation layers
- [ ] Application layer only imports Domain and Foundation layers
- [ ] Domain layer only imports Foundation layer
- [ ] Infrastructure layer only imports Foundation and Domain layers
- [ ] No circular dependencies between layers
- [ ] No cross-feature imports without going through Application layer contracts

### @Observable Usage
- [ ] All ViewModels use @Observable (not @StateObject or ObservedObject)
- [ ] No @Published properties (use direct properties with @Observable)
- [ ] Derived values are computed properties, not stored properties
- [ ] State mutations are clear and traceable

### Repository Pattern
- [ ] All data access goes through repositories
- [ ] Repositories defined as protocols in Domain or Application
- [ ] Repository implementations in Infrastructure or Application
- [ ] No direct SwiftData access from ViewModels or Views

### Dependency Injection
- [ ] All dependencies passed through initializers
- [ ] No ServiceLocator or global singletons
- [ ] Mock implementations available for testing
- [ ] Dependencies clearly documented in initializers

### Feature Module Structure
- [ ] Features in `Sources/Features/[FeatureName]/`
- [ ] Each feature has self-contained Presentation/Application/Domain
- [ ] No cross-feature imports at same level
- [ ] Feature exports public interface only

---

## Swift 6 Compliance Checklist

### Concurrency
- [ ] All async code uses async/await (no callbacks or completion handlers)
- [ ] No @escaping closures for new code
- [ ] Proper use of Task and TaskGroup for concurrent operations
- [ ] await calls are awaited, not fire-and-forget

### Sendable Conformance
- [ ] All types crossing async boundaries conform to Sendable
- [ ] Value types used for Sendable data when possible
- [ ] Actors used for mutable shared state
- [ ] No non-Sendable types in Task parameters

### Actor Isolation
- [ ] Proper nonisolated keyword usage where appropriate
- [ ] MainActor applied to UI code and ViewModels
- [ ] No data races possible with current isolation model
- [ ] Actor-isolated properties properly synchronized

### Strict Concurrency
- [ ] Compiler warnings at strict level addressed
- [ ] No #unchecked Sendable without documented justification
- [ ] Import statements use complete syntax (not wildcard where Sendable matters)

---

## SwiftUI Best Practices Checklist

### View Hierarchy
- [ ] Views are small and focused (under 200 lines)
- [ ] Complex views extracted into separate files
- [ ] Proper use of @ViewBuilder for computed properties
- [ ] View state managed in ViewModels, not Views

### State Management
- [ ] @State only for local UI state (animation, keyboard focus)
- [ ] @Environment for cross-hierarchy values
- [ ] Observable ViewModels for business state
- [ ] No binding to non-simple types

### Performance
- [ ] No unnecessary view recreations (.id modifier where needed)
- [ ] List views use ForEach with explicit ids
- [ ] Heavy computations in ViewModels, not Views
- [ ] Images loaded asynchronously, not blocking rendering

### Navigation
- [ ] NavigationStack used for routing (not NavigationLink alone)
- [ ] Navigation state observable and persistent
- [ ] Deep linking supported where applicable
- [ ] Back button behavior consistent

---

## Performance Checklist

### List Performance
- [ ] ForEach uses explicit id parameters
- [ ] List views lazy-load when displaying 100+ items
- [ ] Row views are simple and don't recompute on scroll
- [ ] No heavy filtering or sorting in view code

### Query Efficiency
- [ ] SwiftData queries use #Predicate for filtering
- [ ] Queries include .limit() for large datasets
- [ ] Indexes created on frequently queried properties (#Index)
- [ ] No N+1 query patterns in loops

### View Rendering
- [ ] Charts and graphs use efficient data aggregation
- [ ] Animation code uses appropriate CADisplayLink alternatives
- [ ] Complex layouts don't recalculate in every frame
- [ ] Gradient and blur effects have performance impact assessed

### Image & Document Loading
- [ ] Images loaded asynchronously with .task modifier
- [ ] Large PDFs or documents loaded in background
- [ ] Memory caching strategy for frequently accessed media
- [ ] Placeholder/skeleton views shown during load

### Memory Management
- [ ] No memory leaks from circular references
- [ ] Task cancellation properly handled
- [ ] Large data structures cleaned up when not needed
- [ ] Weak references used in closures capturing self where appropriate

### Startup Time
- [ ] Heavy initialization deferred to background
- [ ] Database initialization not blocking app launch
- [ ] Initial data fetches don't delay UI presentation
- [ ] CloudKit sync doesn't block first render

---

## Security Checklist

### Data Handling
- [ ] No sensitive data in logs (even in debug)
- [ ] Passwords never logged, even with redaction promises
- [ ] API keys not embedded in code or visible in logs
- [ ] User tokens securely stored in Keychain

### Encryption
- [ ] Sensitive documents encrypted at rest (AES-GCM)
- [ ] HTTPS only for network requests
- [ ] Certificate pinning for sensitive endpoints
- [ ] Encryption keys not derived from hardcoded values

### Authentication
- [ ] Biometric authentication properly integrated
- [ ] Session tokens have expiration
- [ ] Failed auth attempts don't leak user existence
- [ ] Account lockout after repeated failed attempts

### iCloud & Cloud Data
- [ ] CloudKit queries don't expose sensitive filter criteria
- [ ] Synced data marked as sensitive in CloudKit schema
- [ ] User privacy settings respected for cloud storage
- [ ] Data encrypted before CloudKit sync if sensitive

### Input Validation
- [ ] All user input validated before use
- [ ] String lengths bounded to prevent DOS
- [ ] File upload sizes validated
- [ ] SQL-like injection prevented (n/a for SwiftData but apply principle)

---

## Review Template

```
## Files Reviewed
- [File path]
- [File path]

## Architecture Assessment
✓ Passes / ⚠ Concerns / ✗ Fails

[Specific findings]

## Swift 6 Assessment
✓ Passes / ⚠ Concerns / ✗ Fails

[Specific findings]

## SwiftUI Assessment
✓ Passes / ⚠ Concerns / ✗ Fails

[Specific findings]

## Performance Assessment
✓ Passes / ⚠ Concerns / ✗ Fails

[Specific findings]

## Security Assessment
✓ Passes / ⚠ Concerns / ✗ Fails

[Specific findings]

## Summary
[Overall assessment and action items]

## Blockers
- [If any exist]

## Nice-to-Haves
- [Suggested improvements]
```

---

## Common Issues to Watch For

1. **ViewModels with @Published** - Should use @Observable directly
2. **Completion handlers** - Should use async/await instead
3. **Views doing data fetching** - Should happen in ViewModel with .task
4. **No explicit ids in ForEach** - Can cause rendering bugs
5. **Force unwrapping (!)** - Review and replace with optional handling
6. **Hard-coded strings** - Should use String(localized:)
7. **Sendable non-conformance** - Breaks in strict concurrency
8. **Global singletons** - Use dependency injection instead
9. **Direct SwiftData access** - Should go through repositories
10. **Circular dependencies** - Review layer structure

---

## When to Use This Skill

- Reviewing pull requests before merge
- Assessing code quality of completed features
- Validating architectural changes
- Pre-launch security and performance reviews
- Onboarding code review for new team members

