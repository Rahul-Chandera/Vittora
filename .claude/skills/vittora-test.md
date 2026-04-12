# Vittora Test Runner Skill

Use this skill to build, run, and validate Vittora tests. Diagnose test failures and ensure test quality across the codebase.

## Overview
This skill manages the complete testing workflow: building the test target, running tests, interpreting failures, fixing issues, and validating test quality.

---

## Test Build & Execution

### Build Tests
```bash
# Build tests for iOS Simulator
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build-for-testing

# Build tests for macOS
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  -destination 'generic/platform=macOS' \
  build-for-testing

# Build all tests
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  build-for-testing
```

### Run All Tests
```bash
# Run all tests (default platform)
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  test

# Run with verbose output
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  test \
  -verbose

# Run specific test target
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  -only-testing VittoraTests \
  test

# Run specific test class
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  -only-testing VittoraTests/UserViewModelTests \
  test

# Run specific test method
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  -only-testing VittoraTests/UserViewModelTests/testLoginSuccess \
  test
```

### Run Tests with Code Coverage
```bash
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  test \
  -enableCodeCoverage YES

# Generate coverage report
xcrun llvm-cov report \
  -instr-profile=.build/Intermediates.noindex/Vittora.build/Debug/Vittora.build/default.profdata \
  .build/Release/Vittora
```

---

## Test Execution Checklist

### Pre-Test Steps
- [ ] Clean build artifacts: `rm -rf .build`
- [ ] Verify Xcode version: `xcode-select -p` (should be 26.0+)
- [ ] Check Swift version: `swift --version` (should be 6+)
- [ ] Ensure test targets are defined in xcodeproj
- [ ] Verify test files compile

### During Test Execution
- [ ] Monitor output for PASSED/FAILED indicators
- [ ] Note all failing tests with their descriptions
- [ ] Check for compilation warnings
- [ ] Verify no timeouts or hangs
- [ ] Monitor memory usage for leaks

### Post-Test Steps
- [ ] Count total tests run vs total passed
- [ ] Calculate pass rate percentage
- [ ] Identify failing test suites
- [ ] Note any flaky tests (intermittent failures)
- [ ] Generate coverage report

---

## Test Failure Diagnosis

### Common Failure Patterns

**Pattern 1: Compilation Error**
```
error: expected expression after 'await'
```
**Fix**: Check async/await syntax, ensure methods are async

**Pattern 2: Assertion Failure**
```
#expect(viewModel.isLoading == false) - false
```
**Fix**: Verify expected vs actual state, check test setup

**Pattern 3: Mock Not Configured**
```
error: Call to undefined method mockRepository.fetchUser()
```
**Fix**: Ensure mock has required stubbed methods

**Pattern 4: Timeout**
```
Test took longer than 300 seconds to complete
```
**Fix**: Check for infinite loops, missing cancellation, deadlock in concurrent code

**Pattern 5: SwiftData Initialization**
```
error: Unable to initialize ModelContainer
```
**Fix**: Use in-memory container for tests, not file-based

**Pattern 6: View Rendering**
```
error: Cannot preview this view in this context
```
**Fix**: Ensure proper environment setup, mock dependencies

### Failure Analysis Script
```bash
# Run tests with detailed output
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  test 2>&1 | tee test-output.log

# Extract failures
grep -E "FAILED|error:|failed" test-output.log

# Count results
echo "=== Test Results ==="
PASSED=$(grep -c "Test Case.*PASSED" test-output.log)
FAILED=$(grep -c "Test Case.*FAILED" test-output.log)
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Pass Rate: $(( PASSED * 100 / (PASSED + FAILED) ))%"
```

---

## Test Failure Fixing Workflow

### Step 1: Identify Failure Root Cause
- [ ] Read full error message and stack trace
- [ ] Identify line number and test name
- [ ] Check if test setup or test itself is wrong
- [ ] Verify mocks are properly configured
- [ ] Check for async/await issues

