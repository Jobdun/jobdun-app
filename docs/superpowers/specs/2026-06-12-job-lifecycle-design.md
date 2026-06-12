# Job Lifecycle — End-to-End Design

**Date:** 2026-06-12 · **Status: awaiting user review — no code written**
**Follows:** the 2026-06-12 lifecycle audit (gap #2). Reviews loop (gap #1)
already shipped on `feat/notifications-live` and is re-timed by this design.

---

## Decisions locked with the user

| # | Decision | Choice |
|---|----------|--------|
| 1 | Tradies per job | **One** (`jobs.hired_trade_id`, single column). Multi-hire crews deferred. |
| 2 | Losing applicants on hire | **Soft outcome** — shown as "JOB FILLED", never "Rejected". |
| 3 | Who marks a job done | **Builder confirms; tradie can request.** Builder's tap is the only authoritative close. 7-day auto-close timer = deferred phase 3. |

## Goal

Make the existing five-state enum real. Today the only lifecycle in practice is
`open → deleted`: hiring changes nothing on the job, other applicants hang
forever, the feed keeps showing decided jobs, the builder's Filled/Closed tabs
are permanently empty, and reviews fire at hire instead of at completion.

Target invariants (what Airtasker/hipages get right):

1. Hiring's side-effects are **automatic** — no "mark as filled" chore.
2. A filled job **leaves the feed instantly** and can't be applied to.
3. Losing applicants are **auto-resolved and notified softly**.
4. **Completion is one builder tap**, and *that* unlocks reviews — both sides.
5. Both parties always see the same status, dual-encoded.

**No new enum states.** `draft, open, filled, closed, cancelled` already exist
in DB and Dart; we wire transitions, not vocabulary. (`in_progress` was
considered and rejected — derivable later from timesheets as a "STARTED" chip.)

---

## The state machine

```
            createJob                 hire applicant            MARK JOB DONE
  (draft) ───────────► open ────────────────────► filled ────────────────► closed
                         │        (automatic,                (builder tap;
                         │         DB trigger)                tradie can request)
                         │
                         └──────► cancelled   (builder taps CANCEL JOB;
                                               only from open)
```

- `draft` stays reachable-in-schema but out of scope (no draft UI today; the
  create form publishes straight to `open` — unchanged).
- `filled → cancelled` is **not** allowed in v1 (un-hiring is a dispute flow,
  not a status flip). If a hire goes wrong pre-completion, that's support/admin
  territory for now — documented limitation.
- DELETE (soft-delete) remains only for jobs with **zero applications**; a job
  with applicants must go through CANCEL so applicants get told. Existing
  delete confirm sheet branches on `application_count`.

### Transition table

| Transition | Trigger | Mechanism | Side-effects |
|---|---|---|---|
| open → filled | Builder hires an applicant | **DB trigger** on `applications` UPDATE to `hired` | `jobs.status='filled'`, `hired_trade_id=NEW.trade_id`, `filled_at=now()`; all other non-terminal applications on the job → soft-resolved; `job_filled` notifications to losers; double-hire guard |
| filled → closed | Builder taps MARK JOB DONE | App: `CloseJob` use case → `updateJobStatus` (already exists, currently dead) | `closed_at=now()`; `review_prompt` notifications to both parties; review CTA unlocks |
| open → cancelled | Builder taps CANCEL JOB | App: `CancelJob` use case → `updateJobStatus` | `job_cancelled` notifications to all non-terminal applicants (soft copy). Cancelled jobs are already invisible to browsers — the RLS browse policy only exposes open+filled |
| tradie requests done | Tradie taps WORK'S DONE? | App: `RequestJobCompletion` use case | `jobs.completion_requested_at=now()` (idempotence guard, one live request) + `completion_requested` notification to builder |

---

## DB changes (one migration + rollback, pushed to `zethpanvkfyijislxesn`)

1. **Columns:** `jobs.filled_at timestamptz`, `jobs.closed_at timestamptz`,
   `jobs.completion_requested_at timestamptz` (all nullable).
2. **Application soft outcome:** `ALTER TYPE application_status ADD VALUE
   'job_filled'`. Sits in its own migration file (PG allows ADD VALUE in a
   transaction only if unused in the same transaction — keep the trigger that
   references it in the *next* migration file to be safe).
3. **Hire cascade trigger** `applications_hire_cascade` (AFTER UPDATE OF status
   ON applications, WHEN NEW.status='hired'):
   - **Guard:** if the job is already `filled`/`closed`/`cancelled`, RAISE —
     this is the double-hire protection (two applicants can't both be hired;
     decision 1).
   - `UPDATE jobs SET status='filled', hired_trade_id=NEW.trade_id,
     filled_at=now() WHERE id=NEW.job_id AND status='open'`.
   - `UPDATE applications SET status='job_filled' WHERE job_id=NEW.job_id AND
     id<>NEW.id AND status IN ('pending','shortlisted')` (withdrawn/rejected/
     declined stay as they are).
   - Notifications to each soft-resolved applicant: type `job_filled`, title
     "Job filled", body "'<job title>' has been filled — more jobs are waiting",
     data `{job_id}`. The central push fanout (20260609000007) delivers.
     `notification_category()` currently maps only `new_job` to the 'jobs'
     preference bucket, so `job_filled`/`job_cancelled` would land in 'other' —
     **extend the 'jobs' branch of `notification_category()`** in the same
     migration so these respect the user's jobs push preference.
   - SECURITY DEFINER, `search_path=''`, mirroring `notify_on_new_message`.
4. **Existing producer interplay:** `20260609000010` already notifies the hired
   tradie on `application_status` — unchanged. The cascade only adds the
   losers' notifications and the job flip.
5. **`published_at` cleanup (small, same migration set):** stamp
   `published_at=now()` in `createJob`'s insert (app change) and drop the
   read-time patch in the datasource — closes the long-standing gotcha.
6. **Review timing is NOT DB-enforced** in v1 (reviews RLS unchanged); the
   gating is app-side (see Review section). DB-level "review only after closed"
   CHECK is listed under Hardening.

## App changes

### Jobs feature

- **Feed:** default the public browse query to `status='open'` (builder's
  "your listings" scope keeps all statuses). APPLY button + apply sheet gate on
  `job.status == open`; non-open deep-linked detail shows an
  "APPLICATIONS CLOSED" state instead of the CTA.
- **Use cases (new, thin):** `CloseJob`, `CancelJob`, `RequestJobCompletion` —
  all over the existing repo (`updateJobStatus` + one new repo method for the
  completion request). Controller calls use cases per house rule.
- **Builder detail/listings (filled job):** primary action `MARK JOB DONE`
  (confirm sheet: "Mark 'Deck build' as done? This closes the job and asks both
  of you to rate each other."), secondary `VIEW APPLICANTS` remains. A banner
  appears when `completion_requested_at` is set: "Mick says the work's done."
- **Builder detail/listings (open job):** `CANCEL JOB` (replaces DELETE when
  `application_count > 0`), confirm sheet explains applicants are notified.
- **Status chips recolor:** `filled` moves from brand orange → **warning amber**
  (`c.warning*` pair) per MASTER's "orange is action, not status" rule;
  `closed` stays neutral; Filled/Closed tabs now actually populate.

### Applications feature

- Dart `ApplicationStatus` gains `jobFilled` ↔ `'job_filled'`, label
  **"JOB FILLED"**, neutral/soft chip (never the error red of Rejected).
  `fromDb` updated in lockstep with the enum migration.
- **Tradie hired card:** new `WORK'S DONE?` secondary action → confirm sheet →
  `RequestJobCompletion`. After requesting (or when `completion_requested_at`
  set): static "Waiting for the builder to confirm" row. Hidden once closed.
- Card already joins `jobStatus` — used for the review gate below.

### Reviews re-timing (adjusts what shipped this morning)

- `ReviewCta` on hired cards now renders only when `app.jobStatus == closed`.
  While `filled`, the slot shows the completion affordance instead (builder:
  MARK JOB DONE shortcut; tradie: WORK'S DONE? / waiting row). The CTA itself,
  sheet, dedupe, and `review_received` notification are unchanged.

### Notifications

- New producer copy rides the existing central rail; **route resolver**
  additions: `completion_requested` → `/jobs/:jobId` (builder lands on the job
  to confirm), `job_filled` / `job_cancelled` → `/jobs` feed ("keep looking"),
  `review_prompt` → `/applications` (where the CTA lives).
- `review_prompt` producer fires on `closed` for **both** parties from the
  close transition (DB trigger on jobs status change to closed, or emitted by
  the same `CloseJob` path — decision: **DB trigger on jobs**, consistent with
  producers-in-DB).

## Edge cases

- **Double hire:** blocked by the cascade guard; the app surfaces the failure
  as "This job has already been filled."
- **Hired tradie withdraws after fill:** out of scope v1 (same dispute bucket
  as un-hiring); WITHDRAW hidden on hired applications (already terminal).
- **Builder deletes a filled job:** delete hidden once `status != open`;
  cancel hidden once filled. Closed/cancelled jobs are immutable except
  soft-delete of *cancelled* ones with no applicants.
- **Completion request spam:** one live request (`completion_requested_at`
  null-check); re-request allowed only if the builder hasn't acted in 48h
  (cheap client check; no extra schema).
- **Offline:** all transitions are simple writes through the repo; failures
  surface as snackbars, no optimistic job-status flips (status is too
  load-bearing to fake locally).
- **Account deletion:** `hired_trade_id` already `ON DELETE SET NULL`
  (20260611000003); a filled job whose tradie deletes their account stays
  filled and closable.

## Phasing

- **Phase 1 — the pivot (DB-heavy):** migrations (columns, enum value,
  category fn, hire cascade + guard, loser notifications), Dart enum +
  `fromDb`, feed default filter, APPLY gating, `published_at` cleanup.
  *Outcome: hiring fills the job, feed is honest, losers are told.*
- **Phase 2 — the close (app-heavy):** `CloseJob`/`CancelJob`/
  `RequestJobCompletion` use cases + UI on both roles, review-CTA re-timing,
  `review_prompt` + `completion_requested` producers, chip recolor, tabs.
  *Outcome: jobs end, reviews fire at the right moment.*
- **Phase 3 — deferred:** 7-day auto-close via pg_cron (pattern exists in
  verification sweeps), derived "STARTED" chip from timesheets, multi-hire,
  un-hire/dispute flow, DB-level review-after-closed CHECK + reviews RLS
  hardening (tie reviewer to the job's parties).

## Testing

- **DB:** SQL smoke on a branch/staging path is impractical here — verify the
  cascade with a scripted Supabase SQL check post-push (hire one of three
  applicants → assert job filled + two `job_filled` rows + notifications).
- **Dart:** unit tests for the three use cases; widget tests: APPLY hidden on
  non-open job, hired card shows WORK'S DONE? then waiting row, ReviewCta
  hidden while `filled` / shown when `closed`; resolver tests for the three
  new routes; `ApplicationStatus.fromDb('job_filled')` round-trip.
- Gate: `bash scripts/validate.sh` green per phase; phases land as separate
  commits on a `feat/job-lifecycle` branch.

## Out of scope (explicit)

Payments/invoicing, multi-hire crews, un-hire flow, `in_progress` enum state,
draft-job UI, auto-close timer (phase 3), reviews RLS hardening (phase 3),
admin-web lifecycle surfaces.
