# Vittora Commit & Push Skill

Use this skill to validate code and commit changes following Vittora's conventions. Ensures code quality, tests pass, and commits are properly formatted before pushing.

## Overview
This skill guides the complete commit workflow: building, testing, staging, committing with proper format, and pushing to feature branches.

---

## Pre-Commit Checks

### Build the Project
```bash
# Build for Debug configuration
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  build
```

### Expected Output
```
Build settings from command line:
    ...

Build complete! (0.0s)
```

### Handle Build Errors
If build fails:
1. Review error messages carefully
2. Fix compilation errors in source files
3. Check architecture rule violations
4. Verify imports and dependencies
5. Rebuild and confirm success

**Build Checklist:**
- [ ] No compilation errors
- [ ] No compiler warnings (or documented)
- [ ] All architecture rules followed
- [ ] Swift 6 concurrency strict
- [ ] Code compiles cleanly

---

## Run Tests

### Execute Full Test Suite
```bash
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  test
```

### Expected Output
```
Test Suite 'All tests' started at HH:MM:SS
Test Suite 'VittoraTests.xctest' started at HH:MM:SS
...
Test Case '-[TransactionViewModelTests testLoadTransactions]' passed (0.123 seconds)
...
Executed 342 tests, with 0 failures (0 seconds) in 1.234 seconds
```

### If Tests Fail
Do NOT commit. Follow these steps:

1. **Identify Failed Tests**
```bash
# Run tests and capture output
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  test 2>&1 | tee test-results.txt

# Find failures
grep "FAILED\|error:" test-results.txt
```

2. **Analyze Failure**
   - Check test output for assertion failures
   - Review stack trace
   - Identify if bug is in test or code
   - Reproduce locally in Xcode

3. **Fix the Issue**
   - If code bug: fix implementation
   - If test bug: fix test setup or assertions
   - If environment: fix mock configuration
   - Add missing test data/stubs

4. **Re-run Tests**
```bash
# Run just the failing test
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  -only-testing VittoraTests/TestNameTests/testMethodName \
  test

# Or run full test suite again
xcodebuild \
  -scheme Vittora \
  -configuration Debug \
  -derivedDataPath .build \
  test
```

5. **Verify All Pass**
   - All tests green
   - No ignored or skipped tests
   - Reasonable execution time (<2 minutes)

**Test Checklist:**
- [ ] All tests pass (100% pass rate)
- [ ] No flaky or intermittent failures
- [ ] No timeouts
- [ ] Reasonable performance (< 2 min total)
- [ ] Coverage maintained or improved

---

## Stage Files

### Check Modified Files
```bash
git status
```

### Example Output
```
On branch feature/add-transaction-history
Your branch is ahead of 'origin/feature/add-transaction-history' by 1 commit.

Changes not staged for commit:
  (use "git add <file>..." to stage changes)
        modified:   Sources/Presentation/TransactionList/TransactionListView.swift
        modified:   Sources/Presentation/TransactionList/TransactionListViewModel.swift
        modified:   Tests/Presentation/TransactionListViewModelTests.swift

Untracked files:
  (use "git add <file>..." to include in what will be committed)
        new_utility.swift
```

### Stage Specific Files
```bash
# Stage specific files (preferred over git add .)
git add Sources/Presentation/TransactionList/TransactionListView.swift
git add Sources/Presentation/TransactionList/TransactionListViewModel.swift
git add Tests/Presentation/TransactionListViewModelTests.swift

# Or use interactive staging
git add -i
```

### Verify Staging
```bash
git status
```

Expected output shows staged files:
```
Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        new file:   Tests/Presentation/TransactionListViewModelTests.swift
        modified:   Sources/Presentation/TransactionList/TransactionListView.swift
        modified:   Sources/Presentation/TransactionList/TransactionListViewModel.swift
```

**Staging Checklist:**
- [ ] Only modified/new files staged (not .build, .xcodeproj caches)
- [ ] No debug code or temporary files
- [ ] .gitignore respected
- [ ] All related changes included
- [ ] Unrelated changes unstaged

---

## Commit Message Format

