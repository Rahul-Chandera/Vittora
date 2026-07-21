# T1 — Themes: OLED black + accent colour

**Branch:** `feature/t1-themes` · **PR into:** `develop` ·
**Review tier: B** (post-merge review)

## Context

Plan M3.7.3. Today `AppearanceMode` offers light / dark / system only.
Adds a true-black variant (meaningful battery win on OLED iPhones, and a
frequently requested option) and a small accent-colour choice.

## Scope

1. Extend the existing `AppearanceMode` (do **not** invent a parallel
   settings mechanism) with **OLED black**: pure `#000000` backgrounds,
   elevated surfaces as near-black greys, applied through `VColors`
   tokens rather than per-screen overrides.
2. **Accent colour** picker — brand green (default) plus a small fixed set.
   Applies to primary buttons, selection, progress fills. Must flow through
   `VColors`/the design tokens so widgets and the watch app inherit it
   where they already read those tokens.
3. Settings UI grouped under Appearance, with a live preview so the choice
   is visible before committing.
4. Persist via the existing settings/UserDefaults pattern; mirror to the
   App Group **only if** widgets need it (check before adding a key —
   there is already a currency mirror; follow that pattern, don't invent).

## Non-goals

Fully custom user-picked colours, per-screen themes, theme scheduling by
time of day, redesigning the design-token system.

## Contrast requirement (this is the part that can regress)

P1 fixed WCAG AA contrast across the app and locked it with
`AccessibilityAuditUITests`. **Every new theme must satisfy the same 4.5:1
bar for text**, and those audit tests must pass under each theme, not just
the default. Do not ship an accent that fails contrast on the OLED
background.

## Acceptance criteria

- [ ] OLED black and each accent option render correctly on
      iPhone/iPad/Mac; screenshots of dashboard + a report in each.
- [ ] Contrast: state the computed ratio for body and secondary text on
      the OLED background in the PR (must be ≥ 4.5:1). The reviewer will
      recompute.
- [ ] `AccessibilityAuditUITests` pass **under the new themes**, not only
      the default — extend the audit to cover at least OLED black.
- [ ] Widgets/watch do not regress: verify they still render correctly
      (they read the shared tokens).
- [ ] Setting persists across relaunch; unit test for the persistence.
- [ ] `make test` green.
