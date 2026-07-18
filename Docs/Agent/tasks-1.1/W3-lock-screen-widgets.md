# W3 — Lock Screen accessory widgets

**Branch:** `feature/w3-lock-widgets` · **PR into:** `develop` ·
**Review tier: B** (post-merge review) · **Depends on:** W1 merged

## Scope

Accessory-family widgets using the same `WidgetDataProvider` queries:

1. **accessoryCircular** — budget progress ring (percentage used).
2. **accessoryRectangular** — today's spent + budget remaining, two lines.
3. **accessoryInline** — "Spent $X today".
4. Render correctly in the Lock Screen's vibrant/tinted modes
   (`widgetRenderingMode`) — no hardcoded colors that vanish in vibrant
   mode.

**Privacy consideration (important):** amounts on the Lock Screen are
visible without unlocking the phone. Respect the system's
`privacySensitive` redaction for locked state: mark the amount views
`.privacySensitive()` so iOS redacts them when the device is locked and
"Show widget data when locked" is off. (Note: this is the correct use of
that modifier — unlike the in-app privacy shield, these views DO show
user data.)

## Non-goals

watchOS complications, StandBy-specific layouts, configuration.

## Acceptance criteria

- [ ] All three accessory families render on the iPhone simulator Lock
      Screen, legible in vibrant mode.
- [ ] Amounts are marked `.privacySensitive()` and redact when the device
      is locked (verify in simulator: lock the device, check the widget
      shows redacted placeholders).
- [ ] Values match the Home Screen widgets for the same dataset.

## Verification steps

1. Screenshots: each accessory family on the Lock Screen with demo data.
2. Screenshot of redacted state while device is locked.
3. `make test` summary.
