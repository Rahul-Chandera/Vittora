# What's New — 1.8.1

App Store "What's New in This Version" copy. Users are coming from 1.8.0.

1.8.1 is the iPhone Duo release, plus two features that were waiting on it.

**iOS/iPadOS vs Mac.** "ON IPHONE DUO" describes iPhone only. **Delete that
section from the Mac listing**; the rest applies to both (the Mac has the same
transaction form and CSV import).

Claim rules, unchanged from 1.8.0:
- Suggested entries are **rules-based**: matched on your own history by weekday
  and hour. Never call them AI or "predictive".
- AI is named only for on-device category suggestions and the Apple
  Intelligence month summary, and neither changed here, so this note names no AI.
- Apple Wallet import is not mentioned (ships dark).
- No competitor names (Mint, YNAB) in What's New. Guideline 2.3.7 is about
  metadata keywords, but the safer line is "budgeting apps".

Deliberately not listed:
- The tab bar, sheet and toolbar changes as such. Users on other iPhones see
  the same tabs; quick add opens as a sheet rather than a full-screen cover,
  which reads as polish, not news.
- The CloudKit schema initializer (#302): developer tooling only.

---

## English

```
ON IPHONE DUO
• Vittora works across both displays and keeps your place when you fold or unfold, even in the middle of adding an expense
• On the inner display the dashboard spreads into two columns, and they part at the fold, so nothing important sits in the crease
• Transactions show the list and the details side by side when there's room

SUGGESTED ENTRIES
• When you add an expense, Vittora can offer the payee, category and amount you usually record at this time. Tap to use it, or ignore it. It comes from your own history on your device

IMPORTING FROM OTHER BUDGETING APPS
• Dates in day-first exports (05/01 for 5 January) are now read the right way round
• Transfers between your accounts and starting balances are no longer imported as spending or income

FIXES
• On iPad, the transaction list stays visible beside the details in portrait

Still no accounts, no ads, no tracking — your data stays on your devices.
```

---

## Spanish — es-MX

```
EN IPHONE DUO
• Vittora funciona en las dos pantallas y conserva tu lugar al plegar o desplegar el teléfono, incluso a mitad de registrar un gasto
• En la pantalla interior, el panel se reparte en dos columnas que se separan en el pliegue, para que nada importante quede en la bisagra
• Las transacciones muestran la lista y los detalles lado a lado cuando hay espacio

ENTRADAS SUGERIDAS
• Al añadir un gasto, Vittora puede ofrecerte el beneficiario, la categoría y el monto que sueles registrar a esta hora. Tócalo para usarlo o ignóralo. Sale de tu propio historial, en tu dispositivo

IMPORTAR DESDE OTRAS APPS DE PRESUPUESTO
• Las fechas de las exportaciones con el día primero (05/01 para el 5 de enero) ahora se leen correctamente
• Las transferencias entre tus cuentas y los saldos iniciales ya no se importan como gastos ni como ingresos

CORRECCIONES
• En el iPad, la lista de transacciones se mantiene visible junto a los detalles en vertical

Sigue sin cuentas, sin anuncios y sin rastreo: tus datos se quedan en tus dispositivos.
```

---

## Hindi — hi

```
iPhone Duo पर
• Vittora दोनों डिस्प्ले पर चलता है और फ़ोन मोड़ने या खोलने पर आप जहाँ थे वहीं रहता है, खर्च जोड़ते समय भी
• अंदर वाले डिस्प्ले पर डैशबोर्ड दो कॉलम में फैल जाता है, जो मोड़ पर अलग होते हैं, ताकि कोई ज़रूरी चीज़ मोड़ में न आए
• जगह होने पर लेन-देन की सूची और विवरण साथ-साथ दिखते हैं

सुझाई गई प्रविष्टियाँ
• खर्च जोड़ते समय Vittora वह भुगतान पाने वाला, श्रेणी और रकम सुझा सकता है जो आप आमतौर पर इसी समय दर्ज करते हैं। इस्तेमाल करने के लिए टैप करें या छोड़ दें। यह आपके डिवाइस पर आपके अपने इतिहास से आता है

दूसरे बजट ऐप से इम्पोर्ट
• दिन पहले लिखने वाले एक्सपोर्ट (5 जनवरी के लिए 05/01) की तारीखें अब सही पढ़ी जाती हैं
• आपके अकाउंट के बीच ट्रांसफ़र और शुरुआती बैलेंस अब खर्च या आय के रूप में इम्पोर्ट नहीं होते

सुधार
• iPad पर खड़े मोड में लेन-देन की सूची विवरण के साथ दिखती रहती है

अब भी कोई अकाउंट नहीं, कोई विज्ञापन नहीं, कोई ट्रैकिंग नहीं — आपका डेटा आपके डिवाइस पर ही रहता है।
```

---

## Notes

- Limit is 4000 characters per locale; all three are far under.
- Terminology follows the shipped catalogue: *Normalmente registras esto a esta
  hora* / *आप आमतौर पर इसे इसी समय दर्ज करते हैं* is the in-app reason line.
- Mac: delete "ON IPHONE DUO" / "EN IPHONE DUO" / "iPhone Duo पर".
- The Mac listings' household-invitation wording was corrected separately
  (Docs/Store/metadata-mac-*.md, 2026-10-10); description changes ride with
  this submission.