### Conventional Commits Structure
```
type(scope): description

Optional longer explanation (max 72 chars per line).

Co-Authored-By: Author Name <author.email@example.com>
```

### Type Reference
- **feat**: New feature or capability
- **fix**: Bug fix or issue resolution
- **refactor**: Code restructuring without behavior change
- **perf**: Performance improvement
- **test**: Adding or updating tests
- **docs**: Documentation changes
- **chore**: Build, dependency, or configuration changes
- **style**: Code formatting (whitespace, semicolons)

### Scope Reference
Feature, layer, or component being changed:
- Feature names: `auth`, `dashboard`, `transactions`
- Layer names: `persistence`, `network`, `ui`
- Component names: `transaction-list`, `login-form`

### Description Guidelines
- Imperative mood: "add" not "adds" or "added"
- First letter lowercase
- No period at end
- Concise (under 50 characters ideal)

### Examples

**Good Commits:**
```
feat(transactions): add transaction history view with filtering
fix(persistence): correct balance calculation in sync
test(auth): add biometric authentication tests
refactor(foundation): extract date formatting utilities
perf(dashboard): optimize list rendering with lazy loading
docs: update architecture guide with CloudKit patterns
chore: bump minimum iOS version to 18.0
```

**Bad Commits:**
```
Fixed stuff                        # Too vague
feat: Added a new feature          # Grammar
feat(transactionss): add history   # Typo in scope
feat: Add transaction history...   # Too long (>50 chars)
```

### Long Description Example
```
feat(dashboard): add wallet balance chart

Add an interactive bar chart showing monthly balance trends
on the dashboard. Uses SwiftData aggregation to calculate
monthly totals efficiently.

- Added WalletChartView component
- Implemented monthly balance calculations
- Added chart performance tests
- Validated responsive design on iPad

Fixes #234
```

---

## Create Commit

### Single File Commit
```bash
git commit -m "fix(auth): handle biometric lockout gracefully"
```

### Multi-line Commit with Body
```bash
git commit -m "feat(transactions): add export to PDF feature

- Added PDFDocument generation
- Implemented file sharing via UIActivityViewController
- Added date range filtering for export
- Validated PDF generation performance

Closes #456"
```

### With Co-Author
```bash
git commit -m "feat(dashboard): redesign summary cards

Improved visual hierarchy and information density
following design system updates.

Co-Authored-By: Jane Smith <jane.smith@example.com>"
```

### Using heredoc (Recommended)
```bash
git commit -m "$(cat <<'EOF'
feat(persistence): add migration from v1 to v2 schema

- Added TransactionEntity to support detailed history
- Implemented automatic migration on app launch
- Updated repository interfaces
- Added comprehensive migration tests

Tested on: iOS 18.0 simulator
Performance: <500ms migration time
EOF
)"
```

