# App Store Metadata — macOS platform tab, hi (Hindi)

The macOS tab for the **Hindi** localization. `metadata-hi.md` is the
iOS/iPadOS tab in Hindi; `metadata-mac-en-IN.md` is the same macOS tab in
English for the India storefront.

Terminology follows the in-app catalogue, same as `metadata-hi.md`: *बजट*,
*बचत*, *कैटेगरी*, *पेयी*, *उधार*, *खर्च*, *आय*, *ट्रांज़ैक्शन*, *राशि*,
*टैक्स*, *नेट वर्थ*, *आपातकालीन फंड*, *साल की समीक्षा*.

Free, no IAP (DEC-008). Pro is DEC-011 and must not appear.

**What the Mac build must NOT claim** (same target audit as
`metadata-mac-en-US.md`): the Apple Watch app, complications, Smart Stack, Home
Screen / Lock Screen / StandBy widgets, or camera receipt scanning —
`ReceiptScannerView` gates `VisionKit` behind `#if os(iOS)` and the Mac gets a
file-import fallback instead. The Hindi iOS description claims all of those, so
they had to be removed here rather than translated across.

**What it may claim, verified present and unguarded on macOS:** the India tax
estimator and compliance tips, Siri / Shortcuts, Handoff, Spotlight, PDF
export, every report, Year in Review, and full keyboard navigation.

> **Needs a native read before publishing**, same as `metadata-hi.md`. New
> marketing copy, not covered by the 2026-08-02 in-app string review.

---

## App Name (30 max)

```
Vittora: पर्सनल फाइनेंस
```

## Subtitle (30 max)

```
Mac पर बजट, टैक्स और खर्च
```

## Promotional Text (170 max)

```
अब हिंदी में, साल की समीक्षा के साथ। अपने Mac पर खर्च, बजट और टैक्स ट्रैक करें — पुराना बनाम नया रिजीम। कोई बैंक लिंकिंग नहीं, कोई विज्ञापन नहीं। iCloud से सिंक।
```

## Description (4000 max)