### Step 2: Classify Failure Type
- **Code Bug**: Implementation doesn't match test expectation
- **Test Bug**: Test is incorrect or setup is wrong
- **Environment**: Mock/environment not properly initialized
- **Concurrency**: Async/await or task management issue
- **Flaky**: Test fails intermittently (timing or randomness)

### Step 3: Fix Implementation
```swift
// Example: ViewModel not properly handling async result
// ❌ WRONG
@Test func testDataLoading() {
    let viewModel = UserViewModel(repository: mockRepo)
    viewModel.loadData() // Not awaiting
    #expect(viewModel.data.count > 0) // Fails - data not loaded yet
}

// ✓ CORRECT
@Test func testDataLoading() async throws {
    let viewModel = UserViewModel(repository: mockRepo)
    try await viewModel.loadData()
    #expect(viewModel.data.count > 0)
}
```

### Step 4: Fix Test Setup
```swift
// Example: Mock not configured with test data
// ❌ WRONG
let mockRepo = MockUserRepository()
let viewModel = UserViewModel(repository: mockRepo)
try await viewModel.fetchUser(id: "123")
#expect(viewModel.user != nil) // Fails - mock returns nil

// ✓ CORRECT
let mockRepo = MockUserRepository()
mockRepo.stubbedUser = User(id: "123", name: "John")
let viewModel = UserViewModel(repository: mockRepo)
try await viewModel.fetchUser(id: "123")
#expect(viewModel.user?.name == "John")
```

### Step 5: Verify Fix
```bash
# Run individual test
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  -only-testing VittoraTests/UserViewModelTests/testDataLoading \
  test

# Run full test suite for that file
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  -only-testing VittoraTests/UserViewModelTests \
  test
```

---

## Test Quality Validation

### Quality Checklist

#### Test Structure
- [ ] @Suite with descriptive name: `@Suite("UserViewModel Tests")`
- [ ] One @Suite per test file
- [ ] Clear #expect() assertions (not custom matchers)
- [ ] Arrange → Act → Assert pattern visible
- [ ] No global test state between tests

#### Test Names
- [ ] Test name describes behavior: `func testLoadsDataOnInit()`
- [ ] Names read as sentences: "updates user profile on save"
- [ ] No generic names like `test1()` or `testFails()`
- [ ] Naming matches test content

#### Mocks and Stubs
- [ ] Mocks implement required protocol methods
- [ ] Stubs have sensible defaults
- [ ] Mock state verifiable (optional)
- [ ] No real side effects in mocks
- [ ] Mock methods properly document expected calls

#### Assertions
- [ ] Each test has at least one assertion
- [ ] Assertions match test purpose
- [ ] Use #expect() for conditions
- [ ] Meaningful assertion messages
- [ ] No assertion overload (20+ assertions = separate tests)

#### Async Testing
- [ ] Async test functions marked `async`
- [ ] All awaitable calls are awaited
- [ ] Tests using tasks verify completion
- [ ] Proper error handling with `throws`
- [ ] No arbitrary timeouts or sleeps

#### Error Testing
- [ ] Error cases have dedicated tests
- [ ] Error message content tested
- [ ] Recovery behavior verified
- [ ] Error doesn't break app state

### Test Quality Score

```bash
#!/bin/bash
# Calculate test quality metrics

TOTAL_TESTS=$(grep -r "@Test" Tests/ | wc -l)
ASYNC_TESTS=$(grep -r "func test.*async" Tests/ | wc -l)
EXPECT_COUNT=$(grep -r "#expect" Tests/ | wc -l)

echo "Total Tests: $TOTAL_TESTS"
echo "Async Tests: $ASYNC_TESTS"
echo "Average Assertions per Test: $((EXPECT_COUNT / TOTAL_TESTS))"
echo ""
echo "Quality Metrics:"
echo "- Async Coverage: $((ASYNC_TESTS * 100 / TOTAL_TESTS))%"
echo "- Assertion Density: $(( EXPECT_COUNT / TOTAL_TESTS )) per test"
```

### Target Metrics
- Minimum 1 assertion per test
- Average 2-3 assertions per test
- 30%+ async tests for async code
- <5% flaky tests
- 80%+ code coverage for critical paths

