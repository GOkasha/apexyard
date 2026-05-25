---
name: cfo-financial-gate
description: Read-only CFO / Financial Controller audit of a financial backend — accounting correctness, journal integrity, AR/AP, customer credits/deposits/prepayments, refund-liability, COGS/WAC, stock accounting, reporting trust, auditability, and real-data go-live readiness. Produces a P0–P3 CFO Financial Gate Report with a PASS / PASS WITH CONDITIONS / FAIL verdict, persisted for trend tracking. Never edits files, runs migrations, touches .env, or mutates the DB.
disable-model-invocation: true
argument-hint: "[repo-path] [--pr=<n>] [--issue=<n>] [--scope=<area>]"
effort: high
allowed-tools: Bash, Read, Grep, Glob
---

# /cfo-financial-gate — CFO Financial Gate (read-only)

A deliberate financial-correctness checkpoint run by **Yusuf**, the [CFO / Financial Controller](../../../roles/finance/cfo-financial-controller.md). It audits a financial backend against a project's `standards/financial-standards.md` and emits a structured **CFO Financial Gate Report** (sections A–M) with a verdict and P0–P3 findings. It is the deep-dive financial companion to `/launch-check` — invoke it before building money-handling features (customer credits, prepayments, refunds) and before real-data go-live.

> ## ⛔ READ-ONLY — non-negotiable
>
> This skill **never**:
> - edits, creates, or deletes any file in the audited repo;
> - runs migrations (`prisma migrate` / `db push` / `db execute`), seeds, or any DB-mutating command;
> - reads, prints, parses, greps, or infers `.env*` / `DATABASE_URL` / credentials;
> - **invents or changes accounting policy.** When a rule is missing or ambiguous, it flags the gap and *requires a written decision* (`DECISIONS_LOG.md` / AgDR) — it does not settle the question.
>
> Its only writes are: (1) the audit artefact under `projects/<name>/audits/cfo-financial-gate/`, written via `_lib-audit-history.sh` in the **ops fork** — never in the audited app repo; (2) read-only shell/grep output to chat. `allowed-tools` excludes `Edit`/`Write` by construction; the Bash tool must only be used for read-only inspection and the persistence lib.

## LSP-aware (optional, recommended)

This skill performs semantic code navigation — finding posting-helper callers, tracing cost/COGS flow, walking source-of-truth reads across modules. With LSP enabled (`ENABLE_LSP_TOOL=1` + per-language plugin per `docs/getting-started.md`), queries are cheaper than grep + Read. Without LSP, it falls back to grep + Read transparently — no new failure mode, just optional speed.

## Activated role

When `/cfo-financial-gate` runs, the **[CFO / Financial Controller](../../../roles/finance/cfo-financial-controller.md)** role (persona **Yusuf**) activates. Print the activation marker per [`.claude/rules/role-triggers.md`](../../rules/role-triggers.md) § "How to signal activation":

```
▸ Activating Yusuf (CFO / Financial Controller) for <scope> (trigger: /cfo-financial-gate)
```

## Usage

```
/cfo-financial-gate                                   # default: registered app at its workspace clone
/cfo-financial-gate workspace/ecommerce-accountant-software
/cfo-financial-gate workspace/ecommerce-accountant-software --pr=210     # bound to a PR diff
/cfo-financial-gate workspace/ecommerce-accountant-software --issue=148  # bound to an issue's area
/cfo-financial-gate workspace/ecommerce-accountant-software --scope=customer-credits
```

| Input | Effect |
|-------|--------|
| `[repo-path]` | Path to the financial backend to audit. Resolved to a project name via `apexyard.projects.yaml`. Defaults to the registered app's `workspace/<name>`. |
| `--pr=<n>` | Bound the audit to a PR diff (`gh pr view <n>` / `gh pr diff <n>`). Flow matrix focuses on touched flows. |
| `--issue=<n>` | Bound the audit to the area an issue describes (`gh issue view <n>`). |
| `--scope=<area>` | Narrow to one flow family, e.g. `customer-credits`, `cogs`, `returns`, `ap`, `reports`. Filters the D matrix rows. |

No flags → full backend sweep across all 16 flows.

## Process

### Step 1 — Resolve target + scope (read-only)

```bash
ops_root="$(git rev-parse --show-toplevel)"
source "$ops_root/.claude/hooks/_lib-read-config.sh"
source "$ops_root/.claude/hooks/_lib-portfolio-paths.sh"
projects_dir="$(portfolio_projects_dir)"
```

- Resolve `<repo-path>` → `<project-name>` via the registry. If unregistered, use the path basename and advise `/handover` for cross-machine trend continuity.
- If `--pr` / `--issue`, fetch metadata with `gh pr view` / `gh issue view` (read-only) to bound the diff.
- If `--scope`, restrict the D matrix to the named flow family.

### Step 2 — Load the standard (refuse-soft if absent)

