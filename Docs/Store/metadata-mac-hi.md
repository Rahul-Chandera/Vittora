# App Store Metadata — macOS platform tab, hi (Hindi)

**Refreshed 2026-10-06 for 1.8.0 (build 13).** Promotional text and Description now cover the 1.8.0 feature set: tax estimates for five countries, household sharing, sinking funds, sub-categories, the financial health score, spending outlook and what-if, net worth over time, the unusual-spending and budget insights, on-device category suggestions and the Apple Intelligence month summary. AI is named only for those last two ("on supported devices"); the health score, outlook and insights are rules-based. Vittora Pro is named only where a feature is Pro, and household sharing is free. Apple Wallet import is not mentioned (ships dark). **Mac:** Live Activities, the interactive widget, Watch voice entry and multi-page scanning are iOS-only and are not claimed; household invitations can only be accepted on iPhone or iPad (`HouseholdShareAcceptance.swift` is `#if os(iOS)`), which the copy says.

The macOS tab for the **Hindi** localization. `metadata-hi.md` is the
iOS/iPadOS tab in Hindi; `metadata-mac-en-IN.md` is the same macOS tab in
English for the India storefront.

Terminology follows the in-app catalogue, same as `metadata-hi.md`: *बजट*,
*बचत*, *कैटेगरी*, *पेयी*, *उधार*, *खर्च*, *आय*, *ट्रांज़ैक्शन*, *राशि*,
*टैक्स*, *नेट वर्थ*, *आपातकालीन फंड*, *साल की समीक्षा*.

Price tier stays Free but the app offers in-app purchases from 1.7.0
(DEC-013/014/015); Vittora Pro may now be described. The "no ads, no
trackers, no accounts, no data selling" claims remain true and must be kept.

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

## Promotional Text (170 max — 152)

```
1.8 में नया: आपके Mac पर घर के साथ साझा बजट, बेहतर रिपोर्ट और FY 2026-27 के टैक्स नियम। पुराना बनाम नया रिजीम। कोई बैंक लिंकिंग नहीं, कोई विज्ञापन नहीं।
```

## Description (4000 max — 3869)