---

## Performance Testing

### Long-Running Operations Test
```swift
@Test("loads 1000 items without blocking")
func testBulkLoadPerformance() async throws {
    let viewModel = DataViewModel(repository: mockRepo)
    mockRepo.stubbedItems = Array(0..<1000).map { _ in Item() }
    
    let startTime = Date()
    try await viewModel.loadItems()
    let duration = Date().timeIntervalSince(startTime)
    
    #expect(duration < 2.0) // Should load in under 2 seconds
    #expect(viewModel.items.count == 1000)
}
```

### Memory Usage Test
```swift
@Test("doesn't leak memory in repeated operations")
func testMemoryLeak() async throws {
    for _ in 0..<100 {
        var viewModel: UserViewModel? = UserViewModel(repository: mockRepo)
        try await viewModel?.fetchUser(id: "123")
        viewModel = nil // Should be deallocated
    }
    // Monitor with Instruments if needed
}
```

---

## Test Organization

### Test File Structure
```swift
@Suite("UserViewModel Tests")
struct UserViewModelTests {
    
    // Setup
    var mockRepository: MockUserRepository!
    
    init() {
        mockRepository = MockUserRepository()
    }
    
    // Happy path tests
    @Test("loads user data on init")
    func testLoadUserOnInit() async throws { }
    
    @Test("updates UI when data changes")
    func testUIUpdateOnDataChange() { }
    
    // Error handling tests
    @Test("shows error message when fetch fails")
    func testShowsErrorOnFetchFailure() async throws { }
    
    @Test("retries on transient error")
    func testRetryOnTransientError() async throws { }
    
    // Edge cases
    @Test("handles nil user gracefully")
    func testHandlesNilUser() { }
    
    @Test("works with concurrent requests")
    func testConcurrentRequests() async throws { }
}
```

---

## Test Execution Report Format

### Standard Report
```
=== VITTORA TEST EXECUTION REPORT ===
Date: [ISO 8601 timestamp]
Configuration: Debug
Destination: iOS Simulator, iPhone 16 Pro

## Summary
Total Tests: 342
Passed: 340
Failed: 2
Skipped: 0
Pass Rate: 99.4%

## Failed Tests
1. LoginViewModelTests.testInvalidEmailRejected
   Error: #expect(viewModel.isValidEmail == false) - false
   
2. SettingsViewModelTests.testSaveSettings
   Error: Timeout after 30 seconds
   Suspected Issue: Deadlock in concurrent save

## Coverage
Overall: 82.3%
Critical Paths: 95.2%
Untested Files: 3
- SharedAuthenticationService.swift (utility)
- DebugLogging.swift (development-only)
- MockFactory.swift (test helper)

## Performance
Average Test Duration: 245ms
Longest Test: DataMigrationTests.testLargeDataMigration (8.2s)
Total Time: 1m 24s

## Recommendations
1. Fix async/await in SettingsViewModel
2. Add timeout handling to testSaveSettings
3. Add tests for SharedAuthenticationService
4. Consider splitting large migration test

## Sign-off
[ ] All tests passing
[ ] Coverage above 80%
[ ] No flaky tests detected
[ ] Performance acceptable
```

---

## When to Use This Skill

- Running tests during development
- Validating changes before commit
- Debugging test failures
- Assessing test coverage
- Performance regression detection
- Pre-release test validation
- CI/CD integration troubleshooting

## Quick Commands Reference

```bash
# Build and test (one command)
xcodebuild -scheme Vittora -configuration Debug -derivedDataPath .build test

# Run specific test suite
xcodebuild -scheme Vittora -configuration Debug -derivedDataPath .build \
  -only-testing VittoraTests/UserViewModelTests test

# Run with coverage
xcodebuild -scheme Vittora -configuration Debug -derivedDataPath .build \
  test -enableCodeCoverage YES

# Clean and rebuild
rm -rf .build && xcodebuild -scheme Vittora clean && xcodebuild -scheme Vittora test
```

