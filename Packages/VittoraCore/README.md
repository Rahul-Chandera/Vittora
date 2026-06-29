# VittoraCore

Swift package for Vittora's **offline-first** domain, persistence, security, and sync layers.

Future targets (Widget, Watch, App Intents) will depend on `VittoraCore` instead of the app target.

## Migration phases (Epic J2)

1. **Scaffold** — this package + CI `swift build` (current).
2. **Domain** — move `Domain/Entities`, repository protocols, and use cases; remove UI imports from Core (`AttachDocumentUseCase` thumbnail helpers → app adapter).
3. **Data** — move SwiftData models, mappers, repositories, `ModelContainerConfig`, migration plan; keep CloudKit config in package.
4. **Security + Sync** — move keychain, encryption, sync monitor; app-group entitlements for extensions.
5. **Wire app** — add local package to `Vittora.xcodeproj`, exclude `Vittora/Core` from app target, `import VittoraCore` in Features.

## Constraints

- No third-party dependencies.
- No SwiftUI / UIKit / AppKit in the library target (platform adapters live in the app).
- Preserve offline-first semantics; local store remains authoritative.