```bash
standards="${projects_dir}/${project_name}/standards/financial-standards.md"
[ -f "$standards" ] || echo "NOTE: no financial-standards.md for ${project_name}; auditing against the framework defaults only. Recommend authoring projects/${project_name}/standards/financial-standards.md."
```

Read the standards doc — it is the rule set the findings cite. For `ecommerce-accountant-software` it is the 17 standards encoding the app's own `FINANCIAL_LOGIC_BLUEPRINT.md` + `CLAUDE.md` hard rules.

### Step 3 — Build the search / evidence map (read-only)

Run discovery and record each command + what it answered (becomes report section C). Grounded queries for this app:

```bash
cd "$repo_path"
# Journal integrity — postJournal is the only path (Standard 1, 15)
grep -rn "postJournal(" src/lib/services
grep -rn "journalLine.create\|journalEntry.create" src/lib/services   # raw inserts outside posting.service = finding

# COGS / WAC (Standards 4, 5, 6) — classify each as READ vs WRITE
grep -rn "current_avg_cost" src/lib/services
grep -rn "cogs_snapshot" src/lib/services

# Atomicity + audit attribution (Standards 2, 3)
grep -rn "\$transaction" src/lib/services
grep -rn "actor_id\|posted_by_id" src/lib/services

# Source of truth (Standards 8, 13)
grep -rn "customer_summary\|summaries.service" src/lib/services
grep -rn "open_receivable\|amount_paid\|gross_order_value" src   # direct reads of denormalised Customer.* in reports = finding

# Customer credit / deposit / prepayment / overpayment (Standards 9, 10, 11) — the area this gate precedes
grep -rn "2200\|customer.deposit\|customerCredit\|overpay\|prepay\|deposit" src/lib/services
grep -rn "postCustomerPaymentJournal\|postReturnRefundJournal" src/lib/services

# Stock truth (Standard 7)
grep -rn "StockMovement\|stockMovement.create" src/lib/services
# UI math leak (Standard 14)
grep -rn "\* qty\|cogs\|margin\|total" src/app --include=*.tsx
# Chart of accounts (Standard 15)
grep -rn "DEFAULT_ACCOUNTS\|ensureChartOfAccounts\|account_code" src/lib/services/posting.service.ts
```

For every flagged occurrence, **read the surrounding code** and confirm read-vs-write before classifying. Cite `file:line`. Never raise a P0 on a grep hit alone.

### Step 4 — Walk the Financial Flow Matrix

For each of the 16 flows (filtered by `--scope` if set), locate the owning service/helper and answer: posts via `postJournal()`? · write + journal + audit atomic in one `$transaction`? · source of truth correct? · auditable actor?

