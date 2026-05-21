# Governance — ecommerce-accountant-software under ApexYard

How the **two layers of Claude operating instructions** interact when you work on this project:

- **Outer layer** — the ApexYard ops fork at `D:/Apexyard/apexyard/`. Portfolio-level SDLC, role triggers, ticket gates, code-review agent, merge gates, dep-audit cadence.
- **Inner layer** — the app repo at `workspace/ecommerce-accountant-software/`. Strict per-repo rules (no math in `.tsx`, balanced `JournalEntry` via `posting.service`, 7-field final report) plus an in-repo phase pipeline (`/start-phase` → `/implement-phase` → `/test-phase` → `/review-phase`).

Both have a `CLAUDE.md`. Both define `.claude/skills/`. Both define hooks. This document is the contract for how they coexist.

The structural decision behind this layering is recorded in [`agdr/AgDR-0001-apexyard-vs-project-claude-md.md`](agdr/AgDR-0001-apexyard-vs-project-claude-md.md). Read that first if you want the *why*.

---

## 1. Authority order

When the two layers disagree, the rule is **innermost rule wins for code conventions; outermost rule wins for portfolio governance**.

| Concern | Authoritative source |
|---|---|
| Code patterns (where math lives, posting invariants, schema-change rituals, lint policy, file layout) | App `workspace/.../CLAUDE.md` + `docs/ARCHITECTURE.md` |
| Test policy (what must be covered, manual-verification plan template) | App `docs/TESTING_RULES.md` |
| Final-response shape inside an implementation turn | App "Automation A0" 7-field block (supersedes the 6-field block from `AI_CODE_GUARDRAILS.md`) |
| Ticket creation, branch naming, PR titles, merge gates, cross-project visibility | ApexYard ops `.claude/rules/*.md` + hooks |
| Role activation (Tech Lead, QA Engineer, Security Auditor, …) | ApexYard `.claude/rules/role-triggers.md` |
| Dependency-audit cadence + remediation tracking | ApexYard `/audit-deps` + `projects/ecommerce-accountant-software/dep-audit-YYYY-MM-DD.md` |
| Portfolio-wide visibility (`/inbox`, `/tasks`, `/stakeholder-update`, `/agdr` search) | ApexYard ops repo |

If both layers prescribe an *additive* check (e.g., both want a Glossary in the PR body), do both. The layers do not conflict on additive policy; they only conflict on code-shape decisions, and there the app wins.

---

## 2. Working-directory map

```
D:/Apexyard/                                              ← outer container (no governance here)
└── apexyard/                                             ← ApexYard ops fork (governance + portfolio docs)
    ├── CLAUDE.md                                         ← outer layer
    ├── apexyard.projects.yaml                            ← registry; this project is in it
    ├── onboarding.yaml                                   ← company config
    ├── .claude/                                          ← framework hooks, rules, skills, agents
    │   └── session/tickets/ecommerce-accountant-software ← active-ticket marker for THIS project
    ├── projects/ecommerce-accountant-software/           ← portfolio docs about the project
    │   ├── README.md
    │   ├── governance.md                                 ← this file
    │   ├── handover-assessment.md
    │   ├── dep-audit-2026-05-20.md
    │   ├── architecture/container.md
    │   └── agdr/AgDR-0001-apexyard-vs-project-claude-md.md
    └── workspace/ecommerce-accountant-software/          ← live clone of the app repo (gitignored)
        ├── CLAUDE.md                                     ← inner layer
        ├── docs/                                         ← in-repo operating manual
        ├── .claude/                                      ← project-local agents + commands + skills
        ├── src/, prisma/, tests/                         ← app code
        └── ...
```

Two git roots. The ops fork tracks portfolio docs (commits to `GOkasha/apexyard`); the app workspace tracks app code (commits to `GOkasha/ecommerce-accountant-software`). They never share a commit.

---

## 3. Lifecycle: ticket → phase → PR → merge

This is the canonical flow when starting work on this project. Each row names the owning layer and the command to run.

