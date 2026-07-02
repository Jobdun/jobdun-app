# Jobdun — Legal Review Packet (Source of Truth)

> **Prepared:** 22 June 2026 · **Status:** DRAFT, not yet published or effective
> **For:** AU-admitted legal review before production launch
> **Documents enclosed:** Terms of Service v1.0, Privacy Policy v1.0, Account-Deletion policy

This single document is the source of truth for **every legal/compliance text in the
Jobdun application** (mobile app + website). It reproduces both governing documents
in full, plus the data and product context a lawyer needs to assess them, and a
consolidated checklist of every blank to fill and every clause flagged for review.
Nothing here is legal advice — the enclosed documents were drafted from Australian
statute and standard marketplace templates and explicitly require professional sign-off.

---

## 0. Brief for the reviewing lawyer

**What Jobdun is.** A mobile-first **two-sided marketplace** connecting Australian
construction **Builders** (who post jobs) with **Trades/Crews** (who apply). Jobdun is
an intermediary/platform — **not** an employer, labour-hire agency, or party to any
work agreement. It runs as a native **iOS + Android app** plus a **marketing website**
(`jobdun.com.au`). It is **free** today (no payments processed yet), **Australia-only**,
and **18+**.

**What we're asking you to do.**
1. Review and redline the **Terms of Service** and **Privacy Policy** (both reproduced below). Both documents' own preambles request this.
2. Resolve the items in **§2 (Lawyer action items)** — the blanks, the `[VERIFY WITH LAWYER]` clauses, and the gaps.
3. Advise on the **missing pieces** in §2C (e.g., website analytics/cookie coverage, in-app age gate, subprocessor data-processing agreements, content-moderation policy, future payment terms).

**Legal framework relied on.** *Privacy Act 1988* (Cth) + the 13 Australian Privacy
Principles (APPs); Australian Consumer Law (Sch 2, *Competition and Consumer Act 2010*
(Cth)); *Fair Work Act 2009* (Cth) (worker classification); *Spam Act 2003* (Cth);
the Notifiable Data Breaches scheme (Pt IIIC, Privacy Act). Stated governing law: **New
South Wales** (to confirm — see §2A).

**Indicative budget noted in the drafts:** AUD $1,500–3,500 for a one-time review.

---

## 1. Entity details to lock down (fill once — repeats throughout both documents)

| Item | Current value in the drafts | Action |
|---|---|---|
| Legal entity name | Jobdun Pty Ltd | Confirm exact registered name |
| **ABN** | `[PLACEHOLDER]` (blank everywhere) | **Provide** — appears in ~6 places |
| Registered address | `[PLACEHOLDER]` (blank) | **Provide** |
| Governing-law state | New South Wales (assumed) | **Confirm** the state of registration (Terms §24.1) |
| Privacy Officer email | `[PLACEHOLDER — privacy@jobdun.com.au]` | **Create + confirm** the mailbox is live (8 references) |
| Support email | `[PLACEHOLDER — support@jobdun.com.au]` | **Create + confirm** the mailbox is live (5 references) |
| Effective date | `[PLACEHOLDER]` (both docs) | Set on launch |
| Last-updated date | `[PLACEHOLDER]` (both docs) | Set on launch |
| Supabase data region | `[PLACEHOLDER — Singapore or Sydney]` | **Confirm with Supabase** (cross-border / APP 8) |

> There are 43 textual `[PLACEHOLDER]` instances across the documents, but they reduce
> to the ~9 unique facts above plus the dates. Fill each value once and it resolves
> everywhere.

---

## 2. Lawyer action items (consolidated)

### 2A. Blanks to fill
All covered by the table in §1. The only one that is a **legal decision** rather than a
data entry is the **governing-law state** (Terms §24.1): the draft assumes NSW courts /
NSW law; confirm against the company's actual state of registration and where most users
and disputes will sit.

### 2B. Clauses explicitly flagged for legal confirmation `[VERIFY WITH LAWYER]`

| # | Where | The question |
|---|---|---|
| 1 | Both preambles | Baseline sign-off of both documents before production. |
| 2 | Privacy §7.4 | Cross-border disclosure: are we relying on the **APP 8.2(b) consent carve-out** or the **APP 8.2(a) "reasonable steps"** pathway? The current wording mixes both. |
| 3 | Privacy §9 (retention table) | Is **7-year retention of verification documents** lawful and necessary, or excessive under APP 11.2 (destroy/de-identify when no longer needed)? |
| 4 | Privacy §16.1 | Confirm the **current NDB notification timeline** ("within 30 days of assessing as notifiable") against the Act as it stands. |
| 5 | Privacy — APP reference note | Confirm the assumption that **APPs 2, 4 and 9** are not engaged (anonymity, unsolicited PI, government identifiers). |
| 6 | Terms §18.4 | Confirm the **exact ACL non-excludable-guarantees carve-out phrasing**. |
| 7 | Terms §19 / §20 | **Liability cap (AUD $100) + indemnity**: check exposure to the **ACL unfair-contract-terms** regime for consumer / small-business users. |

### 2C. Gaps and missing pieces to advise on

