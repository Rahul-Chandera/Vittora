# VittoraCore

Swift package for Vittora's **offline-first** domain, persistence, security, and sync layers.

Future targets (Widget, Watch, App Intents) will depend on `VittoraCore` instead of the app target.

## Migration phases (Epic J2)

1. **Scaffold** — this package + CI `swift build` (current).
2. **Domain** — move `Domain/Entities`, repository protocols, and use cases; remove UI imports from Core (`AttachDocumentUseCase` thumbnail helpers → app adapter).
3. **Data** — move SwiftData models, mappers, repositories, `ModelContainerConfig`, migration plan; keep CloudKit config in package. **Done** (43 files under `Sources/VittoraCore/Data/`).
4. **Security + Sync** — move keychain, encryption, sync monitor; app-group entitlements for extensions. **Done** (13 files under `Sources/VittoraCore/Security/` and `Sources/VittoraCore/Sync/`).
5. **Wire app** — local package linked from app + test targets; migrated Data/Domain/Security/Sync compile only in `VittoraCore`; app `Core/` retains use cases, infrastructure, and UI adapters. **Done**.

## App `Core/` layout (post phase 5)

- **VittoraCore package:** entities, repository protocols, SwiftData layer, security, sync.
- **App `Vittora/Core/`:** domain use cases, tax/OCR/notifications infrastructure, SwiftUI extensions, monetization helpers.
- **App entry:** `VittoraCoreReexport.swift` re-exports the package; feature code may `import VittoraCore` explicitly.

## Constraints

- No third-party dependencies.
- No SwiftUI / UIKit / AppKit in the library target (platform adapters live in the app).
- Preserve offline-first semantics; local store remains authoritative.
