# License posture — accept MPL-2.0 / LGPL-3.0-or-later transitive packages

> In the context of the 2026-05-20 dependency audit flagging 27 transitive packages under restricted licenses (MPL-2.0 + LGPL-3.0-or-later) in `ecommerce-accountant-software`, facing the absence of any prior documented posture and a backlog ticket [#153] asking for one, I decided to **accept the current transitive-license posture as engineering risk documentation conditional on the project's current hosted-only / no-distribution shape**, in order to close out the audit cycle without ripping out load-bearing build / image / a11y dependencies, accepting that this acceptance is non-eternal and that formal legal review is required before any change to the project's distribution shape.

> **This AgDR is engineering risk documentation, not legal advice.** It is a founder-authored portfolio-side record of the project's current distribution shape and the conditions under which the documented MPL-2.0 / LGPL-3.0-or-later transitive-dependency posture is acceptable. Before any change to that shape — public SaaS launch, source distribution, binary distribution, on-prem installer, Electron / desktop app, or shipping `node_modules` to customers — a formal legal review and a superseding AgDR are required.

## Context

This AgDR is the **Phase-2 portfolio-side record** that pairs with the Phase-1 entry now landed in the project repo as `docs/DECISIONS_LOG.md` § 21 (PR [GOkasha/ecommerce-accountant-software#167](https://github.com/GOkasha/ecommerce-accountant-software/pull/167), squash commit `36592a3d`, merged 2026-05-22). The Phase-1 entry is the in-project, code-adjacent record; this AgDR is the portfolio-wide, cross-project record discoverable via `/agdr search license` from any other ApexYard-managed project.

**Audit findings recap.** The 2026-05-20 audit (`projects/ecommerce-accountant-software/dep-audit-2026-05-20.md` § 5 "License findings") recorded:

- **27 transitive packages under restricted licenses** — all reached through `next` (build-time CSS via `lightningcss`, runtime image processing via `sharp` / `libvips` native binaries) plus the dev-only `axe-core` a11y tool.
- **Zero direct dependencies** under restricted licenses. The project's own `package.json` declares no MPL-2.0 / LGPL-3.0 dependency.
- **Zero banned licenses** — no GPL standalone, no AGPL, no CDDL, no EPL, no proprietary, no unknown.

**Project shape this AgDR conditions on.** `ecommerce-accountant-software` is a founder-operated, single-business **internal hosted web app** (Next.js server-side, Postgres-backed, hosted Node/Next.js deployment target). No source distribution. No binary distribution (no Electron / no on-prem installer / no shipping `node_modules`). Single-tenant; no current plan to multi-tenant SaaS (see app `docs/DECISIONS_LOG.md` § 1 — "Single business now, future-ready").

**License obligations recap.**

- **MPL-2.0** (`lightningcss`, `axe-core`) — file-level copyleft; source-disclosure obligation activates only when an MPL-licensed file is *modified* and *distributed*. The project does neither.
- **LGPL-3.0-or-later** (`sharp`, `libvips` native binaries) — re-link obligation activates only on distribution. A hosted server-side application that serves HTTP responses does not constitute "distribution" of the library in LGPL's sense.
- **Compound `Apache-2.0 AND LGPL-3.0-or-later`** (`@img/sharp-wasm32`, `@img/sharp-win32-*`) — both terms apply. Apache-2.0's attribution requirement becomes load-bearing on any future binary-shipping shape (handled by the follow-up `THIRD_PARTY_NOTICES` chore below).

**Stakeholder context.** The founder is wearing both operator and legal hats. The audit explicitly framed this finding as "a 30-minute legal review file, not a stop-the-build finding." This AgDR documents the engineering-side risk view; it is not a substitute for formal legal counsel. A formal legal pass is required before any change to the project's distribution shape.

**Prior-art linkage.** [`AgDR-0001-apexyard-vs-project-claude-md.md`](AgDR-0001-apexyard-vs-project-claude-md.md) established the boundary that in-project decisions go in app `docs/DECISIONS_LOG.md` and cross-layer / portfolio-visible decisions go here in the ops fork. This is the first license-posture entry under that boundary, and the format other managed projects can reuse when their own audits surface comparable findings.

## Options Considered

| Option | Pros | Cons |
|---|---|---|
| **A. Accept the posture, documented, conditional on the current no-distribution hosted shape** (chosen) | Closes #153 without disrupting load-bearing build / image / a11y deps. Matches the audit's own characterisation as a "vanilla commercial-Node profile". Cheap (markdown only). Re-evaluable on every future `/audit-deps` cycle. Surfaces the conditions explicitly so a future distribution-shape change forces the legal-review conversation, not a silent breach. | Acceptance is non-eternal; every future audit must re-read this entry. Future distribution-shape change forces formal legal review and a superseding AgDR. Operator carries the engineering-side judgement until then. |
| **B. Replace the restricted-license packages with MIT-only alternatives** | Eliminates the entire MPL / LGPL surface. Removes "what about these licenses?" from every future audit. | `lightningcss` is `next`'s built-in CSS optimiser; `sharp` is what `next/image` uses for image transforms; `axe-core` is the JS-ecosystem standard a11y tool. Ripping any of them out means forking Next or pinning inferior alternatives — strictly worse functional outcome than the documented posture. Weeks of work for zero distribution-shape benefit. |
| **C. Defer until formal legal review** | Removes any engineering-side judgement on a legal-shaped question. Cleanest "stay in your lane" angle. | The founder *is* the legal stakeholder for this project. Deferring without a counterparty turns into indefinite blocking. Every future audit re-surfaces the same 27 packages with no context, no remediation path, and no signal that "we've thought about this and chose to accept the conditions." Adds zero safety for an internal hosted app. |
| **D. Add `npm overrides` to swap problematic packages on a per-package basis** | Surgical removal of specific licenses without rewriting the build. | Forces `lightningcss` / `sharp` to versions `next` does not pin. Risks subtle CSS-output and image-pipeline regressions in production. Higher blast radius than the moderate-on-build-tooling-only residual it would resolve. Same anti-pattern the project already rejected for the postcss residual (see app `DECISIONS_LOG.md` § 20 — "Accepted risk — postcss <8.5.10"). |

## Decision

Chosen: **Option A — accept the posture, documented, conditional on the project's current no-distribution hosted shape**, because the dependency profile is the industry-standard "vanilla commercial-Node" shape; the load-bearing alternative (B) destroys working tooling; the procedural alternative (C) blocks indefinitely for an internal hosted app whose founder is the legal stakeholder; and the surgical alternative (D) trades a documented residual for a larger build-regression risk.

**Concretely:**

1. App-side record landed: `docs/DECISIONS_LOG.md` § 21 — "License posture — MPL-2.0 / LGPL-3.0-or-later transitive packages (vanilla commercial-Node profile)" — PR [#167](https://github.com/GOkasha/ecommerce-accountant-software/pull/167), squash commit `36592a3d`, merged 2026-05-22.
2. Portfolio-side record: **this AgDR**.
3. Follow-up `[Chore]` (to be filed in `GOkasha/ecommerce-accountant-software`): add `THIRD_PARTY_NOTICES.md` at the repo root OR a `/legal/attributions` route in the admin UI **before first production, public, customer-facing, or distributed deployment**. Covers the Apache-2.0 attribution obligation in the compound `sharp` packages and pre-positions the project for any future distribution-shape change.
4. Umbrella [#148](https://github.com/GOkasha/ecommerce-accountant-software/issues/148) stays OPEN until a closing comment summarises: High findings cleared, [#152](https://github.com/GOkasha/ecommerce-accountant-software/issues/152) postcss residual formally accepted (app `DECISIONS_LOG.md` § 20), [#153](https://github.com/GOkasha/ecommerce-accountant-software/issues/153) license posture signed off (this AgDR + app `DECISIONS_LOG.md` § 21), and any remaining accepted/documented risks tracked.

**Conditions of acceptance:**

- No modification of any file inside `node_modules/lightningcss/`, `node_modules/axe-core/`, `node_modules/@img/sharp-*/`, or any `libvips` binary. Modifying MPL-2.0 source triggers MPL's file-level source-disclosure obligation.
- No `npm overrides` in `package.json` swapping the restricted-license packages without a superseding AgDR AND a full Next.js production-build integration test.
- No public SaaS launch, source distribution, binary distribution, on-prem installer, Electron / desktop app, mobile app embedding, or shipping `node_modules` to customers without a **formal legal review** and a superseding AgDR.
- No new **direct** dependency under MPL-2.0, LGPL-3.0-or-later, GPL-2.0, GPL-3.0, AGPL, CDDL, EPL, or unknown / proprietary licenses without an explicit `package.json` comment block referencing this AgDR AND an updated audit pass.
- Each future ApexYard `/audit-deps` cycle re-reads this AgDR and either re-affirms or files a superseding record.

**Re-evaluation triggers (any one fires this AgDR's revisit):**

1. The project's distribution shape changes (public SaaS, multi-tenant, source distribution, binary distribution, on-prem installer, Electron / desktop, mobile embed, shipping `node_modules` to a third party). **Formal legal review required** at that point.
2. A new restricted-license package is introduced — direct or transitive, runtime or dev — under MPL-2.0, LGPL-3.0-or-later, GPL-2.0, GPL-3.0, AGPL, CDDL, EPL, or unknown / proprietary.
3. `next` removes `lightningcss` / `sharp` in a future major (16.x → 17.x → …), or one of these packages re-licenses to an MIT-equivalent shape.
4. The follow-up `THIRD_PARTY_NOTICES` `[Chore]` lands — append a "Status update" subsection here linking the chore PR (do not edit the decision itself).
5. The next ApexYard `/audit-deps` cycle runs — confirm acceptance still valid in the new audit's context (Next version, distribution shape, app surface area).

## Consequences

- The `ecommerce-accountant-software` dep tree retains its current 27 transitive restricted-license packages. They are documented, not residual-unknown.
- The next `/audit-deps` run will still list these 27 packages in its license table — that's expected — but the posture is on file and dismissible by reference to this AgDR.
- A follow-up `[Chore]` for `THIRD_PARTY_NOTICES.md` (or `/legal/attributions` route) is **required** before the project's first production / public / customer-facing / distributed deployment. The ticket is **not yet filed** — to be filed as a follow-up to this AgDR.
- Future portfolio-side decisions about restricted licenses across other ApexYard-managed projects can `/agdr search license` to this entry as prior art and adapt the conditions.
- This AgDR is **not** legal advice. Any change to the project's distribution shape (or any future formal legal review) must produce a superseding record and update both the app-side `DECISIONS_LOG.md` § 21 and this AgDR (or its successor).
- The operator carrying both engineering and legal hats has explicitly approved this posture under the conditions above (PR [#167](https://github.com/GOkasha/ecommerce-accountant-software/pull/167) merge approval + this AgDR's invocation).
- `/audit-deps` will continue to surface MPL / LGPL packages on every run. That's intentional and harmless — this AgDR is the answer; future audits cite it.
- Closing umbrella [#148](https://github.com/GOkasha/ecommerce-accountant-software/issues/148) becomes possible once this AgDR's PR merges and a final closing comment is posted on #148 (see Decision § 4 above for the comment shape).

## Artifacts

- **App-side decision record (Phase 1):** `workspace/ecommerce-accountant-software/docs/DECISIONS_LOG.md` § 21 — landed on `main` at squash commit [`36592a3d`](https://github.com/GOkasha/ecommerce-accountant-software/commit/36592a3df51de28b963643213844eccead8e574d) via PR [GOkasha/ecommerce-accountant-software#167](https://github.com/GOkasha/ecommerce-accountant-software/pull/167) — `docs(GH-153): record license posture decision`. Reviewed by Rex at `b5c97548dec6d557f2e209ba99121e2b7fb9029d`; CEO-approved; CI Quality Gate green; merged 2026-05-22.
- **Portfolio-side record (Phase 2):** this AgDR — `projects/ecommerce-accountant-software/agdr/AgDR-0002-license-posture-mpl-lgpl.md`.
- **Source audit:** [`projects/ecommerce-accountant-software/dep-audit-2026-05-20.md`](../dep-audit-2026-05-20.md) — § 5 "License findings", recommendation [L3] "License sign-off".
- **Driving ticket:** [GOkasha/ecommerce-accountant-software#153](https://github.com/GOkasha/ecommerce-accountant-software/issues/153) — `[Chore] Legal review — MPL-2.0 and LGPL-3.0 transitive license posture`. Closes once both Phase 1 (landed) and Phase 2 (this AgDR's PR) merge.
- **Umbrella ticket:** [GOkasha/ecommerce-accountant-software#148](https://github.com/GOkasha/ecommerce-accountant-software/issues/148) — `[Chore] Dependency audit 2026-05-20 — remediation tracking`. Stays OPEN; closes later with the closing comment shape described in Decision § 4.
- **Related portfolio AgDR:** [`AgDR-0001-apexyard-vs-project-claude-md.md`](AgDR-0001-apexyard-vs-project-claude-md.md) — establishes the in-project vs portfolio-side decision boundary that this AgDR sits on.
- **Related app-side decision:** [`docs/DECISIONS_LOG.md` § 20](https://github.com/GOkasha/ecommerce-accountant-software/blob/main/docs/DECISIONS_LOG.md#20-accepted-risk--postcss-8510-transitive-xss-ghsa-qx2v-qp2m-jg93) — the postcss <8.5.10 acceptance from the same audit cycle, same documented-residual pattern.
- **Follow-up `[Chore]` (to be filed):** `[Chore] Add THIRD_PARTY_NOTICES.md / /legal/attributions before first production, public, customer-facing, or distributed deployment`. Will be linked back here once filed.
