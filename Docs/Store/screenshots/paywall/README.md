# Paywall — subscription review screenshot

For **App Store Connect → Subscriptions → (each product) → Review Information →
Screenshot**, and the equivalent field on the Lifetime non-consumable.

`paywall.png` — 1320x2868, iPhone 17 Pro Max, en-US storefront.

## One image covers all three products

The review screenshot is shown to App Review, not to users. It is not localized and
not per-platform, and Vittora's paywall presents Annual, Monthly and Lifetime on one
screen — so the same file goes in all three slots.

## Regenerating

```
Scripts/store/capture_paywall_shot.sh
```

It drives `VittoraUITests/PaywallShotUITests`, which walks the same route
`ProGatingUITests` uses (a Pro report gives the lock; the lock opens the paywall) —
there is no paywall deep link.

**It has to be a UI test.** `simctl` cannot apply a StoreKit configuration and
`xcodebuild` ignores the scheme's, so any other capture route renders the
"products unavailable" state instead of the plans. The test builds its own
`SKTestSession` from `Vittora.storekit`, and asserts the plan cards actually
appeared before writing the file — a shot of the error state would pass review
review-board scrutiny about as well as a blank page.

## What this capture also proves

The image shows **"7 days free, then $39.99/year"** on Annual with the CTA reading
**"Try It Free"**. That is the intro-offer *eligible* path rendering correctly, which
until now had never been confirmed visually on any platform.