```
Vittora वह पर्सनल फाइनेंस ऐप है जो आपसे कभी बैंक का पासवर्ड या OTP नहीं माँगती।

कोई बैंक लिंकिंग नहीं। कोई अकाउंट एग्रीगेटर आपके स्टेटमेंट नहीं पढ़ता। आप जो खर्च करते हैं वह आप दर्ज करते हैं, और सब कुछ आपके निजी iCloud में रहता है — एन्क्रिप्टेड, आपके iPhone और iPad के साथ सिंक, और ऑफ़लाइन भी पूरी तरह काम करता है।

Mac के लिए बनाई गई
• पूरा कीबोर्ड नेविगेशन — माउस छुए बिना हर स्क्रीन और फ़ॉर्म में चलें
• एक असली Mac विंडो, जिस आकार में आप चाहें — खींची हुई फ़ोन ऐप नहीं
• Touch ID या अपने पासवर्ड से अनलॉक करें
• CSV इम्पोर्ट और एक्सपोर्ट करें, और Finder से रसीदें व दस्तावेज़ जोड़ें

हर रुपया ट्रैक करें
• सेकंडों में खर्च, आय और ट्रांसफ़र दर्ज करें
• कैटेगरी, पेयी, अकाउंट और पेमेंट मेथड से व्यवस्थित करें — UPI, कार्ड या कैश
• अपनी पूरी हिस्ट्री तुरंत खोजें और फ़िल्टर करें
• डेटा आपका है — जब चाहें एक्सपोर्ट करें, ऐसे फ़ॉर्मैट में जिसे आप पढ़ सकें

भारत का टैक्स, आपके लिए हिसाब लगाया हुआ
• चुनने से पहले पुराने और नए रिजीम की साथ-साथ तुलना करें
• 80C, 80CCD (NPS), 80D — माता-पिता और सीनियर दरों सहित, HRA और स्टैंडर्ड डिडक्शन
• सेस और सरचार्ज शामिल, ताकि दिखने वाली रकम ही असली रकम हो
• उन नियमों पर चेतावनी जो अक्सर छूट जाते हैं — सेक्शन 269ST की कैश लिमिट, सेक्शन 40A(3), कैश जमा की रिपोर्टिंग, GST रजिस्ट्रेशन थ्रेशोल्ड और किराए पर सेक्शन 194-IB TDS

कहीं भी जारी रखें
• Handoff — iPhone पर ट्रांज़ैक्शन शुरू करें और Mac पर पूरा करें
• Spotlight से कोई भी ट्रांज़ैक्शन खोजें
• Siri से पूछें कि आपने कितना खर्च किया, या बोलकर खर्च जोड़ें

बजट जो आपके साथ चले
• हर कैटेगरी के लिए साप्ताहिक, मासिक, तिमाही या सालाना बजट
• कुल और हर बजट की प्रगति एक नज़र में
• खर्च बढ़ने से पहले रंगों में चेतावनी, बाद में नहीं

बचत लक्ष्य
• लक्ष्य तय करें, योगदान ट्रैक करें, प्रगति रिंग भरते देखें
• आपातकालीन फंड, शादी, नई बाइक — जितने लक्ष्य चाहिए उतने

रिपोर्ट जो आपका पैसा समझाएँ
• 12 महीनों में आय बनाम खर्च का मासिक ओवरव्यू
• प्रतिशत के साथ कैटेगरी ब्रेकडाउन
• 50/30/20 — ज़रूरतें, चाहतें और बचत का विश्लेषण
• आपातकालीन फंड ट्रैकर — आप कितने महीने चला सकते हैं
• सब्सक्रिप्शन ऑडिट — आपके आवर्ती खर्च असल में कितने पड़ते हैं
• कैश-फ़्लो फ़ोरकास्ट, नेट वर्थ, सालाना सारांश और कस्टम रिपोर्ट
• मासिक और सालाना रिपोर्ट PDF में एक्सपोर्ट करें

आपके साल की समीक्षा
• पूरा साल एक जगह: कुल खर्च, मुख्य कैटेगरी, सबसे बड़ा महीना, टॉप मर्चेंट, बचत और उपलब्धियाँ
• इमेज के रूप में सेव या शेयर करें — राशि डिफ़ॉल्ट रूप से छिपी रहती है, इसलिए आप अपनी फ़ाइनेंस बताए बिना पोस्ट कर सकते हैं

स्प्लिट और सेटल
• एक आसान उधार लेजर से दिया या लिया हुआ पैसा ट्रैक करें
• ग्रुप के खर्च बाँटें और देखें किस पर किसका बकाया है

आवर्ती खर्च, सँभाले हुए
• सैलरी, किराया, सब्सक्रिप्शन — एक बार सेट करें और Vittora समय पर दर्ज कर देगी
• आने वाले खर्च की सूची दिखाती है कि अकाउंट से क्या कटने वाला है
• रिमाइंडर कब आएँ यह चुनें, क्वाइट आवर्स के साथ

आपके हिसाब से
• हिंदी, अंग्रेज़ी और स्पैनिश
• ट्रू-ब्लैक थीम और एक्सेंट रंगों का विकल्प
• पूरे ऐप में VoiceOver, डायनामिक टाइप और कंट्रास्ट पर व्यापक काम

निजता, डिज़ाइन से
• पूरी तरह ऑफ़लाइन काम करती है; सिंक वैकल्पिक है और सिर्फ़ आपके निजी iCloud से होता है
• कोई विज्ञापन नहीं, कोई ट्रैकर नहीं, किसी को बेचा गया कोई एनालिटिक्स नहीं
• ऐप के अंदर से सपोर्ट को संपर्क करें — भेजने से पहले आप पूरा डायग्नोस्टिक सारांश देखते हैं, और उसमें आपकी राशि, नोट्स या पेयी कभी शामिल नहीं होते
• अपना सारा डेटा जब चाहें, अपनी शर्तों पर मिटाएँ

Vittora मुफ़्त है। हर फ़ीचर, हर डिवाइस पर।

macOS 26 चाहिए। iPhone, iPad और Apple Watch के लिए भी उपलब्ध।
```

## Keywords (100 max)

```
बजट,खर्च,फाइनेंस,बचत,पैसा,टैक्स,80c,आयकर,खर्च ट्रैकर,पर्सनल फाइनेंस
```

## URLs (unchanged)

- Support URL: `https://www.vittora.app/support`
- Marketing URL: `https://www.vittora.app`
- Privacy Policy URL: `https://www.vittora.app/privacy`

## What's New

Translate the **Mac** block in `WHATS_NEW_1.5.0.md` — it already drops the
Watch and widget claims and words sharing for the Mac share sheet.

---

## Notes for whoever publishes this

- **This is not a translation of `metadata-hi.md`.** The Hindi iOS description
  claims the Watch app, complications and widgets, none of which exist on the
  Mac. Those sections are removed here, not reworded, and a Mac-specific
  section replaces them.
- **The closing line does the cross-sell.** Naming iPhone, iPad and Apple Watch
  recovers the Watch story without claiming it runs on the Mac — this is a
  universal purchase, so a Mac buyer already owns the iOS app.
- Touch ID wording says "या अपने पासवर्ड से" deliberately: plenty of Macs have
  no Touch ID sensor, and `LocalAuthentication` falls back to the password.
- Mac screenshots for this localization are
  `Docs/Store/screenshots/marketing/mac-hi/` (1440×900). Regenerate with
  `Scripts/store/capture_mac_screenshots.sh mac-hi hi hi_IN IN`, which needs an
  unlocked screen and a signed build.