1. **Website analytics / cookie coverage (current gap).** The Privacy Policy is written
   for the *native app* and states (§14.1) "we do not use traditional browser cookies."
   But the **`jobdun.com.au` website is now live and uses Vercel Web Analytics and Speed
   Insights** — cookieless, no advertising SDKs, but it still processes usage events and
   IP-derived data on the **web**. The policy currently does **not** mention the website
   at all. **Recommendation:** add a short web/cookie addendum (or expand scope to "app
   and website") covering Vercel analytics and any future web tooling.
2. **18+ age gate not enforced.** Both docs state users must be 18+, but there is no
   age-verification step in the app's sign-up flow. Advise on what enforcement (if any)
   is required.
3. **No Data Processing Agreements (DPAs).** The docs name subprocessors (Supabase,
   Google, Apple, Sentry, and now **Vercel** for the website) but no DPAs are executed.
   Advise which are needed (esp. Supabase, given cross-border storage).
4. **No published content-moderation / reporting policy.** Terms §10/§13 reference
   prohibited conduct and review removal, but there is no documented report flow, removal
   criteria, or appeal SLA.
5. **No payment / refund terms.** Terms §15 reserves the right to charge with 30 days'
   notice; refund/cancellation terms are required before any paid feature ships (Phase 2).
6. **No GDPR / CCPA equivalents.** Australia-only today. Flag what's needed if/when the
   product reaches EU or California users.
7. **Dispute mediation SLA.** Terms §17 says Jobdun offers limited, non-binding mediation
   and points users to state regulators; there is no defined SLA or escalation procedure.

---

## 3. Product, data and technical context (so the documents can be assessed in context)

**Roles.** Builders (post jobs, manage applicants), Trades/Crews (browse, quote, apply),
Admins (Jobdun staff — verify credentials, moderate, handle disputes).

**Personal information collected** (Privacy §2): identity (name, DOB, ID docs where
submitted), contact (email, AU mobile, address), **trade-verification data** (licence
numbers, insurance certificates, ABN, business name, qualifications, plus register-
confirmed business facts), profile data, job/application data, in-app messages, technical
data (device, OS, app version, IP, crash logs, session tokens), and location (suburb-level
by default; precise only with permission). **No payment data** is collected at this stage.

**How it's collected** (Privacy §3): directly from the user; automatically (device/
technical); and from third parties with consent — Google/Apple sign-in, the **Australian
Business Register (ABR)** for ABN checks, and **state licensing registers** for licence
checks.

**Subprocessors / data sharing** (Privacy §6.2, Terms §22):

| Provider | Purpose | Surface |
|---|---|---|
| Supabase Inc. | Database, auth, file storage | App + web backend of record |
| Google LLC | Google sign-in, FCM push, Maps | App |
| Apple Inc. | Sign in with Apple | App |
| Sentry | Crash/error monitoring | App |
| **Vercel Inc.** | Website hosting + **Web Analytics / Speed Insights** | Website (`jobdun.com.au`) — *not yet reflected in the Privacy Policy; see §2C.1* |

**Security** (Privacy §8): Postgres Row-Level Security on all tables; private storage
buckets with per-request signed URLs for verification/ID docs; bcrypt password hashing
(Supabase Auth); TLS in transit; encryption at rest; admin access logging.

**Retention & deletion** (Privacy §9, §13): 30-day soft-delete grace period, then hard
delete; messages kept 90 days; verification docs and legal-acceptance records kept 7 years.

**In-app legal-acceptance audit trail.** The app records each user's acceptance of each
document in an **immutable** database table (`legal_acceptances`: user, `document_type`
∈ {`terms_of_service`, `privacy_policy`}, `document_version`, timestamp, app version;
unique per user/type/version; no user UPDATE/DELETE). Document versions are tracked in
`assets/legal/versions.json` (both currently `1.0.0`). At sign-up an **un-pre-ticked**
checkbox records consent ("I agree to the Terms of Service and Privacy Policy"); a new
document version triggers a re-acceptance prompt. This is the mechanism that enforces the
"acceptance of these terms" referenced in Privacy §2.9.

**Account deletion** is self-service in-app (Settings → Account → Delete) via a
`SECURITY DEFINER` RPC that deletes the user's `auth.users` row (cascading to their data),
or by email to `ken@jobdun.com.au`. See Document C.

**iOS privacy manifest** (`PrivacyInfo.xcprivacy`) declares collection of email, phone,
name, coarse location, and photos/videos — all "linked, not used for tracking";
`NSPrivacyTracking = false`, no tracking domains.

---

# DOCUMENT A — Terms of Service (v1.0)

> Reproduced verbatim from `assets/legal/terms_of_service.md`. `[PLACEHOLDER]` and
> `[VERIFY WITH LAWYER]` markers are intentional and are the items for your review.

# Terms of Service

**Effective: [PLACEHOLDER — Ken to fill on first production release]**
**Last updated: [PLACEHOLDER — Ken totea fill]**
**Version 1.0**

---

> **Legal disclaimer:** This document was drafted using current Australian law and standard marketplace patterns as a strong starting template. **Before you ship to production, have an AU-admitted lawyer review both this document and the Privacy Policy.** Especially: licensing/registration claims for trades, dispute resolution, payment-handling clauses, and worker-classification language (independent contractor vs employee — critical in AU construction). Budget AUD $1,500–3,500 for a one-time review with a tech/privacy lawyer. This template gets you 85% of the way; the last 15% is jurisdiction-specific risk that needs a human lawyer.

## 1. Acceptance of Terms

**1.1** By creating a Jobdun account or using the Jobdun app, you agree to these Terms of Service ("Terms"). If you do not agree, you must not use Jobdun.

**1.2** You must be at least 18 years old to use Jobdun. By using our platform, you confirm that you meet this requirement.

**1.3** If you are using Jobdun on behalf of a business, company, or other legal entity, you warrant that you have the authority to bind that entity to these Terms. In that case, "you" and "your" refers to both you personally and the entity you represent.

**1.4** These Terms form a legally binding agreement between you and Jobdun Pty Ltd [PLACEHOLDER — Ken to fill ABN] ("Jobdun", "we", "us", "our").

## 2. About Jobdun

**2.1** Jobdun is a **marketplace platform** that connects Builders (who post jobs) with Trades and Crews (who apply for those jobs) in the Australian construction industry.

**2.2** Jobdun is **NOT** an employer, labour-hire agency, recruiter, or staffing company. Jobdun is not a party to any work agreement between a Builder and a Trade or Crew.

