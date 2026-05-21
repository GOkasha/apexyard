# ecommerce-accountant-software

ApexYard-managed docs for the **Perfume ERP Egypt** project (`GOkasha/ecommerce-accountant-software`).

- **What it is**: single-tenant ecommerce back-office + accounting + inventory ERP for an Egypt-based perfume business. Replaces a legacy Excel workbook (~415 products, ~850 POs, ~11k order lines).
- **Stack**: Next.js 16.2 App Router · React 19 · TypeScript 5.9 · Prisma 6.19 · PostgreSQL · Vitest 4.
- **Workbook ingest**: ExcelJS (migrated from `xlsx` on 2026-05-20 — PRs #160, #161, #163, #164).
- **Status**: `handover` — onboarded into the apexyard portfolio on 2026-05-20.
- **Upstream repo**: <https://github.com/GOkasha/ecommerce-accountant-software>
- **Local workspace**: `workspace/ecommerce-accountant-software/` (gitignored).

## Documents in this folder

- [`governance.md`](governance.md) — how the ApexYard outer layer and the app's inner `CLAUDE.md` coexist day to day. **Read this second.**
- [`handover-assessment.md`](handover-assessment.md) — initial assessment from `/handover` (read this first). Carries a `Status update — 2026-05-21` block at the top noting what's changed since.
- [`architecture/container.md`](architecture/container.md) — auto-generated C4 L2 starter diagram; refine as the architecture evolves.
- [`dep-audit-2026-05-20.md`](dep-audit-2026-05-20.md) — first portfolio-side dependency audit (Munir, 2026-05-20). Drives the remediation tracker in `GOkasha/ecommerce-accountant-software#148`.
- [`agdr/`](agdr/) — cross-layer / portfolio-visible Agent Decision Records for this project. In-repo decisions live separately in `workspace/.../docs/DECISIONS_LOG.md` — see `governance.md` § 5 for the split.

## Upstream project docs

The project ships substantial in-repo documentation. When working on this project under apexyard, the **project's own `CLAUDE.md` and `docs/`** are the operating manual; apexyard adds portfolio-level governance on top.

Key project docs (paths inside `workspace/ecommerce-accountant-software/`):

- `CLAUDE.md` — per-repo operating instructions (read first every session).
- `PROJECT_HANDOFF.md` — system overview + risk register.
- `docs/ARCHITECTURE.md` — seven core areas + non-negotiable rules.
- `docs/TESTING_RULES.md` — coverage requirements per business flow.
- `docs/AI_CODE_GUARDRAILS.md` — inspect → explain → plan → implement → verify loop.
- `docs/DECISIONS_LOG.md` — settled decisions; do not relitigate.
- `docs/DEVELOPER_PLAN.md` — current phase + acceptance criteria.
- `docs/FINANCIAL_LOGIC_BLUEPRINT.md` — accounting math + posting invariants.
- `docs/INTERNAL_LAUNCH_RUNBOOK.md` — go-live procedure.
- `docs/DATA_SAFETY_AND_MIGRATION.md` — real-data migration §7 checklist.
