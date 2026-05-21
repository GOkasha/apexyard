# ecommerce-accountant-software — Handover Assessment

**Date**: 2026-05-20
**Assessor**: GOkasha
**Status**: handover

## Status update — 2026-05-21

This document is preserved as the original handover snapshot from 2026-05-20. The points below are what has changed since. The body of the assessment is unchanged.

- **Workbook ingest** — the `xlsx` library has been replaced with **ExcelJS** (PRs [#160](https://github.com/GOkasha/ecommerce-accountant-software/pull/160) *add parallel ExcelJS importer*, [#161](https://github.com/GOkasha/ecommerce-accountant-software/pull/161) *cut over*, [#163](https://github.com/GOkasha/ecommerce-accountant-software/pull/163) *remove xlsx dependency*, [#164](https://github.com/GOkasha/ecommerce-accountant-software/pull/164) *collapse importer paths*, merged 2026-05-20 / 2026-05-21). The "Quality risks → Dependencies → `xlsx`" item and the "Technical debt → workbook ingest uses xlsx" item below are **superseded** — no action remains. The container diagram has been updated accordingly.
- **Registry "Suggested updates"** — `apexyard.projects.yaml` now includes `workspace: workspace/ecommerce-accountant-software` and the additional roles (`platform-engineer`, `sre`, `data-engineer`). The "Suggested updates (apply manually)" block in § Integration Plan is **resolved**.
- **Open question #1 ("Authority of `CLAUDE.md`")** — resolved by [`agdr/AgDR-0001-apexyard-vs-project-claude-md.md`](agdr/AgDR-0001-apexyard-vs-project-claude-md.md) and [`governance.md`](governance.md). Summary: the app's in-repo rules win for code conventions; ApexYard wins for portfolio governance.
- **Recent activity** — the most recent merge is now **PR #164** (was #147 at handover). The project has stayed active through the ExcelJS cutover and the dep-audit remediation; baseline lives in [`dep-audit-2026-05-20.md`](dep-audit-2026-05-20.md), open remediation tracker is [`GOkasha/ecommerce-accountant-software#148`](https://github.com/GOkasha/ecommerce-accountant-software/issues/148).
- **All other risks, integration-plan items, and open questions remain as stated below.**

---

## Origin

- **Where it came from**: greenfield in-house build (registered project, not an acquisition). The repo replaces a working `Store_backend_system_v4_shopify_sync_customers.xlsx` workbook used by an Egypt-based perfume business.
- **Original owner**: `GOkasha` (single contributor in `git shortlog`).
- **Repo location**: <https://github.com/GOkasha/ecommerce-accountant-software>
- **First commit date**: 2026-04-28
- **Last commit date**: 2026-05-19 (1 day ago, very active)

## Current State

### Tech stack

- Language: TypeScript 5.9 (strict mode via `tsconfig.json`)
- Runtime: Node 20 (per `quality-gate.yml`); package type `module`
- Framework: **Next.js 16.2 (App Router)** — Web + API in one deployable
- UI: React 19 + vanilla CSS (no Tailwind, per project rule)
- Database: **PostgreSQL** via **Prisma 6.19** (57 models, 24 migrations)
- Validation: Zod 4 at API / service boundary
- Auth: custom HMAC-signed session cookies + `bcryptjs` for passwords (no NextAuth / Clerk / Auth0)
- Ingest auth: HMAC-SHA256 on `POST /api/pixel` (Meta CAPI / GA4 / TikTok server-side events)
- Workbook ingest: `xlsx` library + custom importer preserving `legacy_id` and source-row metadata
- Test framework: **Vitest 4** (215 test files — unit + integration)
- Lint: ESLint 9 with `eslint-config-next`
- CI: **GitHub Actions** — `quality-gate.yml` spins up Postgres 16 service, applies migrations, runs `lint && typecheck && test && build`

### Build status

- `npm install`: passed locally on 2026-05-20; Prisma Client generated successfully.
- `npm run typecheck`: passed locally.
- `npm run test`: passed locally — 65 test files passed, 150 skipped; 730 tests passed, 1767 skipped, 204 todo.
- `npm run lint`: passed locally.
- `npm run build`: passed locally; Next.js production build completed successfully.
- Note: `npm install` reported 7 vulnerabilities (2 moderate, 5 high). Do not run `npm audit fix` automatically; handle through `/audit-deps`.
- Note: test output included a non-failing `DATABASE_URL` stderr from `expense-category-mapping.test.ts`; track as cleanup noise, not a failed baseline.

### Test coverage

- Estimated: **substantial** — 215 Vitest test files across `tests/unit/`, `tests/integration/`, `tests/_helpers/`. Project has explicit `docs/TESTING_RULES.md` mandating coverage for every business flow (revenue, COGS, refunds, AR, transfers, Shopify imports). No numeric coverage threshold committed; set one before the first apexyard-governed feature PR.

### Repo activity

- Total commits: 299 (single-month velocity since 2026-04-28 — actively built)
- Commits in last 90 days: 299 (all of them)
- Open issues: 0
- Open PRs: 0
- Top contributors: GOkasha (sole contributor)
- Most recent merge: **PR #147** `feature/b22b-live-core-list-pages` (2026-05-19)

### Surface size

- **121** API routes (`src/app/api/**/route.ts`)
- **61** service modules in `src/lib/services/`
- **57** Prisma models
- **24** migrations
- Service-layer subdirs: `api`, `auth`, `domain`, `security`, `services`, `ui`, `utils`, `validation`

## Quality Risks

### Security

- **Custom-built auth** — HMAC-signed session cookies + bcryptjs, no battle-tested library. Implementation looks careful (12-hour TTL, HttpOnly, SameSite=Lax, Secure in prod, fail-closed on missing `AUTH_SECRET`, `timingSafeEqual` for pixel HMAC). Worth an independent `/security-review` pass.
- **Two HMAC secrets** in production env: `AUTH_SECRET` (session cookie), `PIXEL_INGEST_SECRET` (Meta CAPI / GA4 / TikTok). Rotation procedure not in the runbook — verify before launch.
- **Shopify access tokens** for two stores (`SHOPIFY_AL_BAYAA_ACCESS_TOKEN`, `SHOPIFY_ZAHWA_ACCESS_TOKEN`) live in env; rotation playbook not in the runbook.
- **Seed user defaults** — `owner@example.com` / `ChangeMe123!` are placeholders explicitly flagged in README + `.env.example` ("rotate before any non-local deployment"). Pre-launch gate: confirm the real OWNER was created and the seeded one was archived.
- **No SAST in CI** — Quality Gate runs lint/typecheck/test/build but no Semgrep / CodeQL / npm audit step.

### Dependencies

- **`xlsx` library** (workbook ingest) has historical advisories (prototype pollution, ReDoS in 2023-2024). Confirm pinned version is patched; consider migrating to `exceljs` if not.
- **Next.js 16.2** — brand-new major (Next 16 GA was recent). Watch for ecosystem catch-up on `eslint-config-next`, Prisma generator, etc.
- **React 19** — first major adoption; check that any third-party React deps support it.
- **No dependency audit** has been run under apexyard governance yet — run `/audit-deps` to baseline.

### Technical debt

- **Project has its own `CLAUDE.md`, `.claude/agents/`, `.claude/skills/`, `.claude/commands/`** with strict architectural rules (finance posting via `posting.service`, no math in `.tsx`, etc.). Excellent in-repo governance — but it overlaps with apexyard. Decide which is authoritative when both apply (current default per `CLAUDE.md`: the project's own rules outrank user requests; apexyard adds portfolio-level checks on top).
- **Customers service not extracted** yet — customer search / creation / AR aggregation sits inside `sales.service.ts`. Project's own `docs/ARCHITECTURE.md` flags this as Phase 4 work.
- **Reports cross-footing** — `docs/ARCHITECTURE.md` Phase 7 work is to re-source reports from `JournalLine` so reports tie to the trial balance.
- **No public API contract** (OpenAPI / typed client) — 121 routes consumed by the same Next.js frontend; fine while monolithic, worth documenting if a mobile client appears.

### Operational

- **No observability stack** — no Sentry / Datadog / OpenTelemetry / structured-log shipper in `package.json`. `docs/LOGGING_POLICY.md` exists (read it before deciding) but the production wiring isn't visible.
- **No deployment infra-as-code committed** — no `Dockerfile`, no `docker-compose.yml`, no `vercel.json`, no Terraform. Deploy convention is "Vercel + a managed Postgres (Neon / Supabase / Railway / RDS)" per README. Fine for the current shape; codify before adding a second environment.
- **No alerting** visible — production error budget / SLO not defined.
- **CI is a single workflow** (`quality-gate.yml`) — solid baseline, but no SAST / dependency-audit / migration-dry-run jobs yet.
- **Backups** — `docs/INTERNAL_LAUNCH_RUNBOOK.md` is the place to confirm; not assessed here.

## Integration Plan

### Roles that apply

Derived from the tech stack + CI + security surface:

- **tech-lead** — always.
- **backend-engineer** — 121 API routes + 61 services + complex Prisma schema.
- **frontend-engineer** — Next.js App Router pages + React 19 components.
- **platform-engineer** — GitHub Actions Quality Gate; CI will be touched as more pipelines come in.
- **data-engineer** — 57 models, 24 migrations, weighted-average cost, double-entry ledger; schema and migration discipline is load-bearing.
- **security-auditor** — custom HMAC auth + pixel ingest + Shopify tokens + workbook ingest path.
- **sre** — production launch readiness (observability, runbooks, on-call) is genuinely open.
- **head-of-product** + **qa-engineer** + **data-analyst** — already on the registry; aligned with the project's needs (acceptance criteria, regression coverage, P&L verification).

The registry today lists: `head-of-product, tech-lead, backend-engineer, frontend-engineer, qa-engineer, security-auditor, data-analyst`. **Recommended additions**: `platform-engineer`, `sre`, `data-engineer`.

### Workflows that kick in

- [ ] PR workflow (`.claude/rules/pr-workflow.md`) — every change through a PR (project already enforces this via its `quality-gate.yml`).
- [ ] AgDR (`/decide`) for new technical decisions — the project has its own `docs/DECISIONS_LOG.md`; treat AgDRs as the *apexyard-portfolio-level* layer (cross-project visibility via `/agdr`), the in-repo log as the day-to-day source of truth.
- [ ] Code Reviewer agent (Rex) on every PR.
- [ ] Security Reviewer agent (Hatim) on first pass + auth / pixel-ingest / Shopify diffs.
- [ ] `/audit-deps` on adoption and monthly thereafter.
- [ ] Migration gate (`/migration` + AgDR) for any further Prisma schema work.
- [ ] QA gate — merged PR → ticket moves to `qa`, not Done.

### Hooks to enable

These run automatically from the ops-fork `.claude/settings.json` when working *under apexyard*. Inside the cloned workspace they apply to `Edit` / `Write` / `Bash` issued from this session:

- [ ] `block-git-add-all` — already a project rule via the safety script.
- [ ] `block-main-push` — already a project rule (no direct merges to `main`).
- [ ] `validate-branch-name` — `ticket_prefix: GH` (per registry); branch format `{type}/#{NN}-{description}`.
- [ ] `validate-pr-create` — single ticket per PR title.
- [ ] `pre-push-gate` — lint / typecheck / test / build before push (already in project workflow).
- [ ] `check-secrets` — backstop the project's `scripts/check-git-safety.mjs`.
- [ ] `require-migration-ticket` — gate edits under `prisma/migrations/` and `prisma/schema.prisma` on a labelled migration ticket + AgDR.
- [ ] `block-private-refs-in-public-repos` — leak protection if any work touches the public apexyard tracker.

### CI templates to consider

The project ships a clean `quality-gate.yml` already. Layer apexyard pipelines as additive workflows (don't replace what works):

- [ ] `golden-paths/pipelines/security.yml` — Semgrep SAST + `npm audit` + secrets scan (closes the no-SAST gap).
- [ ] `golden-paths/pipelines/dependency-audit.yml` — weekly vulnerability + license scan.
- [ ] `golden-paths/pipelines/pr-title-check.yml` — enforce ticket ID in PR titles (current titles already follow the pattern; this codifies it).
- [ ] `golden-paths/pipelines/review-check.yml` — block merge until Rex has reviewed the latest commit.

### Registry entry

Project is **already in** `apexyard.projects.yaml`:

```yaml
- name: ecommerce-accountant-software
  repo: GOkasha/ecommerce-accountant-software
  docs: projects/ecommerce-accountant-software
  status: handover
  tier: P0
  roles:
    - head-of-product
    - tech-lead
    - backend-engineer
    - frontend-engineer
    - qa-engineer
    - security-auditor
    - data-analyst
  tags:
    - ecommerce
    - accounting
    - inventory
    - shopify
    - perfume-business
    - egypt
  ticket_prefix: GH
```

**Suggested updates** (apply manually — handover doesn't mutate an existing registry entry):

- Add `workspace: workspace/ecommerce-accountant-software` so portfolio skills pick up the local clone.
- Add `platform-engineer`, `sre`, `data-engineer` to `roles`.

## Next Steps

Top dynamic actions derived from the risks above:

1. `/audit-deps ecommerce-accountant-software` — triage the `xlsx` library historical CVEs and baseline Next 16 + React 19 dep tree before any new feature work.
2. Run `npm install && npm run typecheck && npm run test && npm run lint && npm run build` locally — confirm baseline is green on this machine (this assessment did not attempt the build).
3. `/decide` on observability — Sentry vs Datadog vs Vercel Analytics + log drain (project ships without an APM today; `docs/LOGGING_POLICY.md` is the input).
4. `/security-review` the auth + pixel-ingest + Shopify-token surface as Hatim — custom HMAC session cookies + dual HMAC secrets warrant an independent pass.
5. `/threat-model` the full app — produce a DFD with trust boundaries (admin, Shopify, pixel ingest, workbook import) and run STRIDE.
6. `/code-review` PR #147 (latest merged) retrospectively as Rex — calibrates review standards on the project's own conventions.
7. Reconcile project `CLAUDE.md` ↔ apexyard governance — write an AgDR documenting that the project's in-repo rules are authoritative for code conventions, and apexyard adds portfolio-level governance (registry, cross-project AgDRs, stakeholder updates) on top.
8. Add `ecommerce-accountant-software` to the weekly `/stakeholder-update` rollup.

## Post-Handover Checklist

- [ ] Review this assessment with GOkasha (the project owner) — confirm risks + agreed next steps.
- [ ] `/audit-deps` baseline — close any High / Critical findings before the first apexyard-governed feature PR.
- [ ] Update the registry entry with `workspace:` + the additional roles (see "Suggested updates" above).
- [ ] Set a coverage baseline by running `npm test -- --coverage` and committing the threshold the team is willing to defend.
- [ ] Schedule `/audit-deps` monthly for the next 3 months.
- [ ] Decide observability stack + wire it up before any production-bound deploy.
- [ ] Run `/security-review` on the auth + pixel-ingest surface.
- [ ] Run `/threat-model` and produce a DFD under `projects/ecommerce-accountant-software/architecture/dfd.md`.
- [ ] Onboard `platform-engineer`, `sre`, `data-engineer` into the project's review rotation.
- [ ] Add this project to the weekly `/stakeholder-update` rollup.

## Open Questions

- **Authority of `CLAUDE.md`** — when working on this codebase under apexyard, the project's own `CLAUDE.md` is strict and well-considered. Confirm with GOkasha that apexyard layers *on top* (portfolio governance, cross-project AgDRs, stakeholder updates) and does not override the in-repo rules. Worth an AgDR.
- **Production target** — README mentions Vercel + Neon / Supabase / Railway / RDS. Which is the actual target? Affects observability, secret store, and runbook contents.
- **Backup posture** — `docs/INTERNAL_LAUNCH_RUNBOOK.md` is the right place; confirm RPO / RTO are set and tested.
- **PII surface** — Egyptian customer data (names, addresses, phones for COD) is collected. Confirm scope and any local data-protection obligations (Egypt's Personal Data Protection Law 151 of 2020).
- **Shopify webhook signature verification** — `docs/ARCHITECTURE.md` mentions "Phase 5 HMAC verification" for Shopify; confirm phase status before treating webhooks as trusted.
- **Coverage threshold** — what minimum coverage is the team committing to? (apexyard default is 80% for domain logic.)
- **Existing `tier: P0`** — the registry pins this as P0. Confirm SLA expectations match (incident response time, on-call coverage).
