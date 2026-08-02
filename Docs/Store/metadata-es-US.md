# App Store Metadata — es-US (Spanish, United States)

For the **Spanish (Mexico)** / `es-MX` localization in App Store Connect, which
is what serves Spanish-speaking users in the US storefront. Neutral Latin
American Spanish, matching the in-app translations shipped in 1.5 (L2).

**Written for the current feature set** (1.4.0 shipped + 1.5), not translated
from `metadata-en-US.md` — that file still describes v1.0.0 and predates the
Watch app, widgets, Siri, Handoff and Year in Review. See the note at the end.

Terminology follows the in-app catalogue so the listing and the app agree:
*saldo*, *presupuesto*, *meta de ahorro*, *patrimonio neto*, *deuda*,
*beneficiario*, *monto*, *impuestos*.

---

## App Name (30 max — this is 28)

```
Vittora: Finanzas Personales
```

## Subtitle (30 max — this is exactly 30)

```
Gastos y presupuestos privados
```

## Promotional Text (170 max — this is ~158)

```
Tu dinero, en tu dispositivo. Registra gastos, presupuestos y metas de ahorro sin conectar tu banco, sin anuncios y sin vender tus datos. Sincroniza por iCloud.
```

## Description (4000 max)

```
Vittora es la app de finanzas personales que nunca te pide la contraseña de tu banco.

Sin conexión bancaria. Sin Plaid. Sin servicios externos leyendo tus estados de cuenta. Tú registras lo que gastas y todo se queda en tu iCloud privado: cifrado, sincronizado entre iPhone, iPad, Apple Watch y Mac, y totalmente funcional sin internet.

REGISTRA CADA MONTO
• Anota gastos, ingresos y transferencias en segundos
• Organiza con categorías, beneficiarios, cuentas y métodos de pago
• Busca y filtra todo tu historial al instante
• Importa desde CSV y exporta tus datos cuando quieras: son tuyos

PRESUPUESTOS QUE TE SIGUEN EL PASO
• Presupuestos semanales, mensuales, trimestrales o anuales por categoría
• Progreso general y por presupuesto, de un vistazo
• Avisos por color antes de pasarte, no después

METAS DE AHORRO
• Define un objetivo, registra aportes y mira avanzar el progreso
• Fondo de emergencia, vacaciones, un auto nuevo: tantas metas como necesites

EN TU MUÑECA Y EN TU PANTALLA
• App para Apple Watch: registra un gasto en segundos con la corona digital
• Complicaciones y widgets con el gasto de hoy y lo que queda del presupuesto
• Widgets en pantalla de inicio, pantalla bloqueada y StandBy
• Los montos se ocultan mientras el dispositivo está bloqueado
• Pregúntale a Siri cuánto gastaste, o registra un gasto con la voz

CONTINÚA EN OTRO DISPOSITIVO
• Empieza una transacción en el iPhone y termínala en el iPad o la Mac
• Encuentra cualquier transacción desde Spotlight

REPORTES QUE EXPLICAN TU DINERO
• Resumen mensual de ingresos y gastos a 12 meses
• Desglose por categoría con porcentajes
• Regla 50/30/20 de necesidades, deseos y ahorro
• Fondo de emergencia: cuántos meses podrías cubrir
• Auditoría de suscripciones: lo que realmente cuestan cada mes
• Proyección de flujo de efectivo, patrimonio neto y reportes personalizados
• Exporta el resumen mensual y anual en PDF

TU AÑO EN RESUMEN
• Mira tu año completo: total gastado, categorías principales, mes más alto y logros
• Compártelo como imagen. Los montos se omiten de forma predeterminada, para que puedas publicarlo sin publicar tus finanzas

IMPUESTOS
• Estimación federal de EE. UU. según tus ingresos y estado civil fiscal
• Cuánto espacio te queda este año en 401(k) e IRA

PRESTA Y DIVIDE
• Registra lo que prestaste o pediste prestado
• Divide gastos de grupo y mira quién le debe a quién

RECURRENTES, RESUELTO
• Sueldo, renta, suscripciones: configúralos una vez y Vittora los registra
• La vista de próximos muestra lo que está por caer en tus cuentas

PRIVADA POR DISEÑO
• Funciona sin internet; la sincronización es opcional y solo por tu iCloud personal
• Bloqueo con Face ID o Touch ID
• Sin anuncios, sin rastreadores, sin analíticas vendidas a nadie
• Borra todos tus datos cuando quieras

ACCESIBILIDAD
• VoiceOver, texto dinámico y contraste revisados en toda la app
• Navegación completa con teclado en iPad y Mac
• Tema negro OLED y colores de acento

Vittora es gratis. Todas las funciones, en todos tus dispositivos.

Requiere iOS 26, iPadOS 26 o macOS 26.
```

## Keywords (100 max — this is ~86)

```
presupuesto,gastos,finanzas personales,ahorro,dinero,control de gastos,cuentas,recibos
```

## URLs

Same as en-US — the site is English-only, which is a known gap:

- Support URL: `https://www.vittora.app/support`
- Marketing URL: `https://www.vittora.app`
- Privacy Policy URL: `https://www.vittora.app/privacy`

## What's New — 1.5.0 (Spanish)

```
TU AÑO EN RESUMEN
• Mira tu año en un solo lugar: total gastado, categorías principales, mes más alto, comercios frecuentes, ahorro y algunos logros
• Compártelo como imagen: los montos se omiten de forma predeterminada, para que puedas publicarlo sin publicar tus finanzas
• Elige cualquier año con registros

ESPAÑOL
• Vittora ya está disponible por completo en español

ACCESIBILIDAD
• Encabezados más claros y fáciles de leer en toda la app
• Mejor contraste en montos y etiquetas
• Más mejoras de VoiceOver y texto dinámico

Sigue sin cuentas, sin anuncios y sin rastreo: tus datos se quedan en tus dispositivos.
```

---

## Notes for whoever publishes this

**`metadata-en-US.md` is four releases stale.** It was written for v1.0.0 and
still says so — no Apple Watch app, no widgets, no Siri, no Spotlight, no
Handoff, no 50/30/20 or emergency fund, no subscription audit, no Year in
Review, no PDF export. The live listing is therefore selling far less than the
app does. **Refreshing en-US (and en-IN) is worth more than adding Spanish**,
because it fixes the listing every US visitor already sees. This Spanish file
is written against the current feature set, so it can serve as the source when
updating English.

**Screenshots are still English.** Spanish metadata with English screenshots is
acceptable and common, but localized captures would land better. The
`SpanishLocalizationUITests` suite already produces Spanish screenshots as test
attachments (`es-dashboard`, `es-savings`, `es-tax-dashboard`, and others) — those
can be pulled from the xcresult and framed with `Scripts/store/make_marketing.py`
rather than re-shot by hand.

**Two claims to re-check before publishing**, because they are localization
choices rather than facts:
- *Estado civil fiscal* for "filing status" — correct and used in the app, but a
  tax-savvy native speaker should confirm it reads naturally in a US context.
- The US tax section stays in Spanish while naming US concepts (401(k), IRA).
  That is intentional — the audience is Spanish-speaking US filers.