**2.3** Jobdun does not supervise, direct, control, or manage the work performed through connections made on our platform. Builders and Trades contract directly with each other.

**2.4** We provide tools to facilitate connections, but we are not responsible for the conduct, quality of work, or legal compliance of any user.

## 3. User Roles

**3.1 Builders** are businesses or individuals who post job opportunities on Jobdun and seek to engage Trades or Crews to perform construction, trade, or related work.

**3.2 Trades and Crews** are sole traders, contractors, or businesses who browse job listings and apply for work opportunities posted by Builders.

**3.3 Admins** are authorised Jobdun personnel who manage the platform, verify user credentials, moderate content, and handle disputes and support.

**3.4** Each user may register as either a Builder or a Trade/Crew. To switch roles, contact us at [PLACEHOLDER — support@jobdun.com.au].

## 4. Account Registration

**4.1** To use Jobdun, you must create an account and provide accurate, current, and complete information. You must keep your information up to date.

**4.2** You may only create one account per person or per ABN. Creating multiple accounts to circumvent suspensions or restrictions is prohibited and may result in permanent banning.

**4.3** You are responsible for maintaining the security of your account credentials. Do not share your password with anyone. You are liable for all activity that occurs under your account.

**4.4** If you believe your account has been compromised, notify us immediately at [PLACEHOLDER — support@jobdun.com.au].

**4.5** We reserve the right to verify your identity and eligibility at any time, and to suspend or terminate accounts that violate these Terms.

## 5. Trade Verification

**5.1** Jobdun offers a voluntary verification programme where Trades can submit licence documents, insurance certificates, and other credentials for review.

**5.2** Verification by Jobdun means only that we have reviewed copies of the submitted documents and they appeared valid at the time of review. **Verification is NOT a guarantee of a Trade's competence, quality of work, legal compliance, or current standing with any regulatory authority.**

**5.3** Builders remain fully responsible for conducting their own due diligence before engaging any Trade, including independently verifying licences, insurance, and compliance with applicable laws.

**5.4** If your verification documents expire or your credentials change, you must update your profile promptly. Maintaining false or outdated verification information is a breach of these Terms.

## 6. Licensing and Registration

**6.1** Australian trades are regulated at state and territory level. Depending on your trade and location, you may be required to hold a licence or registration issued by a body such as:

- **NSW:** NSW Fair Trading
- **Queensland:** QBCC (Queensland Building and Construction Commission)
- **Victoria:** VBA (Victorian Building Authority)
- **Western Australia:** WA Building Commission
- **South Australia:** Consumer and Business Services
- **Australian Capital Territory:** ACT Planning
- **Tasmania:** Consumer, Building and Occupational Services
- **Northern Territory:** NT Building Advisory Services

**6.2** By registering as a Trade on Jobdun, you **warrant** that you hold all required licences and registrations for the type of work you offer in the relevant jurisdiction(s). This warranty is ongoing — if your licence lapses, you must cease advertising those services on Jobdun until your licence is renewed.

**6.3** Making false or misleading claims about your licences or qualifications is a serious breach of these Terms and may constitute an offence under Australian consumer law. We will suspend your account immediately and, where required by law, report the matter to the relevant authority.

## 7. Worker Classification

**7.1 IMPORTANT: This clause protects both users and Jobdun.** By using Jobdun, Trades and Crews acknowledge that they operate as **independent contractors, sole traders, or businesses** — not as employees of Builders or of Jobdun.

**7.2** Nothing in these Terms or in any arrangement made through Jobdun creates an employer-employee relationship between Jobdun and any user, or between a Builder and a Trade.

**7.3** Australian law (including the *Fair Work Act 2009* (Cth)) applies a multi-factor test to determine whether a working relationship is truly one of contractor or employee. Relevant factors include: who sets the work hours and methods, whether the worker uses their own tools, whether the worker operates under their own ABN, whether GST is charged, whether the worker can sub-contract, and the degree of financial risk borne by the worker. **We do not provide legal advice. If you are uncertain about your classification for a particular engagement, seek independent legal advice before commencing work.**

**7.4** Trades using Jobdun are responsible for their own tax obligations (including GST if applicable), superannuation contributions, and insurance as required by law.

## 8. Posting Jobs (Builder Obligations)

**8.1** Builders must post accurate, truthful, and complete job descriptions. Misleading or deceptive job posts violate these Terms and may breach Australian Consumer Law.

**8.2** Builders must only post lawful work. You must not solicit work that is illegal, unsafe, or designed to circumvent any regulatory requirement (for example, unlicensed electrical work).

**8.3** Builders must not discriminate in job postings on the basis of race, colour, sex, gender identity, sexual orientation, age, disability, religion, ethnic origin, or any other characteristic protected under applicable Australian anti-discrimination legislation.

**8.4** Builders must not use Jobdun to request unpaid trial work or "spec" work without fair compensation.

**8.5** As a person who engages workers on a construction site, you acknowledge your obligations under the *Work Health and Safety Act 2011* (Cth) or equivalent state legislation. Safe sites are your responsibility.

## 9. Applying to Jobs (Trade Obligations)

**9.1** Trades must ensure their profiles, qualifications, and quotes are accurate and honest. Misrepresentation may result in account suspension and may constitute fraud.

**9.2** If you apply for and are accepted for a job, you are expected to fulfil that commitment. Repeatedly abandoning accepted jobs without reasonable cause may result in account restrictions.

**9.3** You must carry all required insurance (including public liability and income protection as appropriate for your trade) before commencing any work arranged through Jobdun.

**9.4** You are responsible for your own safety and the safety of others on any site you work on, in accordance with applicable WHS legislation.

## 10. Prohibited Conduct

The following are strictly prohibited on Jobdun:

