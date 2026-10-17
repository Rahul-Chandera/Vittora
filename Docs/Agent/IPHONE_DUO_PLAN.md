# iPhone Duo — UI study for the next release

Study date 2026-10-10. Sources: Apple's [iPhone Duo hub](https://developer.apple.com/iphone-duo/),
[Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo),
[Designing for iPhone Duo (HIG, 2026-09-09)](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo),
the [readiness checklist](https://developer.apple.com/iphone-duo/prepare/) and the
[screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
Code findings are from a grep audit of `Vittora/` on `develop` (4017a8b8). Nothing here has run on an
iPhone Duo simulator yet — that needs Xcode 27.1 (installed: 27.0, which cannot create the device).

## 1. The device, in what matters for layout

- Foldable iPhone (`userInterfaceIdiom == .phone`). **Outer display**: compact width, wider and shorter
  than other iPhones. **Inner display**: large; behaves like a regular-width (iPad-like) environment.
- Poses: closed, open, partially folded ("book"), laid flat, standing on an edge; each can rotate.
  The app moves between displays and **resizes mid-session** as people fold and unfold.
- **Reserved regions**: the outer front camera (always occludes, grows into the Dynamic Island for Live
  Activities); the inner camera (occludes only while active); the **fold** (divides the inner display
  when partially open).
- **Vertical bars**: navigation bar, toolbar and tab bar move to the **side** of the display on the outer
  display, and on the inner display in landscape. Only inner-display portrait keeps horizontal bars.
- Split View multitasking runs on the inner display; each app keeps its bars on its outer edge.

## 2. SDK and tooling

| Build with | Result on iPhone Duo |
|---|---|
| iOS 26 SDK or earlier | Doesn't extend under the status bar and camera |
| **iOS 27 SDK (what 1.8.0 ships with)** | Resizes dynamically. **1.8.0 will already run resizable on Duo** |
| iOS 27.1 SDK | Optimized: full display, vertical toolbars and tab bars |

- Need **Xcode 27.1** (currently RC) for the iPhone Duo simulator and the 27.1 SDK. CI runners need it too.
- Testing: the iPhone Duo simulator (Device Hub poses), the resizable iOS simulator, and iPhone Mirroring
  on macOS 27 resized to extremes.
- Xcode's coding assistant has a skill for this ("get my app ready for iPhone Duo"); `xcrun agent skills
  export` exports it for other agents.

## 3. App Store

- Screenshots: outer **1398 × 2034** (portrait) / 2034 × 1398; inner **2007 × 2853** / 2853 × 2007 px.
- **From April 2027, Duo screenshots are required for any app built with the iOS 27.1 SDK or later.**
  Optional before then. `StoreGalleryUITests` + `capture_screenshots.sh` need an iPhone Duo pass
  (both displays; the inner display wants the iPad-style layout).
- Featuring nomination can state "optimized for iPhone Duo, all poses".

## 4. What the audit found in Vittora

Good news first: none of Apple's red-flag patterns appear: no `UIScreen.main`, no
`UIDevice.current.orientation` / `interfaceOrientation`, no `UIWindow(frame:)`, no hard-coded device
heights, no custom `UITabBar`/`UIToolbar`. The app is SwiftUI with system containers, and iPhone
already supports landscape. The work is concentrated in a few places.

### P0: layout swaps on size class (state loss when folding)

On Duo, horizontal size class flips **every time the device folds or unfolds**. Vittora swaps whole
view trees on it:

| Where | What swaps | Risk on fold/unfold |
|---|---|---|
| `Navigation/AppTabView.swift:16` | Two different `TabView`s: compact (4 tabs + More hub) vs regular (`.sidebarAdaptable`, 9 tabs) | Entire navigation rebuilt: open screens and scroll positions lost, an overflow destination lands on the More root |
| `Navigation/AppTabView.swift:26` + `AppCommandHandling.swift:81` | Quick add: `fullScreenCover` (compact) vs `sheet` (regular) | **An expense being typed is likely dismissed and lost** when the user unfolds mid-entry |
| `Dashboard/Views/DashboardView.swift:105` | Quick actions: cover vs sheet | Same as above |
| `Transactions/Views/TransactionListView.swift:30` | List vs nested `NavigationSplitView` | Selected transaction / pushed detail lost |

HIG: "Keep functionality and the state of elements the same between displays." "Avoid extreme layout
changes as people fold the device."

**Fix direction**
- One root `TabView` with `.sidebarAdaptable` for every width. It already becomes a tab bar in compact
  and a sidebar in regular. Express the iPhone "More" grouping with `TabSection` and tab visibility
  instead of a second `TabView`. Mind the iOS 27 rule already documented in `AppState.swift:338`
  (selection must be a visible tab).
- Present quick add the same way at every width (a sheet; on compact it can use a large detent or
  `.presentationSizing(.page)`), so a size-class change never changes the presentation type.
- Keep the transaction split view mounted at both widths and let `NavigationSplitView` collapse itself.
- Tests: a UI test that opens Add Expense, types an amount, changes size class (iPad Split View or a
  resizable simulator), and asserts the form and amount survive.

### P1: toolbars for vertical presentation

161 `ToolbarItem`s across the app.

- **~60 text-only dialog buttons (32 files)**: Cancel / Save / Done / Add, styled with
  `vDialogConfirmButton` / `vDialogCancelButton`. Apple: "If your item has a title and doesn't have an
  icon, the system doesn't present it vertically", and sheets on the outer display use vertical bars by
  default. Move to semantic roles: `Button(role: .cancel/.close)` and `Button(role: .confirm)`, which carry
  system glyphs, or `Label(title, systemImage:)`. Then check that `VToolbarConfirmButtonStyle`'s padding
  and `fixedSize` still look right in a vertical bar.
- **~20 icon-only items with no title** (add `plus`, edit `pencil`, household `person.2`, rules
  `text.magnifyingglass`): Budgets, Accounts, Categories, Payees, Debt, Savings, Splits, Recurring, Tax,
  Household, Transaction detail. Overflow menus need a title. Use `Label(String(localized:), systemImage:)`.
- **Placement and priority**: Back/Close on top, then the prominent action (`topBarPinnedTrailing`), then
  `visibilityPriority` so "Add" outlives secondary actions. Decide compression per screen. Dashboard,
  Transactions and Reports are navigation-first (keep the tab bar). Add/Edit forms are task-first
  (`ToolbarVerticalCompressionBehavior`: minimize the tab bar).
- `TransactionListView.swift:365` uses `.bottomBar`: confirm it goes vertical cleanly.
- Custom overflow menus (an ellipsis in our own toolbar): fold them into `ToolbarOverflowMenu`.

### P1: floating buttons and side insets

- Dashboard quick-entry FAB, `.overlay(alignment: .bottomTrailing)` at `DashboardView.swift:41`. With bars on
  the trailing side of the outer display, check that it clears the vertical bar and the camera region.
  It may belong in the toolbar on Duo (HIG: put controls in the system bars).
- Paywall purchase footer `safeAreaInset(edge: .bottom)` (`PaywallView.swift:188`): check it on the short
  outer display.

### P1: idiom checks

- `Paywall/PaywallView.swift:41`: `userInterfaceIdiom == .pad` decides the taller sheet. On the Duo inner
  display (idiom `.phone`, regular width) the paywall would get the default form sheet. Decide by space
  (size class or container size), not idiom.
- `AppleWallet/AppleWalletService.swift:84` (`== .phone`) is a capability gate, not layout. Fine, and the
  feature ships dark anyway.

### P2: content layout on the inner display and around the fold

- **Dashboard (regular width)**: verify the two-column layout reads as a natural iPad-like layout on
  the inner display. Keep important numbers off the fold: hero spending card and charts
  (`HeroSpendingCard.swift:123` and `DashboardView.swift:332` use `GeometryReader`).
- **Grids**: HIG prefers an even column count so content splits cleanly at the fold. Tax dashboard uses
  1/2 columns (good). Account colour grid uses 6 (good). Payment method grid uses 3, and category badges
  are adaptive at a 140 pt minimum: check both when folded.
- **Charts and reports** (Cash Flow, Net Worth, 50/30/20, Year in Review): check that bars and labels
  don't sit in the fold. `ReservedRegion` (SwiftUI `GeometryProxy.reservedRegions(kind:)`) is the tool if
  the system doesn't move them.
- **ArrangementView candidates**: Transaction detail + receipt attachment, Budget detail + its
  transactions, Monthly Overview chart + breakdown (split arrangement, horizontal axis only).
- **Background extension**: none of our screens use a full-bleed hero, so `backgroundExtensionEffect` is
  probably unneeded.
- `DocumentThumbnailView.swift:40` `.scaledToFill()` is a thumbnail in a fixed frame. Fine.

### P2: system surfaces

- Live Activities (shopping total, bill countdown): the outer camera region expands into the Dynamic
  Island. Check the compact and minimal presentations on the outer display.
- Widgets (small/medium, Lock Screen accessories): no Duo-specific guidance. Check in the simulator.
- Document scanning uses the system VisionKit camera. The inner camera hides when inactive, so there's
  nothing to change. The camera-direction guidance is for AVFoundation capture apps, which we aren't.

## 5. Suggested order

1. Install Xcode 27.1 RC locally; create iPhone Duo simulators; run 1.8.0's code as-is and record what
   breaks per pose (outer portrait/landscape, inner portrait/landscape, book fold, Split View).
2. **P0 state-loss fixes** plus the size-change UI test. These matter even before we ship a 27.1 build,
   because 1.8.0 (iOS 27 SDK) already resizes on Duo.
3. Switch the project and CI to Xcode 27.1 / iOS 27.1 SDK; then do the P1 toolbar pass across the 32 dialog
   files and the ~20 icon-only items.
4. P1 FAB, paywall and idiom fixes; P2 fold/inner-display polish screen by screen.
5. Duo screenshots in the capture pipeline (required April 2027), plus What's New and store copy.

## 6. Open questions for the owner

- When does iPhone Duo ship to customers? That sets whether the P0 fixes go out as a 1.8.x on the iOS 27
  SDK before the bigger 27.1 release.
- Is the next release iPhone Duo only, or bundled with the 1.8.1 items (Mac invitations copy,
  predictive entry decision, Mint/YNAB import)?
