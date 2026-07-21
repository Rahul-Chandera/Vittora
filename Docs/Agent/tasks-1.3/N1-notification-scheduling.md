# N1 — Notification scheduling & quiet hours

**Branch:** `feature/n1-notification-scheduling` · **PR into:** `develop` ·
**Review tier: B** (post-merge review)

## Context

Plan M3.7.7. Per-type toggles already exist (`notifyBillsDue`,
`notifyBudgetAlerts`, `notifyGoalMilestones`, `notifyRecurring`) and
`NotificationService` schedules them. What's missing is **when**: users
can only turn a type off entirely, which is why finance apps get muted.

## Scope

1. **Preferred delivery time** for digest-style notifications (bill
   reminders, recurring items) — a single daily time, default 09:00 local.
2. **Quiet hours** — a start/end window during which no Vittora
   notification fires; anything that would fire inside the window is
   deferred to the window's end, not dropped.
3. **Lead time for bill reminders** — how many days before due (default
   existing behaviour; offer e.g. same day / 1 / 3 days).
4. Settings UI grouped with the existing notification toggles; keep the
   per-type switches working exactly as now.
5. Rescheduling: changing any of these must **reschedule already-pending
   notifications**, not just apply to future ones. This is the part most
   likely to be wrong — a user who moves quiet hours should not still get
   last night's scheduled alert.

## Non-goals

Per-category notification rules, push notifications from a server (there
is no server), rich/actionable notification buttons, changing what the
notifications say.

## Correctness requirements

- Times are **local** and must survive a timezone change — compute against
  the current calendar/timezone at schedule time, and reschedule on
  significant time change. Add a test with an injected timezone.
- Quiet-hours windows that **cross midnight** (e.g. 22:00–07:00) must work.
  This is the classic off-by-one; test it explicitly in both directions.
- Deferral must not stack duplicates: a notification deferred out of quiet
  hours fires **once**, not once per reschedule pass. Test it.

## Acceptance criteria

- [ ] Settings expose delivery time, quiet hours, and bill lead time; the
      existing per-type toggles still work.
- [ ] Unit tests: quiet hours crossing midnight (both a time inside and
      outside the window); deferral fires exactly once; changing settings
      reschedules pending notifications; injected-timezone case.
- [ ] Verify on simulator that a scheduled notification actually lands at
      the configured time (use a near-future time), with a screenshot.
- [ ] Existing notification behaviour unchanged when the new settings are
      left at defaults — a regression test for that.
- [ ] `make test` green.
