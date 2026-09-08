# App Store Metadata — macOS platform tab, es-US (Spanish)

The macOS tab for the **Spanish (Mexico)** / `es-MX` localization, which is what
serves Spanish-speaking users in the US storefront. `metadata-mac-en-US.md` is
the same tab in English; `metadata-es-US.md` is the **iOS/iPadOS** tab in
Spanish. All three are separate fields in App Store Connect.

Neutral Latin American Spanish, matching the in-app translations shipped in 1.5
(L2) and natively reviewed on 2026-08-02. Terminology follows the in-app
catalogue so the listing and the app agree: *saldo*, *presupuesto*, *meta de
ahorro*, *patrimonio neto*, *deuda*, *beneficiario*, *monto*, *impuestos*.

Free, no IAP (DEC-008). Pro is DEC-011 and must not appear.

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

## Promotional Text (170 max)

```
Ahora con Año en Resumen y en español. Registra gastos, presupuestos y metas en tu Mac sin conectar tu banco, sin anuncios y sin vender tus datos. Sincroniza por iCloud.
```

## Description (4000 max)

```
Vittora es la app de finanzas personales que nunca te pide la contraseña de tu banco.

Sin conexión bancaria. Sin Plaid. Sin servicios externos leyendo tus estados de cuenta. Tú registras lo que gastas y todo se queda en tu iCloud privado: cifrado, sincronizado con tu iPhone y iPad, y totalmente funcional sin internet.

HECHA PARA LA MAC
• Navegación completa con el teclado: recorre cada pantalla y formulario sin tocar el mouse
• Una ventana de Mac de verdad, del tamaño que tú quieras, no una app de teléfono estirada
• Desbloquea con Touch ID o tu contraseña
• Importa y exporta CSV, y adjunta recibos y documentos desde el Finder

REGISTRA CADA PESO
• Anota gastos, ingresos y transferencias en segundos
• Organiza con categorías, beneficiarios, cuentas y métodos de pago
• Busca y filtra todo tu historial al instante
• Tus datos son tuyos: expórtalos cuando quieras, en un formato que puedes leer

CONTINÚA DONDE SEA
• Handoff: empieza un movimiento en el iPhone y termínalo en la Mac
• Encuentra cualquier movimiento con Spotlight
• Pregúntale a Siri cuánto has gastado, o registra un gasto por voz

PRESUPUESTOS QUE TE SIGUEN EL PASO
• Presupuestos semanales, mensuales, trimestrales o anuales por categoría
• Progreso general y por presupuesto de un vistazo
• Avisos con color antes de pasarte, no después

METAS DE AHORRO
• Define un objetivo, registra aportaciones y mira avanzar el anillo de progreso
• Fondo de emergencia, vacaciones, un coche nuevo: tantas metas como necesites

REPORTES QUE SÍ EXPLICAN TU DINERO
• Resumen mensual de ingresos contra gastos a lo largo de 12 meses
• Desglose por categoría con porcentajes
• Análisis 50/30/20 de necesidades, gustos y ahorro
• Fondo de emergencia: cuántos meses podrías cubrir
• Auditoría de suscripciones: lo que realmente cuestan tus cargos recurrentes
• Flujo de efectivo, patrimonio neto, resumen anual y reportes personalizados
• Exporta reportes mensuales y anuales en PDF

TU AÑO EN RESUMEN
• Mira tu año completo: total gastado, categorías principales, tu mes más alto, comercios frecuentes, ahorro y logros
• Compártelo como imagen: los montos quedan fuera de forma predeterminada, así puedes publicarlo sin publicar tus finanzas

DIVIDE Y SALDA
• Lleva el control de lo que prestaste o te prestaron con un registro de deudas
• Divide gastos de grupo y ve quién le debe a quién

LO RECURRENTE, RESUELTO
• Sueldo, renta, suscripciones: configúralos una vez y Vittora los registra a tiempo
• La vista de próximos muestra lo que está por caer en tus cuentas
• Elige cuándo llegan los recordatorios, con horas de silencio

A TU MANERA
• Español, inglés e hindi
• Tema negro puro y varios colores de acento
• Trabajo extenso de VoiceOver, texto dinámico y contraste en toda la app

PRIVADA POR DISEÑO
• Funciona sin internet; la sincronización es opcional y solo pasa por tu iCloud personal
• Sin anuncios, sin rastreadores, sin analíticas vendidas a nadie
• Contacta a soporte desde la app: ves el resumen de diagnóstico completo antes de enviar nada, y nunca incluye tus montos, notas ni beneficiarios
• Borra todos tus datos cuando quieras, en tus términos

Vittora es gratis. Todas las funciones, en todos tus dispositivos.

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

Translate the **Mac** block in `WHATS_NEW_1.5.0.md`, or reuse the Spanish
"What's New" in `metadata-es-US.md` with the Watch and widget lines removed and
sharing worded for the Mac share sheet.

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
- Mac screenshots for this localization are
  `Docs/Store/screenshots/marketing/mac-es/` (1440×900). Regenerate with
  `Scripts/store/capture_mac_screenshots.sh mac-es es es_MX US`, which needs an
  unlocked screen and a signed build.