| Flow | Key anchor to check |
|------|---------------------|
| Sales order | `sales.service` → `postSalesRevenueJournal` / `postSalesCogsJournal` |
| POS checkout | POS path → same posting helpers (blueprint §2.2.9) |
| Customer payment / AR | `postCustomerPaymentJournal` (credits `1100`, never `4000`) |
| **Customer overpayment** | excess > `amount_due` → must become `2200` liability, **not** zeroed AR (Standard 9; blueprint §7 #4) |
| **Customer prepayment / deposit** | credit `2200`, not revenue (Standard 10) |
| **Apply customer credit to order** | reduce `2200`, settle order (Standard 11) |
| **Refund customer credit** | `Dr 2200 / Cr cash` — distinct from `4200` return path (Standard 11) |
| Supplier payment / AP | `purchasing.service`; `SupplierPayment`; AP `2000` (Standard 12) |
| Purchase receipt / WAC | `receivePurchaseOrder` — only writer of `current_avg_cost` (Standards 4, 5) |
| Returns / refunds | `postReturnRefundJournal` (`4200` contra-revenue, AR-first split) |
| Damaged returns / stock loss | `postDamagedReturnLossJournal` (`5100`←`5000`) |
| Stock transfer / adjustment | `postStockCountAdjustmentJournal`; transfers paired, no journal |
| Expenses | `postExpenseJournal`; `Expense` / `ExpenseCategory.gl_account_code` |
| Budget lines | `budget.service`; `BudgetLine` — reporting only, no posting |
| Reports | tie to trial balance via `getTrialBalance` / `ledger-reporting.service` (Standard 8) |
| Shopify imports | imported orders → same posting path (Standard 13) |

### Step 5 — Classify, score, verdict

Classify each finding **P0 / P1 / P2 / P3** (see the standards doc). Compute the headline score and verdict the same way the other audit skills do:

```
score = max(0, 100 − 25*P0 − 10*P1 − 3*P2 − 1*P3)
```

| Worst tier present | Verdict | Persisted verdict token |
|--------------------|---------|--------------------------|
| any P0            | **FAIL** | `fail` |
| P1 (no P0)        | **PASS WITH CONDITIONS** | `conditional` |
| P2/P3 only / none | **PASS** | `pass` |

(P0 → `critical`, P1 → `high`, P2 → `medium`, P3 → `low` in the persisted payload's severity vocabulary.)

### Step 6 — Emit the A–M report

Print the full report to chat using the section structure in `templates/audits/cfo-financial-gate.md`:

```
A. CFO verdict (PASS | PASS WITH CONDITIONS | FAIL) + score
B. Scope inspected
C. Search commands / evidence map
D. Financial flow matrix
E. Source-of-truth findings
F. Journal integrity findings
G. Transaction / audit findings
H. Backend / API / test coverage findings
I. P0 blockers
J. P1 risks
K. P2/P3 follow-ups
L. Recommended issues
M. Final CFO recommendation
```

### Step 7 — Persist the run + render trend + previous-run comparison

Persist via the shared audit-history lib so financial-readiness is trackable across runs. The artefact lands in the **ops fork** at `projects/<name>/audits/cfo-financial-gate/<ts>.md` — never in the app repo.

```bash
source "$ops_root/.claude/hooks/_lib-audit-history.sh"

# Lowercase severity in the payload — the lib's stats derivation expects
# critical / high / medium / low. Map P0→critical, P1→high, P2→medium, P3→low.
payload=$(mktemp); cat > "$payload" <<'EOF'
{
  "schema_version": 1,
  "findings": [
    {"id": "P0-1", "severity": "critical", "status": "open", "summary": "Customer overpayment floored into zeroed AR (no 2200 liability)"},
    {"id": "P1-1", "severity": "high",     "status": "open", "summary": "current_avg_cost written outside purchasing.service"}
  ]
}
EOF

# Body = A–M report per templates/audits/cfo-financial-gate.md.
body=$(mktemp); cat > "$body" <<'EOF'
## A. CFO verdict
...
## M. Final CFO recommendation
...
EOF

ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
audit_run_persist "<project-name>" "cfo-financial-gate" "$ts" "<verdict>" <score> "$body" < "$payload"
rm -f "$payload" "$body"

# Trend + previous-run comparison
audit_render_trend "<project-name>" "cfo-financial-gate" 5
```

- `audit_render_trend`: `< 2` prior runs → silent (no trend section). `≥ 2` prior runs → prints a markdown trend block (heading + table + ASCII score-over-time chart). Append it to this run's MD artefact and to the chat output.
- **Previous-run comparison**: when ≥ 1 prior run exists, read the most-recent prior artefact under `$(audit_resolve_dir "<project-name>" cfo-financial-gate)` and add a one-line delta to section A (e.g. *"Δ vs last run: score 60→75; P0 3→1; closed P0-2 (overpayment), P0-1 still open"*).

### Step 8 — Recommend exact follow-up issues (never auto-file)

Section L lists each recommended issue with: **title**, **type** (`/feature` · `/bug` · `/task` · `/migration`), and **which standard(s)** it satisfies. Schema / chart-of-account items MUST be typed `/migration` (Standard 16). The skill **does not** run `gh issue create` — the operator decides.

#### 8a. Opt-in commit (history-tracked marker)

By default the dimension's `runs/` JSON is gitignored. To commit the history:

```bash
touch projects/<name>/audits/cfo-financial-gate/.audit-history-tracked
```

The `<ts>.md` artefacts are committed regardless — they are the durable human-readable record. (This skill stages nothing; committing is a separate, operator-driven step.)

## Rules

1. **Read-only, always.** No edits, no migrations, no DB mutation, no `.env` access. The only writes are the ops-fork audit artefact + chat output.
2. **Never invent accounting policy.** Missing/ambiguous rule → flag the gap, classify it, and require a written decision. Cross-reference `FINANCIAL_LOGIC_BLUEPRINT.md` §7 open questions.
3. **Evidence-backed findings only.** Every finding cites `file:line`; confirm read-vs-write before raising a P0. Don't cry wolf on a grep hit.
4. **Customer credit / prepayment / overpayment / refund are first-class.** These flows (Standards 9–11) are the reason the gate exists — always walk them, even on a scoped run, and call out the §7 #4 gap explicitly.
5. **Schema / chart-of-account follow-ups route through `/migration`.** The gate recommends; it never touches schema.
6. **Always persist.** Step 7 writes a JSON + MD pair via `audit_run_persist` regardless of verdict, so the trend is visible across runs.
7. **Standalone.** This skill does not modify `/launch-check` and is not a merge gate. (A future advisory hook / `<pr>-cfo.approved` gate is a separate, opt-in decision — out of scope here.)
8. **Verdict semantics are fixed.** any P0 → FAIL; P1 (no P0) → PASS WITH CONDITIONS; otherwise PASS.

## Anti-patterns

- **Don't "fix" a finding.** Recommend an issue; never edit the audited repo.
- **Don't run a migration to verify** a schema concern — reason about it read-only.
- **Don't treat Shopify totals as authoritative** — the ledger is the source of truth (Standard 13).
- **Don't present an accounting choice as settled** when it's an open question — that's policy invention (Standard 17).
- **Don't raise a P0 from a grep count alone** (e.g. `current_avg_cost` appears in ~9 files, mostly reads) — read the code first.