**10.1** Fraud, deception, or misrepresentation of any kind.

**10.2** Harassment, threats, intimidation, or abusive behaviour directed at any user or Jobdun staff.

**10.3** Posting false reviews or manipulating the review system.

**10.4** Sharing another user's personal information without their consent.

**10.5** Scraping, crawling, or using automated tools to extract data from Jobdun.

**10.6** Posting spam, unsolicited commercial messages, or phishing links.

**10.7** Offering or accepting work that violates Australian law, including cash-in-hand arrangements designed to evade tax.

**10.8** Posting or sharing harmful, defamatory, obscene, or illegal content.

**10.9** Attempting to hack, disrupt, or damage the Jobdun platform or its infrastructure.

## 11. Off-Platform Circumvention

**11.1** Making initial contact through Jobdun and then deliberately taking the working relationship off-platform to avoid future platform fees or obligations is prohibited.

**11.2** This clause does not restrict you from maintaining an existing working relationship with a party you knew independently of Jobdun, prior to that party appearing on Jobdun.

## 12. Content Ownership and Licence

**12.1** You retain ownership of all content you submit to Jobdun, including profile information, photos, job posts, messages, and reviews ("Your Content").

**12.2** By submitting Your Content, you grant Jobdun a worldwide, non-exclusive, royalty-free, sublicensable licence to store, display, reproduce, and process Your Content for the purposes of operating, improving, and promoting the Jobdun platform.

**12.3** You warrant that Your Content does not infringe any third party's intellectual property rights and that you have all rights necessary to grant the licence above.

## 13. Reviews and Ratings

**13.1** Reviews must be honest and based on your genuine experience with the user being reviewed.

**13.2** Reviews must not be defamatory, harassing, or otherwise unlawful under Australian law.

**13.3** We may remove reviews that violate these Terms, but we are not obligated to do so. **Jobdun is not liable for user-submitted reviews under section 230 equivalents or the *Defamation Act* (applicable state/territory legislation)** — though we take all reports of defamatory content seriously.

**13.4** Attempting to manipulate the review system (e.g., trading positive reviews, commissioning fake reviews) is a serious breach and may result in account termination.

## 14. Messages and Communication

**14.1** Jobdun provides in-app messaging to facilitate communication between users. Keep all communications professional and respectful.

**14.2** Jobdun may access message content for moderation, safety investigations, fraud prevention, and legal compliance. By using in-app messaging, you consent to this access for these purposes.

**14.3** Do not use in-app messaging to send scams, illegal content, harassment, spam, or unsolicited commercial communications.

## 15. Fees

**15.1** Jobdun is currently free to use for all users (Phase 1).

**15.2** We reserve the right to introduce paid features or subscription tiers in the future. We will provide at least **30 days' written notice** (via email and in-app notification) to existing users before introducing any charges for previously free features.

**15.3** Where feasible, existing core features that have been free since a user's registration will remain accessible in some form, subject to fair-use limits, after the introduction of paid tiers.

## 16. Account Suspension and Termination

**16.1** We may suspend or terminate your account immediately without notice if we determine you have:

- Violated these Terms;
- Provided false or misleading information;
- Received a court order or regulatory direction requiring us to do so;
- Engaged in conduct that poses a risk to other users or the platform.

**16.2** In less serious cases, we may issue a warning or temporary suspension before permanent termination.

**16.3** If you believe your account has been suspended in error, you may appeal by contacting us at [PLACEHOLDER — support@jobdun.com.au] within 30 days of suspension. We will review and respond within 10 business days.

**16.4** Upon termination, your access to Jobdun ceases. Your data is handled in accordance with our Privacy Policy.

## 17. User-to-User Disputes

**17.1** Jobdun provides limited mediation assistance through our Admin team to help users resolve disputes. However, **Jobdun is not an arbitrator and our decisions are not legally binding**.

**17.2** Where disputes cannot be resolved through our mediation, users are encouraged to contact the relevant state fair trading or consumer protection body:

- **NSW Fair Trading:** fairtrading.nsw.gov.au
- **Consumer Affairs Victoria:** consumer.vic.gov.au
- **Queensland QBCC:** qbcc.qld.gov.au
- **WA Building Commission:** buildingcommission.wa.gov.au

**17.3** For trade licence complaints, contact the relevant state licensing authority listed in clause 6.1.

## 18. Disclaimers

**18.1** Jobdun is provided "as is" and "as available" without warranties of any kind, express or implied, including warranties of merchantability, fitness for a particular purpose, or non-infringement.

**18.2** Jobdun does not warrant the identity, conduct, competence, or quality of any user. We are a platform — we do not vet users beyond what is described in clause 5.

**18.3** We do not warrant that the platform will be uninterrupted, error-free, or virus-free.

**18.4** **Nothing in these Terms excludes, restricts, or modifies any consumer guarantee, right, or remedy provided under the *Australian Consumer Law* (Schedule 2 of the *Competition and Consumer Act 2010* (Cth)) that cannot lawfully be excluded.** [VERIFY WITH LAWYER — this exact phrasing is the ACL-required carve-out.]

## 19. Limitation of Liability

**19.1** To the maximum extent permitted by law, Jobdun's total liability to you for any loss or damage arising out of or in connection with these Terms or your use of the platform is limited to:

- (a) the resupply of the relevant service; or
- (b) the refund of any fees paid by you to Jobdun in the six (6) months before the event giving rise to the claim; or
- (c) AUD $100, whichever is greatest.

**19.2** Jobdun is not liable for:

- (a) any indirect, incidental, special, or consequential loss;
- (b) loss of income, revenue, profit, or business opportunity;
- (c) loss of data or goodwill; or
- (d) losses arising from the conduct of any user.

**19.3** This limitation does not apply to liability that cannot be lawfully excluded under the Australian Consumer Law.

