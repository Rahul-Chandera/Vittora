# App Store Metadata — macOS platform tab, es-US (Spanish)

**Refreshed 2026-10-06 for 1.8.0 (build 13).** Promotional text and Description now cover the 1.8.0 feature set: tax estimates for five countries, household sharing, sinking funds, sub-categories, the financial health score, spending outlook and what-if, net worth over time, the unusual-spending and budget insights, on-device category suggestions and the Apple Intelligence month summary. AI is named only for those last two ("on supported devices"); the health score, outlook and insights are rules-based. Vittora Pro is named only where a feature is Pro, and household sharing is free. Apple Wallet import is not mentioned (ships dark). **Mac:** Live Activities, the interactive widget, Watch voice entry and multi-page scanning are iOS-only and are not claimed; household invitations can only be accepted on iPhone or iPad (`HouseholdShareAcceptance.swift` is `#if os(iOS)`), which the copy says.

The macOS tab for the **Spanish (Mexico)** / `es-MX` localization, which is what
serves Spanish-speaking users in the US storefront. `metadata-mac-en-US.md` is
the same tab in English; `metadata-es-US.md` is the **iOS/iPadOS** tab in
Spanish. All three are separate fields in App Store Connect.

Neutral Latin American Spanish, matching the in-app translations shipped in 1.5
(L2) and natively reviewed on 2026-08-02. Terminology follows the in-app
catalogue so the listing and the app agree: *saldo*, *presupuesto*, *meta de
ahorro*, *patrimonio neto*, *deuda*, *beneficiario*, *monto*, *impuestos*.

Price tier stays Free but the app offers in-app purchases from 1.7.0
(DEC-013/014/015); Vittora Pro may now be described. The "no ads, no
trackers, no accounts, no data selling" claims remain true and must be kept.

**What the Mac build must NOT claim** (same target audit as
`metadata-mac-en-US.md`): the Apple Watch app, complications, Smart Stack, Home
Screen / Lock Screen / StandBy widgets, or camera receipt scanning —
`ReceiptScannerView` gates `VisionKit` behind `#if os(iOS)` and the Mac gets a
file-import fallback instead.

**What it may claim, verified present and unguarded on macOS:** Siri /
Shortcuts, Handoff, Spotlight, PDF export, every report, Year in Review, and
full keyboard navigation.

---

## App Name (30 max — 28, same record as iOS)

```
Vittora: Finanzas Personales
```

## Subtitle (30 max — 28)

```
Tu dinero, privado en tu Mac
```

## Promotional Text (170 max — 148)

```
Nuevo en 1.8: impuestos para cinco países, presupuestos del hogar compartidos e informes más útiles en tu Mac. Sin conectar tu banco y sin anuncios.
```

## Description (4000 max — 3962)

