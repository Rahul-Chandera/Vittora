# Branch protection — required CI (L1)

Gate merges into **`refactoring`** and **`develop`** on a green **CI / build-and-test** check.

## GitHub settings (repo admin)

1. **Settings → Branches → Add branch ruleset** (or classic protection rule).
2. **Branch name pattern:** `refactoring` — repeat for `develop`.
3. Enable **Require status checks to pass before merging**.
4. Search and select status check: **`build-and-test`** (workflow job name under the **CI** workflow).
5. Enable **Require branches to be up to date before merging** (recommended).
6. Save.

## What CI runs

On every push/PR to `refactoring` or `develop`:

- `make build-ios`
- `make build-macos`
- `make test` (macOS unit tests + iOS Simulator UI tests)
- Uploads `.build-ci/*.xcresult` artifacts on completion (pass or fail)

US locale is pinned on the runner (`en_US`); tests remain locale-independent in code.

## Notes

- Requires a macOS runner with **Xcode matching the project deployment target** (currently iOS/macOS 26.x). If GitHub-hosted images lag, use a self-hosted Mac or Xcode Cloud with the same `Makefile` targets.
- UI tests need a current **iOS Simulator** runtime; local hosts with outdated CoreSimulator should rely on CI for `VittoraUITests`.
