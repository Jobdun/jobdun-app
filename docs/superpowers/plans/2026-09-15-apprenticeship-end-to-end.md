# Apprenticeship jobs end-to-end implementation

**Goal:** Complete the authorised apprentice experience from vacancy creation through discovery, application and builder review, and produce verified release artifacts.

**Design:** Extend the existing jobs lifecycle with `job_kind` (`trade_job` default, `apprenticeship`). A dedicated apprenticeship is always open to apprentices and uses an employer-set positive hourly amount. Existing trade jobs may separately invite apprentices. Reuse description for training, hours and experience requirements, the trade picker for occupation, and existing private resumes and applications. Do not invent a parallel hiring or payment system.

**Architecture:** Keep domain contracts independent of Flutter. Database constraints enforce valid apprenticeship pricing and invitation flags. Append the field to the public browse view, Edge Function projection, model and disk caches. Filter before pagination; preserve filters across searches. Application submission stays in the existing application repository and server lifecycle. No quote requested for dedicated apprenticeships or apprentices applying to invited trade work; the builder reads the applicant's profile and relationship-gated resume.

**UI:** Existing Jobdun design system, UI/UX Pro Max and Impeccable product register. Listing kind in step one; hourly pay in step two. Feed filters for all jobs, apprenticeships and open-to-apprentices jobs. Distinct neutral badges on feed, saved, home, builder and detail surfaces. Form errors inline, loading guarded, empty state reset action.

**Execution:** Use subagent-driven-development for the bounded creation/application UI task while the parent implements domain, filtering and database integration. All edits remain uncommitted as instructed. Preserve the existing dirty release work.

- [x] Add failing model/filter/constraint/application tests.
- [x] Implement job kind, filters, data projections and cache support; migration and rollback.
- [x] Implement creation and application UI with widget tests.
- [x] Wire discovery filters and badges through every job display and navigation payload.
- [x] Check profile completeness, resume access and builder application lifecycle; repair demonstrated gaps.
- [x] Run focused tests, SQL regression checks, complete validation, and independent spec/code review.
- [x] Build and run Android emulator; capture and inspect real flow screenshots.
- [x] Build signed Android release, document exact backend/artifact/store status and remaining external requirements.

## Verification cases

Legacy JSON defaults to trade work. Apprenticeship persists through database and offline-cache serialization. Filter combinations survive trade/search changes and query before range pagination. Dedicated apprenticeships require positive finite hourly employer-set pay and invitation flag. Apprentice application submits no quote and handles retry/double taps. Unrelated builders cannot read private resumes; the receiving builder can review an applicant. Existing ordinary trade quote applications keep working. All mobile changes require actual emulator screenshots before completion.
