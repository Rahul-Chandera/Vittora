# VittoraCore

Swift package for Vittora's **offline-first** domain, persistence, security, and sync layers.

Future targets (Widget, Watch, App Intents) will depend on `VittoraCore` instead of the app target.

## Migration phases (Epic J2)

1. **Scaffold** — this package + CI `swift build` (current).
2. **Domain** — move `Domain/Entities`, repository protocols, and use cases; remove UI imports from Core (`AttachDocumentUseCase` thumbnail helpers → app adapter).
3. **Data** — move SwiftData models, mappers, repositories, `ModelContainerConfig`, migration plan; keep CloudKit config in package. **Done** (43 files under `Sources/VittoraCore/Data/`).
4. **Security + Sync** — move keychain, encryption, sync monitor; app-group entitlements for extensions. **Done** (13 files under `Sources/VittoraCore/Security/` and `Sources/VittoraCore/Sync/`).
5. **Wire app** — local package linked from app + test targets; migrated Data/Domain/Security/Sync compile only in `VittoraCore`; app `Core/` retains use cases, infrastructure, and UI adapters. **Done**.

### J2 follow-up (not 100% — merge #12 as partial)

Epic J shipped with **108 files** in `VittoraCore`; app `Vittora/Core/` still holds use cases, infrastructure (tax, OCR, notifications), extensions, and monetization. **`AttachDocumentUseCase` still imports UIKit** for thumbnail generation (app adapter).

**Finish J2 only when a Widget/Watch/App Intents target is real:** move remaining domain use cases into the package, relocate `AttachDocumentUseCase` UIKit helpers to an app-side adapter, and drop `@_exported import VittoraCore` once all dependents import the package explicitly.

## App `Core/` layout (post phase 5)

- **VittoraCore package:** entities, repository protocols, SwiftData layer, security, sync.
- **App `Vittora/Core/`:** domain use cases, tax/OCR/notifications infrastructure, SwiftUI extensions, monetization helpers.
- **App entry:** `VittoraCoreReexport.swift` re-exports the package; feature code may `import VittoraCore` explicitly.

## Constraints

- No third-party dependencies.
- No SwiftUI / UIKit / AppKit in the library target (platform adapters live in the app).
- Preserve offline-first semantics; local store remains authoritative.
