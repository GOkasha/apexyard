# ApexYard governance layers on top of the project's in-repo CLAUDE.md

> In the context of bringing `ecommerce-accountant-software` into the ApexYard portfolio, facing two non-trivial sets of Claude operating instructions (the app's strict in-repo `CLAUDE.md` + `docs/` ruleset versus the ApexYard ops fork's portfolio-level rules / hooks / skills), I decided to make the project's in-repo rules authoritative for code conventions and let ApexYard add an outer governance layer on top, to achieve a clean separation between "don't break the ledger" rules and "don't lose track of work across the portfolio" rules, accepting that day-to-day work happens under two `.claude/` trees and operators have to read both.

## Context

The `ecommerce-accountant-software` project arrived at handover (2026-05-20) with substantial in-repo Claude tooling already in place:

- A `CLAUDE.md` with six **hard rules** about where financial math lives, posting invariants, and schema-change discipline.
- An "Automation A0" section mandating a **7-field final report** on every implementation turn.
- Project-local agents (`finance-accounting-reviewer`, `code-quality-reviewer`).
- Project-local skills (`safe-change-workflow`, `ecommerce-accounting-rules`, `shopify-inventory-rules`).
- A multi-step phase pipeline (`/start-phase`, `/implement-phase`, `/test-phase`, `/review-phase`).
- `docs/ARCHITECTURE.md`, `docs/TESTING_RULES.md`, `docs/AI_CODE_GUARDRAILS.md`, `docs/DECISIONS_LOG.md`, `docs/PHASE_WORKFLOW_AUTOMATION.md` — a complete in-repo operating manual.

ApexYard adds an outer layer the project lacked: cross-project visibility (`/projects`, `/inbox`, `/tasks`, `/stakeholder-update`), portfolio-wide AgDR search (`/agdr`), structured ticket flow (`/start-ticket` + per-project session markers per ApexYard #41), automated code review (Rex), automated security review (Hatim), automated dependency audit (Munir), and merge gates (`block-unreviewed-merge.sh`).

The two layers overlap on:

- PR title / branch name validation (both enforce the same shape).
- "No direct push to `main`" / "no `git add -A`" (both enforce).
- Lint / typecheck / test / build before push.

They potentially conflict on:

- **Which `CLAUDE.md` is authoritative when they disagree?**
- **Final-report format** — ApexYard's PR conventions ask for a Glossary + standard summary; the app's "Automation A0" asks for a 7-field block.
- **AgDR storage** — ApexYard's convention is `{project}/docs/agdr/`; the app has `docs/DECISIONS_LOG.md` and never adopted the AgDR shape.
- **Phase pipeline vs. role-triggered SDLC** — ApexYard activates a Tech Lead → Backend Engineer → QA Engineer chain on triggers; the app drives the same work through `/start-phase` → `/implement-phase` → `/test-phase` → `/review-phase`.

The handover assessment (open question #1) explicitly flagged this layering as "worth an AgDR" but did not write one. This record is that AgDR.

## Options Considered

| Option | Pros | Cons |
|---|---|---|
| **A. Project rules win for code; ApexYard wins for governance** (the layered approach) | Keeps both well-considered systems; nothing has to be deleted. Aligns with ApexYard's existing stance that managed projects keep their own conventions. | Two `.claude/` trees, two skill sets, ongoing cognitive overhead. Requires a governance doc to keep boundaries clear. |
| **B. ApexYard rules win uniformly** | Single source of truth across the portfolio; simpler mental model. | Destroys the app's hard rules (no math in `.tsx`, balanced `JournalEntry` via `posting.service`, 7-field report) — these are stricter than ApexYard defaults and were authored with intent. Strictly worse for accounting correctness. |
| **C. Project rules win uniformly; ApexYard is read-only governance** | Lightest touch on the existing project. | Loses ApexYard's merge gates, automated code review, ticket-marker enforcement — defeats the point of onboarding into the portfolio. |
| **D. Rewrite the app's `CLAUDE.md` to fold ApexYard rules in** | Single `CLAUDE.md` inside the workspace. | Forks the framework — the app's `CLAUDE.md` would have to be re-merged on every ApexYard upgrade. Breaks the "live clone of the upstream repo" invariant. |

## Decision

Chosen: **Option A — project rules win for code conventions; ApexYard wins for governance and portfolio visibility**, because the two systems were built for different concerns (the app's `CLAUDE.md` is about not breaking the ledger; ApexYard's `CLAUDE.md` is about not losing track of work across a portfolio) and neither subsumes the other.

Concretely:

1. **Code shape, accounting invariants, testing policy, schema discipline** → app `CLAUDE.md` + `docs/`.
2. **Tickets, branches, PR titles, merge gates, code-review agents, dep-audit cadence, cross-project AgDRs, stakeholder updates** → ApexYard ops repo.
3. **Final-report format** → use the app's 7-field block inside implementation turns; ApexYard's Glossary still goes in the PR body. Both shapes coexist (additive, not conflicting).
4. **AgDR storage** → in-repo decisions go in `docs/DECISIONS_LOG.md` (the app's existing convention); cross-layer / portfolio-visible decisions go in `projects/ecommerce-accountant-software/agdr/` under the ApexYard fork (this file is the first).
5. **Phase pipeline vs. role-triggered SDLC** → keep both. ApexYard's `/start-ticket` is the prerequisite gate; the app's `/start-phase` → `/implement-phase` → `/test-phase` → `/review-phase` is the implementation procedure within the ticket. Roles activate per ApexYard's trigger table for review-time gates (Rex on every PR, Hatim on auth/crypto/secrets diffs, QA Engineer on merge → `qa` label).

The boundaries are documented in [`../governance.md`](../governance.md).

## Consequences

- Operators read two `CLAUDE.md`s. Mitigated by the governance doc acting as the single index.
- The 7-field final report is mandatory for app implementation turns; the Glossary is mandatory for PR bodies. Both are checked by different reviewers (app-side reviewer for the report; Rex for the Glossary).
- Future portfolio decisions that touch this project (observability stack, deployment target, on-call rotation) get AgDRs under `projects/ecommerce-accountant-software/agdr/`, not in `docs/DECISIONS_LOG.md`.
- The app's in-repo `.claude/commands/`, `.claude/agents/`, and `.claude/skills/` continue to load when cwd is the app workspace; ApexYard's hooks fire in parallel because they walk up to the ops fork.
- ApexYard upgrades (`/update`) never touch the app workspace; app upstream pulls never touch the ops fork. The two upgrade paths are independent.
- If a future conflict arises (e.g., ApexYard introduces a rule that contradicts an app hard rule), the app wins for code, and the project files an exemption/extension request against the framework.

## Artifacts

- Governance doc: [`../governance.md`](../governance.md) (created in the same PR as this AgDR).
- Handover assessment: [`../handover-assessment.md`](../handover-assessment.md) — open question #1 resolved by this record.
- App-side authoritative rules: `workspace/ecommerce-accountant-software/CLAUDE.md` + `docs/ARCHITECTURE.md` + `docs/TESTING_RULES.md` + `docs/AI_CODE_GUARDRAILS.md`.
- Outer-layer rules: ApexYard ops `CLAUDE.md` + `.claude/rules/*.md`.
- Registry entry: `D:/Apexyard/apexyard/apexyard.projects.yaml` → `projects[name=ecommerce-accountant-software]`.
- Ticket: `GOkasha/apexyard#165` — *[Docs] Align ApexYard nested workflow for Ecommerce Accountant Software*.