**Commit Checklist:**
- [ ] Message type is correct (feat, fix, etc.)
- [ ] Scope is present and accurate
- [ ] Description in imperative mood
- [ ] Description under 50 characters (ideal)
- [ ] Co-Authored-By included if applicable
- [ ] Body explains "why" not just "what"
- [ ] Issue/PR references included (#123)

---

## Push to Feature Branch

### Get Current Branch
```bash
git branch --show-current
```

Example output:
```
feature/add-transaction-history
```

### Check Remote Status
```bash
git status
```

Example output:
```
On branch feature/add-transaction-history
Your branch is ahead of 'origin/feature/add-transaction-history' by 1 commit.
  (use "git push" to publish your local commits)
```

### Push to Feature Branch
```bash
# First time pushing branch
git push -u origin feature/add-transaction-history

# Subsequent pushes
git push

# Explicit push
git push origin feature/add-transaction-history
```

### Expected Output
```
Enumerating objects: 8, done.
Counting objects: 100% (8/8), done.
Delta compression using up to 8 threads
Compressing objects: 100% (4/4), done.
Writing objects: 100% (4/4), 1.2 KiB | 1.2 MiB/s, done.
Total 4 (delta 2), reused 1 (delta 0), reused 1 (delta 0)
remote: Resolving deltas: 100% (2/2), done.
To github.com:vittora/vittora-ios.git
   abc1234..def5678  feature/add-transaction-history -> feature/add-transaction-history
```

### Push Without Force
```bash
# Normal push (safe)
git push origin feature/add-transaction-history

# ❌ NEVER force push to main/master
# git push --force-with-lease origin feature/add-transaction-history

# ❌ NEVER use --force
# git push --force origin feature/add-transaction-history
```

**Push Checklist:**
- [ ] Correct branch (feature/*, not main/master)
- [ ] All commits have proper messages
- [ ] No .build or cache files included
- [ ] Commit history is clean
- [ ] No force push to shared branches
- [ ] Remote branch created if first time
- [ ] Verification of successful push

---

## Complete Commit Workflow

### Step 1: Build
```bash
cd /path/to/Vittora
xcodebuild -scheme Vittora -configuration Debug -derivedDataPath .build build
```

Status: ✓ Build successful with 0 errors

### Step 2: Test
```bash
xcodebuild -scheme Vittora -configuration Debug -derivedDataPath .build test
```

Status: ✓ All 342 tests passed

### Step 3: Stage Files
```bash
git status
git add Sources/Presentation/TransactionList/TransactionListView.swift
git add Sources/Presentation/TransactionList/TransactionListViewModel.swift
git add Tests/Presentation/TransactionListViewModelTests.swift
git status
```

Status: ✓ 3 files staged

### Step 4: Commit
```bash
git commit -m "feat(transactions): add transaction history view with filtering

Add a comprehensive transaction history screen with support for
filtering by date range, transaction type, and amount. Implements
pagination for efficient rendering of large transaction lists.

- Added TransactionHistoryView and HistoryViewModel
- Implemented #Predicate-based filtering
- Added test coverage for all filter combinations
- Validated list performance with 1000+ items

Closes #234"
```

Status: ✓ Commit created: abc1234

### Step 5: Push
```bash
git push origin feature/add-transaction-history
```

Status: ✓ Pushed to feature/add-transaction-history

### Step 6: Verify
```bash
git log --oneline -5
git status
```

Status: ✓ Local branch matches remote

---

## Commit Troubleshooting

### "Nothing to commit, working tree clean"
Problem: Files not staged
Solution:
```bash
git add <files>
git status # verify staged
git commit -m "message"
```

### "Error: Your branch has diverged"
Problem: Remote branch changed
Solution:
```bash
git pull --rebase origin feature-branch
git push origin feature-branch
```

### "Error: commit failed"
Problem: Pre-commit hook failed
Solution:
```bash
# Check what hook failed
git log -1 # See your commit
# Fix the issue (linting, formatting)
git add <fixed files>
git commit --amend --no-edit
```

### "fatal: refusing to merge unrelated histories"
Problem: Branches have no common ancestor
Solution: Ensure you're on correct branch
```bash
git branch --show-current
git pull origin feature-branch --allow-unrelated-histories
```

---

## Commit Best Practices

### Atomic Commits
Each commit should represent one logical change:
- One feature per commit
- One bug fix per commit
- Tests always together with implementation

### Clear History
```bash
# Good commit sequence
1. feat(auth): add login screen UI
2. feat(auth): implement login service
3. test(auth): add login tests

# Bad commit sequence  
1. feat(auth): add login, update settings, fix bug
2. test: add some tests
```

### Rebase Before Push
```bash
# Ensure you're up-to-date
git fetch origin
git rebase origin/feature-branch
git push origin feature-branch
```

### Link to Issues
```bash
# In commit message
Fixes #234
Closes #456
Related to #789
```

---

## When to Use This Skill

- After completing a feature or fix
- Before creating a pull request
- During code review preparation
- When pushing changes to remote
- Regular development workflow
- Pre-release code verification

## Quick Workflow Command
```bash
# One-line quick commit (after building and testing)
git add <files> && git commit -m "type(scope): description" && git push origin feature-branch
```

## Git Configuration Check
```bash
# Verify your Git identity (for Co-Authored-By)
git config user.name
git config user.email

# Set if needed
git config user.name "Your Name"
git config user.email "your.email@example.com"
```

