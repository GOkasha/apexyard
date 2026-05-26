# CFO Financial Gate Report — {project} @ {short-sha}

> Persisted by `/cfo-financial-gate` via `_lib-audit-history.sh`. Frontmatter (added by the lib) is structured; the body is freeform per dimension. Audited by **Yusuf** (CFO / Financial Controller) against `projects/{project}/standards/financial-standards.md`. See `docs/agdr/AgDR-0019-audit-artefact-persistence.md` for the schema rationale.
>
> **READ-ONLY artefact.** The gate that produced this never edited code, ran a migration, touched `.env`, or mutated the DB.

## A. CFO verdict

**{PASS | PASS WITH CONDITIONS | FAIL}** — score {0–100}.

(One-paragraph rationale. PASS = no P0/P1. PASS WITH CONDITIONS = P1 present, named conditions to clear. FAIL = any P0.)

## B. Scope inspected

- Target: `{repo-path}` @ `{sha}`
- Bound by: {full backend | `--pr=<n>` | `--issue=<n>` | `--scope=<area>`}
- Standards source: `projects/{project}/standards/financial-standards.md` ({N} standards)
- Out of scope: {what was not inspected}

## C. Search commands / evidence map

| # | Command | What it answered |
|---|---------|------------------|
| 1 | `grep -rn "postJournal(" src/lib/services` | Journal posting path |
| 2 | `grep -rn "current_avg_cost" src/lib/services` | WAC write surface (read vs. write) |
| … | … | … |

## D. Financial flow matrix

| Flow | Owning service / helper | Posts via `postJournal`? | Atomic? | Source of truth | Finding |
|------|--------------------------|--------------------------|---------|-----------------|---------|
| Sales order | | | | | |
| POS checkout | | | | | |
| Customer payment / AR | | | | | |
| Customer overpayment | | | | | |
| Customer prepayment / deposit | | | | | |
| Apply customer credit to order | | | | | |
| Refund customer credit | | | | | |
| Supplier payment / AP | | | | | |
| Purchase receipt / WAC | | | | | |
| Returns / refunds | | | | | |
| Damaged returns / stock loss | | | | | |
| Stock transfer / adjustment | | | | | |
| Expenses | | | | | |
| Budget lines | | | | | |
| Reports | | | | | |
| Shopify imports | | | | | |

## E. Source-of-truth findings

(Ledger / approved summaries vs. stale denormalised fields or external channel. Standards 8, 13.)

## F. Journal integrity findings

(Balanced double-entry, single posting path, source linkage, idempotency. Standards 1, 15.)

## G. Transaction / audit findings

(Atomicity of write + journal + audit; actor attribution from verified session. Standards 2, 3.)

## H. Backend / API / test coverage findings

(API boundary validation; test coverage for money/stock flows; UI-math leakage. Standards 14 + `TESTING_RULES.md`.)

## I. P0 blockers

| # | Finding | Standard | Evidence (`file:line`) | Required fix |
|---|---------|----------|------------------------|--------------|

## J. P1 risks

| # | Finding | Standard | Evidence | Condition to clear |
|---|---------|----------|----------|--------------------|

## K. P2 / P3 follow-ups

| # | Tier | Finding | Standard | Evidence |
|---|------|---------|----------|----------|

## L. Recommended issues

| Title | Type | Standard(s) | Notes |
|-------|------|-------------|-------|
| (e.g. "Explicit customer-credit liability on overpayment") | `/feature` | 9, 10 | Awaiting `DECISIONS_LOG.md` decision (blueprint §7 #4) |
| (e.g. "Confine `current_avg_cost` writes to purchasing.service") | `/task` | 4, 5 | |
| (schema-touching items) | `/migration` | 16 | Needs migration ticket + Migration AgDR |

## M. Final CFO recommendation

(Go / no-go on the financial work this audit precedes. Name the exact conditions for a PASS WITH CONDITIONS, and the decision(s) that must be logged before customer credit / prepayment / refund implementation begins.)