## 20. Indemnity

**20.1** You agree to indemnify, defend, and hold harmless Jobdun, its officers, directors, employees, and agents against any claims, liabilities, damages, losses, and expenses (including reasonable legal fees) arising out of or related to:

- (a) your use of Jobdun in breach of these Terms;
- (b) any false, misleading, or inaccurate information you provide;
- (c) any dispute between you and another user;
- (d) your violation of any applicable law.

## 21. Intellectual Property

**21.1** The Jobdun name, logo, app code, design, and all associated intellectual property are owned by or licensed to Jobdun Pty Ltd. All rights are reserved.

**21.2** You must not reproduce, distribute, or create derivative works from Jobdun's intellectual property without our prior written consent.

## 22. Third-Party Services

**22.1** Jobdun uses the following third-party services to operate the platform:

- **Supabase Inc.** — database, authentication, and file storage
- **Google LLC** — Sign in with Google, push notifications (Firebase Cloud Messaging), and mapping
- **Apple Inc.** — Sign in with Apple
- **Sentry** — error monitoring

**22.2** These providers have their own terms and privacy policies. For detail on how your data is handled by these providers, see our Privacy Policy.

## 23. Modifications to Terms

**23.1** We may update these Terms from time to time. For material changes, we will provide at least **30 days' notice** via email and in-app notification before the new Terms take effect.

**23.2** For minor clarifications or corrections that do not materially affect your rights, we may update these Terms immediately and note the change.

**23.3** Your continued use of Jobdun after the effective date of updated Terms constitutes acceptance of the new Terms.

**23.4** If you do not agree with updated Terms, you may close your account at any time in Settings → Account → Delete Account.

## 24. Governing Law and Jurisdiction

**24.1** These Terms are governed by the laws of New South Wales, Australia [PLACEHOLDER — confirm with lawyer if registered in another state].

**24.2** You agree to submit to the non-exclusive jurisdiction of the courts of New South Wales for any disputes arising under these Terms.

## 25. Contact

For questions about these Terms, contact:

**Jobdun Pty Ltd**
ABN: [PLACEHOLDER — Ken to fill]
Email: [PLACEHOLDER — support@jobdun.com.au]
Address: [PLACEHOLDER — Ken to fill]

## 26. Severability

If any provision of these Terms is found to be unenforceable, that provision will be severed, and the remaining provisions will continue in full force and effect.

## 27. Entire Agreement

These Terms, together with our Privacy Policy, constitute the entire agreement between you and Jobdun regarding your use of the platform, and supersede all prior agreements or understandings.

*Jobdun Pty Ltd — [PLACEHOLDER — ABN] — [PLACEHOLDER — address] — [PLACEHOLDER — support@jobdun.com.au]*

---

# DOCUMENT B — Privacy Policy (v1.0)

> Reproduced verbatim from `assets/legal/privacy_policy.md`.

# Privacy Policy

**Effective: [PLACEHOLDER — Ken to fill on first production release]**
**Last updated: [PLACEHOLDER — Ken to fill]**
**Version 1.0**

---

> **Legal disclaimer:** This policy was drafted using the *Privacy Act 1988* (Cth) and the 13 Australian Privacy Principles (APPs) as the primary framework. **Before going to production, have an AU-admitted privacy lawyer review this document.** Key review areas: cross-border disclosure clauses (APP 8), retention periods, the NDB response timeline, and any payment-data clauses added when payments are introduced. Budget AUD $1,500–3,500 for a one-time review. [VERIFY WITH LAWYER] markers indicate clauses requiring professional confirmation.

## Your Rights — At a Glance

- **Access:** You can request a copy of your personal information at any time.
- **Correction:** You can correct your data in-app or by contacting us.
- **Deletion:** You can delete your account in Settings → Account → Delete.
- **Opt-out of marketing:** Unsubscribe at any time via in-app settings or the link in any marketing email.
- **Complaints:** Contact our Privacy Officer first; escalate to the OAIC if unresolved.

## 1. About This Policy

*(APP 1 — Open and transparent management of personal information)*

**1.1** This Privacy Policy explains how Jobdun Pty Ltd (ABN: [PLACEHOLDER]) ("Jobdun", "we", "us", "our") collects, uses, stores, and discloses personal information.

**1.2** This policy applies to all users of the Jobdun mobile app — Builders, Trades/Crews, and Admins — and to anyone who contacts us for support.

**1.3** We are committed to managing personal information in accordance with the *Privacy Act 1988* (Cth) and the Australian Privacy Principles (APPs).

**1.4** Our Privacy Officer can be reached at: [PLACEHOLDER — privacy@jobdun.com.au]

**1.5** This policy is available in-app (Settings → Legal → Privacy Policy) and linked from the registration screen.

## 2. What Personal Information We Collect

*(APP 3 — Collection of solicited personal information)*

We collect the following categories of personal information:

### 2.1 Identity Data
- Full name
- Date of birth (where provided for verification purposes)
- Copies of identity documents (where voluntarily submitted)

### 2.2 Contact Data
- Email address
- Mobile phone number (Australian format: +61)
- Business or home address (where provided)

### 2.3 Trade Verification Data
*(Collected only from users who submit verification)*
- Trade licence numbers and issuing authority (e.g., NSW Fair Trading, QBCC)
- Insurance certificates (public liability, professional indemnity)
- Australian Business Number (ABN)
- Business or trading name
- Qualifications and certifications

**Register-confirmed business details.** When you verify an ABN or licence, we record a curated set of facts returned by the relevant public register — your verified legal/entity name, ABN status, GST registration status, entity type, and business state/postcode, together with the date the check was performed ("as at"). These are sourced from the public registers in clause 3.3, not typed by you, and are shown as a "verified business" trust signal (see clause 6.1). We retain the full register response as an internal audit record; it is not shown to other users.