```
Vittora es la app de finanzas personales que nunca te pide la contraseña de tu banco.

Sin conexión bancaria. Sin Plaid. Sin servicios externos leyendo tus estados de cuenta. Tú registras lo que gastas y todo se queda en tu iCloud privado: cifrado, sincronizado con tu iPhone y iPad, y totalmente funcional sin internet.

HECHA PARA LA MAC
• Navegación completa con el teclado: recorre cada pantalla y formulario sin tocar el mouse
• Una ventana de Mac de verdad, del tamaño que tú quieras, no una app de teléfono estirada
• Desbloquea con Touch ID o tu contraseña
• Importa y exporta CSV, y adjunta recibos y documentos desde el Finder

REGISTRA CADA MONTO
• Anota gastos, ingresos y transferencias en segundos
• Sugerencias de categoría que aprenden de tu propio historial, en tu Mac
• Categorías con subcategorías, beneficiarios, cuentas y métodos de pago
• Busca y filtra todo tu historial al instante

CONTINÚA EN OTRO DISPOSITIVO
• Empieza una transacción en el iPhone y termínala en la Mac
• Encuentra cualquier transacción desde Spotlight
• Pregúntale a Siri cuánto gastaste, o registra un gasto con la voz

PRESUPUESTOS QUE TE SIGUEN EL PASO
• Presupuestos semanales, mensuales, trimestrales o anuales por categoría
• Avisos por color antes de pasarte, no después
• Hogar compartido: presupuestos compartidos por iCloud, gasto por miembro y control de quién puede editar (las invitaciones se aceptan en el iPhone o el iPad)

METAS DE AHORRO Y FONDOS COMPARTIDOS
• Define un objetivo, registra aportes y mira avanzar el progreso
• Varias metas pueden usar la misma cuenta, y Vittora te avisa cuando suman más de lo que hay en ella

INFORMES QUE EXPLICAN TU DINERO
• Salud financiera y una perspectiva de gastos con escenarios de «qué pasaría si»
• Patrimonio neto a lo largo del tiempo, pronóstico de flujo de efectivo y resumen anual
• Resumen mensual con una explicación en palabras sencillas, escrita por Apple Intelligence en las Mac compatibles
• Alertas de gastos inusuales y sugerencias de presupuesto basadas solo en tus registros
• Desglose por categoría, regla 50/30/20, fondo de emergencia y auditoría de suscripciones
• Informes personalizados y exportación mensual y anual en PDF

TU AÑO EN RESUMEN
• Total gastado, categorías principales, mes más alto y logros
• Compártelo como imagen; los montos se omiten de forma predeterminada

IMPUESTOS PARA CINCO PAÍSES
• Estados Unidos, Reino Unido, Canadá (todas las provincias y territorios), Australia e India
• Cuánto espacio te queda este año en 401(k), IRA y HSA
• Estimaciones educativas, calculadas en tu Mac

PRESTA Y DIVIDE
• Registra lo que prestaste o pediste prestado
• Divide gastos de grupo y mira quién le debe a quién

RECURRENTES, RESUELTO
• Sueldo, renta, suscripciones: configúralos una vez y Vittora los registra
• Vista de próximos y recordatorios con horas de silencio

PRIVADA POR DISEÑO
• Funciona sin internet; la sincronización es opcional y solo por tu iCloud personal
• Sin anuncios, sin rastreadores, sin analíticas vendidas a nadie
• Borra todos tus datos cuando quieras

ACCESIBILIDAD
• VoiceOver, texto dinámico y contraste revisados en toda la app
• Tema negro y colores de acento

Vittora es gratis, en todos tus dispositivos.

Tus registros, tus gastos compartidos, el hogar compartido, la sincronización con iCloud y la exportación a CSV siguen siendo gratis, siempre. Vittora Pro es una mejora opcional que desbloquea el análisis de futuro: estimaciones fiscales y comparación de regímenes, salud financiera, perspectiva de gastos, pronóstico de flujo de efectivo, auditoría de suscripciones, el informe 50/30/20, el fondo de emergencia, informes personalizados con PDF y escaneo de recibos ilimitado. Sin Pro tienes cinco escaneos al mes, y todo lo que ya creaste sigue siendo tuyo.

Vittora Pro está disponible por mes, por año con 7 días de prueba gratis, o como compra única Lifetime.

Requiere macOS 26. También disponible para iPhone, iPad y Apple Watch.
```

## Keywords (100 max)

```
presupuesto,gastos,finanzas personales,ahorro,dinero,control de gastos,recibos,deudas
```

## URLs (unchanged)

- Support URL: `https://www.vittora.app/support`
- Marketing URL: `https://www.vittora.app`
- Privacy Policy URL: `https://www.vittora.app/privacy`

## What's New

Use the Spanish section of `WHATS_NEW_1.8.0.md`, without its "ON IPHONE AND APPLE WATCH" section (iPhone-only features).

---

## Notes for whoever publishes this

- **Not a translation of the English Mac file.** Written against the same
  verified Mac feature set, but the section headings and phrasing follow the
  Spanish in-app terminology so the listing and the app agree.
- **The closing line does the cross-sell.** Naming iPhone, iPad and Apple Watch
  recovers the Watch story without claiming it runs on the Mac — this is a
  universal purchase, so a Mac buyer already owns the iOS app.
- Touch ID wording says "o tu contraseña" deliberately: plenty of Macs have no
  Touch ID sensor, and `LocalAuthentication` falls back to the password there.
- **Screenshots** are the 1.8.0 gallery in `Marketing/AppStore/` (beside the repo): mac-es. Regenerate with the scripts in `Scripts/store/` — see `Docs/Store/screenshots/README.md`.