| # | Step | Layer | Command(s) |
|---|---|---|---|
| 1 | Create the GitHub issue in the app repo | ApexYard | `/feature`, `/bug`, `/task`, `/migration`, or `/spike` against `GOkasha/ecommerce-accountant-software` |
| 2 | Declare the active ticket for this session | ApexYard | `/start-ticket GOkasha/ecommerce-accountant-software#<N>` — writes the marker to `<ops_root>/.claude/session/tickets/ecommerce-accountant-software` |
| 3 | `cd workspace/ecommerce-accountant-software/` | — | shell |
| 4 | Open a feature branch in the app repo | App | `/start-phase` — creates `<type>/#<N>-<slug>` and refuses if the working tree has `.env*` / `next-env.d.ts` pollution |
| 5 | Implement the change | App | `/implement-phase` — reads the project `CLAUDE.md`, edits only allowed paths, optionally one additive migration, ends with the 7-field final report |
| 6 | Run the local quality gate | App | `npm run typecheck && npm test && npm run lint && npm run build` (also driven by `/test-phase`) |
| 7 | Open the PR | ApexYard | `gh pr create --repo GOkasha/ecommerce-accountant-software …` — ApexYard's PR-title validator enforces `type(#NN): description` |
| 8 | Code review | ApexYard | Rex (`/code-review`) reviews the diff; if `**/auth/**`, `**/crypto/**`, `**/secrets/**`, or `.env*` are touched, Hatim (`/security-review`) reviews too |
| 9 | App-side CI | App | `quality-gate.yml` runs Postgres + migrations + lint/typecheck/test/build |
| 10 | CEO approval gate | ApexYard | `/approve-merge <PR#>` after the CEO names the PR explicitly |
| 11 | Merge | ApexYard | `/approve-merge` runs `gh pr merge` once both markers (`*-rex.approved` and `*-ceo.approved`) are present and CI is green |
| 12 | Move to QA | ApexYard | App-side label `qa`; the QA Engineer role activates and verifies acceptance criteria before the issue closes |

Step 2 is load-bearing. Without the marker, `require-active-ticket.sh` blocks every `Edit` / `Write` / write-shaped `Bash` against app code from step 4 onward.

---

## 4. Where session state lives

Per ApexYard issue #41, **all** session-state files live under the ops fork at `D:/Apexyard/apexyard/.claude/session/` — even when cwd is `workspace/ecommerce-accountant-software/`. The hooks walk up from cwd to find the ops fork (anchor: `onboarding.yaml` + `apexyard.projects.yaml`) and read/write the markers there.

| Marker | Path | Written by |
|---|---|---|
| Active ticket (per-project) | `<ops_root>/.claude/session/tickets/ecommerce-accountant-software` | `/start-ticket` (preferred when the ticket is in the app repo) |
| Active ticket (ops fallback) | `<ops_root>/.claude/session/current-ticket` | `/start-ticket` (when the ticket is in the ops repo itself) |
| Rex code-review approval | `<ops_root>/.claude/session/reviews/<PR#>-rex.approved` | the `code-reviewer` agent on a successful review |
| CEO merge approval | `<ops_root>/.claude/session/reviews/<PR#>-ceo.approved` | `/approve-merge <PR#>` on an explicit per-PR nod |
| Design-review approval (UI PRs) | `<ops_root>/.claude/session/reviews/<PR#>-design.approved` | `/approve-design <PR#>` |

Never look for these inside the app workspace. The pre-#41 layout that kept them under `workspace/<name>/.claude/session/` is no longer read by any hook.

---

## 5. Decisions: AgDR layering

| Decision class | Lives where | Authoritative for |
|---|---|---|
| In-repo conventions (where a helper goes, why a service exists, library choices for in-repo concerns) | App `docs/DECISIONS_LOG.md` | The app repo only |
| Cross-layer / structural / portfolio-visible decisions (how the two `CLAUDE.md` layers interact, observability stack for the portfolio, when to swap a major dependency) | ApexYard `projects/ecommerce-accountant-software/agdr/AgDR-NNNN-<slug>.md` | The portfolio's view of this project; surfaced by `/agdr search` and `/agdr browse` |
| Pure framework-level decisions (release model, rule structure) | ApexYard ops `docs/agdr/` | The ApexYard framework itself |

If a decision is *only* about the app's internal shape, it stays in-repo. If a decision changes how ApexYard governs the project, or a future portfolio onboarding would want to know about it, write a portfolio-side AgDR here.

---

## 6. PR conventions (both layers must agree)