### 2.4 Profile Data
- Profile photo or avatar
- Trade specialties and skills
- Service area (suburb-level by default)
- Hourly rate or quoting preferences (optional)
- Portfolio images and project descriptions (optional)
- Ratings and reviews submitted by other users

### 2.5 Job and Application Data
- Job posts you create (as a Builder)
- Applications you submit (as a Trade)
- In-app messages between users
- Application status history

### 2.6 Technical Data
- Device identifier and model
- Operating system version
- App version
- IP address (collected at sign-in and key events)
- Crash logs and error reports (via Sentry — PII is scrubbed before transmission where technically feasible)
- Session tokens and authentication data

### 2.7 Location Data
- **Approximate location** (suburb-level): collected from your profile settings for job matching. You provide this directly.
- **Precise location**: collected only if you grant location permission for the "Jobs Near Me" feature. You can withdraw this permission at any time in your device settings.

### 2.8 Payment Data
Not collected at this stage. If payment processing is introduced, this policy will be updated with at least 30 days' notice.

### 2.9 Legal Acceptance Data
- Record of your acceptance of these terms (document type, version, timestamp, app version). Required for legal compliance and dispute resolution.

## 3. How We Collect Your Information

*(APP 3 — Collection; APP 5 — Notification of collection)*

**3.1** We collect personal information **directly from you** when you:

- Register an account
- Complete or update your profile
- Submit verification documents
- Post a job or apply for one
- Send in-app messages
- Contact our support team

**3.2** We collect information **automatically** when you use the app, including device and technical data (see clause 2.6).

**3.3** We collect information from **third parties** only with your consent, for example:

- **Google:** if you sign in with Google, we receive your name and email address from Google's OAuth service.
- **Apple:** if you use Sign in with Apple, we receive your name and Apple-generated email (or relay address).
- **Australian Business Register (ABR):** when you submit an ABN for verification, we query the ABR's public web services and receive your business's registered details (entity name, ABN status, GST registration, entity type, business state/postcode).
- **State licensing registers** (e.g., NSW Fair Trading, QBCC): when you submit a licence for verification, we check the relevant state regulator's public register to confirm the licence details.

Submitting an ABN or licence for verification constitutes your consent to these checks.

**3.4** This policy serves as our notification of collection as required by APP 5.

## 4. Why We Collect and How We Use Your Information

*(APP 6 — Use or disclosure of personal information)*

We use your personal information for the following purposes:

### 4.1 Primary Purposes (to operate the platform)
- Create and manage your account
- Verify trade licences and credentials
- Display your profile to other users
- Match Builders with relevant Trades and vice versa
- Facilitate in-app messaging
- Process job posts and applications
- Send transactional notifications (application updates, messages, job status changes)
- Provide customer support

### 4.2 Safety and Integrity
- Prevent fraud and abuse
- Investigate reports of prohibited conduct
- Comply with legal obligations and court orders

### 4.3 Platform Improvement
- Analyse aggregated, de-identified usage patterns to improve features
- Monitor app performance and fix errors (via Sentry crash reports)

**4.4** We will not use your personal information for a secondary purpose that is unrelated to the primary purpose without your separate consent, except where required or permitted by law.

## 5. Direct Marketing

*(APP 7 — Direct marketing)*

**5.1** We will only send you marketing communications (job alerts, platform updates, promotional emails, push notifications) if you have **opted in** at registration or subsequently in your account settings.

**5.2** Every marketing email contains an **unsubscribe link**. You can also manage notification preferences in Settings → Notifications at any time. Withdrawal of consent takes effect within 5 business days.

**5.3** Transactional messages — such as notifications about an application you submitted, a message you received, or a job you posted — are not considered "marketing" under the *Spam Act 2003* (Cth) and may be sent without a separate opt-in, as they are directly related to your use of the service.

## 6. Who We Share Your Information With

*(APP 6 — Disclosure; APP 8 — Cross-border disclosure)*

We share personal information only as follows:

### 6.1 Other Users (necessary for platform function)
- Builders see your public Trade profile when you apply for a job.
- Trades see your public Builder profile and job posting.
- In-app messages are visible to both parties in the conversation.
- Ratings and reviews are visible to all users.

### 6.2 Third-Party Service Providers (subprocessors)

| Provider | Purpose | Region | Privacy Policy |
|---|---|---|---|
| **Supabase Inc.** | Database, authentication, file storage | US/EU (data may be stored in Singapore or Sydney — [PLACEHOLDER — confirm with Supabase support]) | supabase.com/privacy |
| **Sentry** | Crash and error monitoring | US/EU | sentry.io/privacy |
| **Google LLC** | Sign in with Google; Firebase Cloud Messaging (push); Google Maps | US/global | policies.google.com/privacy |
| **Apple Inc.** | Sign in with Apple | US/global | apple.com/legal/privacy |

**6.3** We do **not** sell your personal information to third parties. Ever.

**6.4** We do not share your information for third-party advertising or data broker purposes.

**6.5** We may disclose your information where required by Australian law, a court order, or a lawful request from a regulator (e.g., OAIC, ACCC, AFP, state police).

## 7. Cross-Border Disclosure

*(APP 8 — Cross-border disclosure)*

**7.1** Your data is primarily stored on infrastructure operated by Supabase Inc. Data may be stored in [PLACEHOLDER — confirm Supabase region: Singapore or Sydney] and processed in the United States and/or European Union by Supabase's subprocessors (AWS, Cloudflare).

**7.2** Error logs are processed by Sentry, which operates in the United States and European Union.

**7.3** If you use Google or Apple sign-in, your name and email are transmitted to and from Google's or Apple's servers in the United States.

