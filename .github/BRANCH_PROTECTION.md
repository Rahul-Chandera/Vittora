# Branch protection — required CI (L1)

Gate merges into **`refactoring`** and **`develop`** on a green **CI / build-and-test** check.

## GitHub settings (repo admin)

1. **Settings → Branches → Add branch ruleset** (or classic protection rule).
2. **Branch name pattern:** `refactoring` and `develop` (not all branches — feature branches push freely; checks gate merges into protected branches).
3. Enable **Require status checks to pass before merging**.
4. Search and select status check: **`build-and-test`** (workflow job name under the **CI** workflow).
5. Enable **Require branches to be up to date before merging** (recommended).
6. Save.

## What CI runs

On every push/PR to `refactoring` or `develop`:

- `make build-ios`
- `make build-macos`
- `make test` (VittoraTests + full VittoraUITests on iOS Simulator — onboarding runs in an isolated first pass, then the remaining UI suite; GitHub `macos-15` has no macOS 26 host)
- Uploads `.build-ci/*.xcresult` artifacts on completion (pass or fail)

US locale is pinned on the runner (`en_US`); tests remain locale-independent in code.

## Notes

- Requires a macOS runner with **Xcode matching the project deployment target** (currently iOS/macOS 26.x). GitHub **`macos-15` hosts macOS 15.x**, so `make test` runs **VittoraTests + VittoraUITests on an iOS 26 Simulator** instead of `platform=macOS`. That drops macOS-host-specific coverage (`#if os(macOS)` file protection, macOS sandbox paths). For full macOS test coverage, add a **self-hosted macOS 26** runner or **Xcode Cloud** running the same `Makefile` targets with `-destination 'platform=macOS'`.
- UI tests need a current **iOS Simulator** runtime; local hosts with outdated CoreSimulator should rely on CI for `VittoraUITests`.