| Rule | Source | Enforced by |
|---|---|---|
| Branch name `type/#<N>-<slug>` (`type` ∈ feature / fix / refactor / chore / docs / test / spike / ci / build / perf) | ApexYard `.claude/rules/git-conventions.md` | `validate-branch-name.sh` |
| PR title `type(#<N>): description`, single ticket per PR | ApexYard `.claude/rules/git-conventions.md` | `validate-pr-create.sh` + `pr-title-check.yml` (CI) |
| `Refs #<N>` or `Closes #<N>` in PR body | App-side convention | manual; `verify-commit-refs.sh` checks commit messages |
| Glossary section in PR body | ApexYard `.claude/rules/pr-quality.md` | Rex requests changes if missing |
| 7-field final-report block in the implementation turn | App `CLAUDE.md` Automation A0 | manual; app-side reviewer enforces |
| Lint / typecheck / test / build pass before push | both | `pre-push-gate.sh` (ApexYard) + app's `npm run safety:git` |
| No `git add -A` / `git add .` | both | `block-git-add-all.sh` (ApexYard) + app's `scripts/check-git-safety.mjs` |
| No direct push to `main` | both | `block-main-push.sh` (ApexYard) + GitHub branch protection |
| Two recorded approvals before merge (Rex + CEO) | ApexYard `.claude/rules/pr-workflow.md` | `block-unreviewed-merge.sh` |

The two enforcers act as belt-and-braces. Don't go looking for a difference between them — there isn't one.

---

## 7. Hooks active inside `workspace/ecommerce-accountant-software/`

When cwd is the app workspace, the following ApexYard hooks still fire because they're wired in the ops `.claude/settings.json` and walk up to find the ops fork:

- `require-active-ticket.sh` — blocks `Edit` / `Write` / write-shaped `Bash` on non-exempt paths without an active ticket marker.
- `require-migration-ticket.sh` — extra gate on `prisma/migrations/**`, `prisma/schema.prisma`.
- `block-git-add-all.sh` — refuses `git add -A` / `git add .`.
- `block-main-push.sh` — refuses pushes to `main`.
- `check-secrets.sh` — scans commit content for credential patterns.
- `block-private-refs-in-public-repos.sh` — leak protection. Does **not** apply here: both repos live under `GOkasha/`, neither is the public framework.
- `validate-branch-name.sh`, `validate-pr-create.sh`, `pre-push-gate.sh` — git/PR shape gates.
- `block-unreviewed-merge.sh` + companions — merge-time gates.
- `verify-commit-refs.sh` — sanity-checks `Closes #N` / `Refs #N` in commit messages.

The app's own `.claude/commands/*` (e.g. `phase-review`, `pre-commit-safety`) and `.claude/agents/*` (`finance-accounting-reviewer`, `code-quality-reviewer`) are loaded by Claude Code from the **inner** repo when cwd is inside it. They run *in addition to* the outer hooks.

Exempt paths under `require-active-ticket.sh` (no ticket required): `.claude/`, `docs/`, `projects/*/docs/`, any `*.md`.

---

## 8. When each layer is irrelevant

Pure framework-internal work on the ApexYard fork (editing ops `CLAUDE.md`, adding a skill, fixing a hook) uses the ops-fallback ticket marker (`.claude/session/current-ticket`) and does not interact with the app workspace at all. The inner layer is irrelevant for those tickets.

Conversely, even a pure in-repo change (a typo fix in `docs/INTERNAL_LAUNCH_RUNBOOK.md`, a CSS tweak) still needs an app GitHub issue and a `/start-ticket` against it, because that's the outer gate. Both layers always apply; only the *decisions captured* are scoped.

---

## 9. Cross-references

- Decision record: [`agdr/AgDR-0001-apexyard-vs-project-claude-md.md`](agdr/AgDR-0001-apexyard-vs-project-claude-md.md)
- Initial handover snapshot: [`handover-assessment.md`](handover-assessment.md)
- Container diagram: [`architecture/container.md`](architecture/container.md)
- Most recent dep audit: [`dep-audit-2026-05-20.md`](dep-audit-2026-05-20.md)
- Outer-layer rules: `D:/Apexyard/apexyard/.claude/rules/`
- Inner-layer rules: `workspace/ecommerce-accountant-software/CLAUDE.md` + `workspace/ecommerce-accountant-software/docs/`
- Registry entry: `D:/Apexyard/apexyard/apexyard.projects.yaml` → `projects[name=ecommerce-accountant-software]`