**7.4** Before disclosing your personal information to overseas recipients, we take reasonable steps to ensure the recipient handles it in a manner consistent with the Australian Privacy Principles. By accepting this policy, you consent to these cross-border disclosures. [VERIFY WITH LAWYER — the APP 8.2(b) consent carve-out vs. the APP 8.2(a) reasonable steps pathway]

## 8. Security of Your Personal Information

*(APP 11 — Security of personal information)*

**8.1** We implement the following security measures:

- **Row Level Security (RLS):** All database tables have RLS policies enforced. Users can only access their own data except where the platform requires broader access (e.g., public profiles, job listings).
- **Private storage buckets:** Verification documents, insurance certificates, and ID documents are stored in private, access-controlled buckets. Access requires a time-limited signed URL generated per request.
- **Authentication:** Supabase Auth manages credential storage with bcrypt hashing. We never store passwords in plain text.
- **Transport encryption:** All data in transit uses TLS (HTTPS).
- **Encryption at rest:** Supabase storage and database use encryption at rest.
- **Access logging:** Admin access to sensitive data is logged.

**8.2** No system is completely secure. If we become aware of a security incident affecting your data, we will notify you and, if required by the Notifiable Data Breaches (NDB) scheme, the OAIC — see clause 11.

## 9. Data Retention

*(APP 11 — Security; APP 13 — Correction)*

| Data Type | Retention Period | Reason |
|---|---|---|
| Active account data | While account is active | Operate the service |
| Deleted account — basic profile | 30 days post-deletion | Allow account restoration within grace period |
| Deleted account — in-app messages | 90 days post-deletion | Dispute resolution and legal claims |
| Verification documents (licences, insurance) | 7 years post-account deletion | Legal compliance, trade dispute history, regulatory requirements [VERIFY WITH LAWYER] |
| Crash logs (Sentry) | 90 days | Debugging and platform improvement |
| Database backups | Up to 30 days rolling | Disaster recovery |
| Legal acceptance records | 7 years | Legal compliance — proof of consent |

**9.1** After retention periods expire, data is deleted or de-identified.

## 10. Quality of Personal Information

*(APP 10 — Quality of personal information)*

**10.1** You can update most of your personal information at any time via your profile settings in the app.

**10.2** For data you cannot edit directly (e.g., email address linked to a social sign-in), contact our Privacy Officer at [PLACEHOLDER — privacy@jobdun.com.au].

**10.3** We do not independently reverify your personal details beyond what is described in clause 5 (Trade Verification), except where we have reason to believe information is inaccurate or misleading.

## 11. Access to Your Personal Information

*(APP 12 — Access to personal information)*

**11.1** You have the right to request a copy of the personal information we hold about you.

**11.2** To make an access request, email our Privacy Officer at [PLACEHOLDER — privacy@jobdun.com.au] with:
- Your full name
- The email address associated with your Jobdun account
- A description of the information you are seeking
- Proof of identity (a photo of your ID document)

**11.3** We will respond within **30 days**. In complex cases, we may request a 30-day extension and will notify you.

**11.4** We may decline to provide access in limited circumstances permitted by the *Privacy Act 1988* (Cth), such as where providing access would pose an unreasonable impact on another person's privacy or would prejudice law enforcement. We will explain any refusal.

**11.5** We do not charge a fee for access requests.

## 12. Correction of Personal Information

*(APP 13 — Correction of personal information)*

**12.1** You can correct most personal information directly in the app (profile settings).

**12.2** If you believe we hold personal information about you that is inaccurate, out-of-date, incomplete, or misleading, and you cannot correct it in-app, contact our Privacy Officer.

**12.3** We will take reasonable steps to correct the information within **30 days** of your request. If we disagree with the correction, we will tell you why and note your request for correction alongside the relevant information.

## 13. Deletion of Account and Data

**13.1** You can delete your account at any time in: Settings → Account → Delete Account.

**13.2** Account deletion results in:

- **Day 0–30:** Soft-delete (your account is deactivated but recoverable). Your profile is no longer visible to other users.
- **After 30 days:** Hard-delete of profile data, job posts, and applications. Data is deleted except where retention is required by clause 9.
- **Messages:** In-app messages are deleted after 90 days (to allow dispute resolution).
- **Verification documents:** Retained for 7 years as described in clause 9.
- **Legal acceptance records:** Retained for 7 years.

**13.3** To restore your account during the 30-day grace period, log in and follow the prompts.

## 14. Cookies and Tracking

**14.1** Jobdun is a native mobile app. We do not use traditional browser cookies.

**14.2** We use the following SDK-level identifiers and tracking:

- **Supabase session tokens:** stored securely on device to maintain your login session.
- **Firebase Cloud Messaging (FCM) token:** a device-level token used to send push notifications. Not linked to advertising.
- **Sentry SDK:** collects a device identifier for crash grouping. PII is scrubbed from crash reports where possible.

**14.3** We do not use advertising networks, cross-app tracking, or third-party advertising SDKs.

> **PACKET NOTE (not part of the published policy):** since this clause was written, the
> `jobdun.com.au` **website** launched with **Vercel Web Analytics + Speed Insights**
> (cookieless, no ads). This section does not yet cover the website. See §2C.1 of this packet.

## 15. Children's Privacy

**15.1** Jobdun is not intended for use by anyone under 18 years of age.

**15.2** We do not knowingly collect personal information from minors. If we become aware that a user is under 18, we will immediately suspend the account and delete any data collected.

**15.3** If you believe a minor has created a Jobdun account, please notify us at [PLACEHOLDER — privacy@jobdun.com.au] immediately.

## 16. Data Breach Notification

*(Notifiable Data Breaches (NDB) scheme — Part IIIC of the Privacy Act 1988)*

**16.1** If we become aware of a data breach that is likely to result in serious harm to you, we will:

