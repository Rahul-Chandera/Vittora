# Branch protection — required CI (L1)

Gate merges into **`develop`**, **`staging`**, and **`main`** on a green **CI / build-and-test** check.

Branch flow: feature branches → `develop` (ongoing development) → `staging` (QA testing) → `main` (release).

## GitHub settings (repo admin)

1. **Settings → Branches → Add branch ruleset** (or classic protection rule).
2. **Branch name pattern:** `develop`, `staging`, and `main` (not all branches — feature branches push freely; checks gate merges into protected branches).
3. Enable **Require status checks to pass before merging**.
4. Search and select status check: **`build-and-test`** (workflow job name under the **CI** workflow).
   `build-and-test` is now an **aggregator**: the real work runs in the `build` job and the
   three parallel `test (…)` matrix legs, and `build-and-test` fails unless all of them pass.
   Keep requiring only `build-and-test` — requiring the individual legs by name would need a
   protection edit every time the matrix changes.
5. Enable **Require branches to be up to date before merging** (recommended).
6. Save.

## What CI runs

On every PR to `develop`, `staging`, or `main` (and direct pushes to `develop`), across
jobs that run **concurrently**:

- job `build` — `make build-ios`, the watch string-catalogue check, `make build-macos`,
  the localization coverage check
- job `test (test-unit)` — `VittoraTests` on iOS Simulator
- job `test (test-ios-ui-core)` — `VittoraUITests` minus `OnboardingFlowUITests`
- job `test (test-ios-ui-onboarding)` — `OnboardingFlowUITests`
- job `build-and-test` — no work of its own; fails unless every job above passed

The same suites run as before; they are only distributed across runners instead of chained
in one job. Each test job uploads its own `.xcresult` artifact on completion (pass or fail).
`make test` still runs all three serially for local use.

US locale is pinned on the runner (`en_US`); tests remain locale-independent in code.

## Notes

- Requires a macOS runner with **Xcode matching the project deployment target** (currently iOS/macOS 26.x). GitHub **`macos-15` hosts macOS 15.x**, so `make test` runs **VittoraTests + VittoraUITests on an iOS 26 Simulator** instead of `platform=macOS`. That drops macOS-host-specific coverage (`#if os(macOS)` file protection, macOS sandbox paths). For full macOS test coverage, add a **self-hosted macOS 26** runner or **Xcode Cloud** running the same `Makefile` targets with `-destination 'platform=macOS'`.
- UI tests need a current **iOS Simulator** runtime; local hosts with outdated CoreSimulator should rely on CI for `VittoraUITests`.