```
Vittora वह पर्सनल फाइनेंस ऐप है जो आपसे कभी बैंक का पासवर्ड या OTP नहीं माँगती।

कोई बैंक लिंकिंग नहीं। कोई अकाउंट एग्रीगेटर आपके स्टेटमेंट नहीं पढ़ता। आप जो खर्च करते हैं वह आप दर्ज करते हैं, और सब कुछ आपके निजी iCloud में रहता है — एन्क्रिप्टेड, आपके iPhone और iPad के साथ सिंक, और ऑफ़लाइन भी पूरी तरह काम करता है।

Mac के लिए बनाई गई
• पूरा कीबोर्ड नेविगेशन — माउस छुए बिना हर स्क्रीन और फ़ॉर्म में चलें
• एक असली Mac विंडो, जिस आकार में आप चाहें — खींची हुई फ़ोन ऐप नहीं
• Touch ID या अपने पासवर्ड से अनलॉक करें
• CSV इम्पोर्ट और एक्सपोर्ट करें, और Finder से रसीदें व दस्तावेज़ जोड़ें

हर रुपया ट्रैक करें
• सेकंडों में खर्च, आय और ट्रांसफ़र दर्ज करें — UPI, कार्ड या कैश
• कैटेगरी सुझाव जो आपकी अपनी हिस्ट्री से सीखते हैं, आपके Mac पर ही
• कैटेगरी और उप-श्रेणियाँ, पेयी, अकाउंट और पेमेंट मेथड
• अपनी पूरी हिस्ट्री तुरंत खोजें और फ़िल्टर करें

भारत का टैक्स, आपके लिए हिसाब लगाया हुआ
• FY 2026-27 के नियमों के साथ पुराने और नए रिजीम की साथ-साथ तुलना
• 80C, 80CCD(1B) के तहत NPS और 80CCD(2) के तहत नियोक्ता NPS, 80D — माता-पिता और सीनियर दरों सहित, HRA, स्टैंडर्ड डिडक्शन, सेस और मार्जिनल रिलीफ़ के साथ सरचार्ज
• उन नियमों पर चेतावनी जो अक्सर छूट जाते हैं — सेक्शन 269ST की कैश लिमिट, सेक्शन 40A(3), कैश जमा की रिपोर्टिंग, GST रजिस्ट्रेशन थ्रेशोल्ड और किराए पर सेक्शन 194-IB TDS
• अमेरिका, UK, कनाडा और ऑस्ट्रेलिया के टैक्स अनुमान भी

बजट जो आपके साथ चले
• हर कैटेगरी के लिए साप्ताहिक, मासिक, तिमाही या सालाना बजट
• खर्च बढ़ने से पहले रंगों में चेतावनी, बाद में नहीं
• घर के साथ साझा बजट: iCloud के ज़रिए, हर सदस्य का खर्च, और कौन बदलाव कर सकता है इस पर नियंत्रण (निमंत्रण iPhone या iPad पर स्वीकार किए जाते हैं)

बचत लक्ष्य और सिंकिंग फ़ंड
• लक्ष्य तय करें, योगदान ट्रैक करें, प्रगति रिंग भरते देखें
• कई लक्ष्य एक ही अकाउंट साझा कर सकते हैं, और Vittora बताती है जब वे उसमें मौजूद रकम से ज़्यादा का दावा करते हैं

रिपोर्ट जो आपका पैसा समझाएँ
• वित्तीय स्वास्थ्य स्कोर, और "क्या हो अगर" परिदृश्यों के साथ खर्च आउटलुक
• समय के साथ नेट वर्थ, कैश फ़्लो पूर्वानुमान और सालाना सारांश
• मासिक अवलोकन आसान शब्दों वाले सारांश के साथ, जिसे समर्थित Mac पर Apple Intelligence लिखता है
• असामान्य खर्च की चेतावनी और बजट सुझाव, सिर्फ़ आपके अपने रिकॉर्ड से
• कैटेगरी ब्रेकडाउन, 50/30/20, आपातकालीन फंड ट्रैकर और सब्सक्रिप्शन ऑडिट
• कस्टम रिपोर्ट, और मासिक व सालाना PDF एक्सपोर्ट

आपके साल की समीक्षा
• कुल खर्च, मुख्य कैटेगरी, सबसे बड़ा महीना और उपलब्धियाँ
• इमेज के रूप में शेयर करें — राशि डिफ़ॉल्ट रूप से छिपी रहती है

कहीं भी जारी रखें
• iPhone से Handoff, Spotlight खोज, और Siri से खर्च पूछें या नया खर्च जोड़ें

स्प्लिट और सेटल
• दिया या लिया हुआ पैसा ट्रैक करें, और ग्रुप के खर्च बाँटें

आवर्ती खर्च, सँभाले हुए
• सैलरी, किराया, सब्सक्रिप्शन — एक बार सेट करें, Vittora समय पर दर्ज करेगी; क्वाइट आवर्स के साथ रिमाइंडर

निजता, डिज़ाइन से
• पूरी तरह ऑफ़लाइन काम करती है; सिंक वैकल्पिक है और सिर्फ़ आपके निजी iCloud से होता है
• कोई विज्ञापन नहीं, कोई ट्रैकर नहीं, किसी को बेचा गया कोई एनालिटिक्स नहीं
• ऐप के अंदर से सपोर्ट को संपर्क करें — भेजने से पहले आप पूरा डायग्नोस्टिक सारांश देखते हैं, और उसमें आपकी राशि, नोट्स या पेयी कभी शामिल नहीं होते
• अपना सारा डेटा जब चाहें मिटाएँ

हिंदी, अंग्रेज़ी और स्पैनिश में, पूरे ऐप में VoiceOver, डायनामिक टाइप और कंट्रास्ट पर व्यापक काम के साथ। Vittora मुफ़्त है, हर डिवाइस पर।

आपके रिकॉर्ड, आपके स्प्लिट, घर के साथ साझा बजट, iCloud सिंक और CSV एक्सपोर्ट हमेशा मुफ़्त रहेंगे। Vittora Pro एक वैकल्पिक अपग्रेड है जो आगे की योजना बताने वाला विश्लेषण अनलॉक करता है: टैक्स अनुमान और रिजीम तुलना, वित्तीय स्वास्थ्य स्कोर, खर्च आउटलुक, कैश फ़्लो पूर्वानुमान, सब्सक्रिप्शन ऑडिट, 50/30/20 रिपोर्ट, आपातकालीन फंड ट्रैकर, PDF एक्सपोर्ट के साथ कस्टम रिपोर्ट, और असीमित रसीद स्कैनिंग। Pro के बिना हर महीने पाँच रसीद स्कैन मिलते हैं, और आपने जो कुछ बनाया है वह आपका ही रहता है।

Vittora Pro मासिक, वार्षिक (7 दिन मुफ़्त ट्रायल के साथ), या एक बार की Lifetime खरीद के रूप में उपलब्ध है।

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

Use the Hindi section of `WHATS_NEW_1.8.0.md`, without its "ON IPHONE AND APPLE WATCH" section (iPhone-only features).

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
- **Screenshots** are the 1.8.0 gallery in `Marketing/AppStore/` (beside the repo): mac-hi. Regenerate with the scripts in `Scripts/store/` — see `Docs/Store/screenshots/README.md`.