- Promptly investigate the breach.
- If required, notify the **Office of the Australian Information Commissioner (OAIC)** within 30 days of the breach being assessed as notifiable. [VERIFY WITH LAWYER — confirm current NDB assessment timeline under the Act]
- Notify affected individuals as soon as practicable, including details of the breach and recommended steps to protect yourself.

**16.2** To report a suspected security or privacy incident: [PLACEHOLDER — privacy@jobdun.com.au]

## 17. Your Privacy Complaints

*(APP 1 — Complaints handling)*

**17.1** If you believe we have not handled your personal information in accordance with the Australian Privacy Principles, you may make a complaint.

**Step 1 — Contact us directly:**
Email: [PLACEHOLDER — privacy@jobdun.com.au]
We will acknowledge your complaint within 5 business days and respond within 30 days.

**Step 2 — If unresolved, escalate to the OAIC:**
Office of the Australian Information Commissioner
Website: oaic.gov.au
Phone: 1300 363 992
Post: GPO Box 5218, Sydney NSW 2001

## 18. Changes to This Policy

**18.1** We may update this Privacy Policy from time to time. For material changes (changes that meaningfully affect your rights), we will:

- Notify you via email at least **30 days** before the changes take effect.
- Display an in-app banner linking to the updated policy.
- Require you to acknowledge the updated policy before continuing to use the app.

**18.2** For minor clarifications, we may update the policy immediately.

**18.3** The "Last updated" date at the top of this document indicates when it was last changed.

## 19. Contact Us

For all privacy enquiries:

**Privacy Officer — Jobdun Pty Ltd**
ABN: [PLACEHOLDER — Ken to fill]
Email: [PLACEHOLDER — privacy@jobdun.com.au]
Address: [PLACEHOLDER — Ken to fill]

## Australian Privacy Principles Reference

| APP | Topic | Clauses in This Policy |
|---|---|---|
| APP 1 | Open and transparent management | 1, 17, 18 |
| APP 3 | Collection of solicited PI | 2, 3 |
| APP 5 | Notification of collection | 3.4 |
| APP 6 | Use or disclosure | 4, 6 |
| APP 7 | Direct marketing | 5 |
| APP 8 | Cross-border disclosure | 6.2, 7 |
| APP 10 | Quality of PI | 10 |
| APP 11 | Security of PI | 8, 9 |
| APP 12 | Access to PI | 11 |
| APP 13 | Correction of PI | 12 |

*APPs 2, 4, and 9 are not directly applicable to Jobdun at this stage: APP 2 (anonymity) — Jobdun requires identity for safety reasons; APP 4 (unsolicited PI) — address if/when unsolicited PI is received; APP 9 (government identifiers) — not applicable unless TFN handling is added.* [VERIFY WITH LAWYER]

*Jobdun Pty Ltd — [PLACEHOLDER — ABN] — [PLACEHOLDER — privacy@jobdun.com.au]*

---

# DOCUMENT C — Account-Deletion policy (published web page)

> Published at `jobdun.com.au/delete-account`. Required by Apple App Store and Google Play.

**Delete your account.** You can permanently delete your Jobdun account and the data
associated with it at any time, either directly in the app or by emailed request.

**Option 1 — in the app (immediate):** Open the Jobdun app and sign in → tap your avatar
to open the account sheet → tap **Settings → Delete account** → confirm. Your account is
removed immediately.

**Option 2 — by email:** Email `ken@jobdun.com.au` from the address registered to your
account with the subject "Jobdun account deletion request". We action requests within 30 days.

**What gets deleted:** your login and profile (name, photo, contact details, location);
your job posts, applications, quotes, bookings and timesheets; your messages and uploaded
photos and documents; your notification tokens and preferences.

**This cannot be undone.** Reviews you left for others remain (attributed to a deleted
account), and minimal records may be retained where required for legal, security or audit
purposes. Those records are de-identified from you.

*Note: the published web copy of this page describes immediate in-app deletion. The
Privacy Policy (§13) describes a 30-day soft-delete grace period before hard deletion.
**These two descriptions should be reconciled** — flag for the lawyer and engineering.*

---

## Appendix — where this lives, and how acceptance is enforced

**Canonical sources (version-controlled):**
- `assets/legal/terms_of_service.md` (v1.0.0)
- `assets/legal/privacy_policy.md` (v1.0.0)
- `assets/legal/versions.json` — `{ "terms_of_service": "1.0.0", "privacy_policy": "1.0.0" }`

**Published copies (must be kept in sync with the sources above):**
- Web: `marketing-site/app/privacy/page.tsx`, `marketing-site/app/delete-account/page.tsx` (live on `jobdun.com.au`)
- Legacy static HTML: `site/privacy/index.html`, `site/delete-account/index.html`
- In-app: loaded from the `assets/legal/*.md` bundle (Settings → Legal)

**Acceptance enforcement (in-app):**
- DB table `public.legal_acceptances` (migration `20260512000001_legal_acceptances.sql`): immutable record per user × document_type × version, with timestamp + app version; RLS lets a user read/insert only their own rows, admins read all (for disputes).
- Sign-up requires ticking a non-pre-checked consent box (AU law: pre-ticked consent is invalid).
- A new document version triggers a re-acceptance prompt before continued use.

**Account-deletion mechanics:** `delete_my_account` `SECURITY DEFINER` RPC
(migration `20260611000001_delete_my_account.sql`) deletes the caller's `auth.users` row,
cascading to their data.

**App-store compliance:** `ios/Runner/PrivacyInfo.xcprivacy` declares the collected data
types (email, phone, name, coarse location, photos/videos — linked, not tracking).

---

*End of packet. To send: export this file to PDF (or attach the `.md`) and email to your
reviewing lawyer along with §0 (the brief) and §2 (the action items).*
