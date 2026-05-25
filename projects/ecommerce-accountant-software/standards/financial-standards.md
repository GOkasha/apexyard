# Financial Standards — ecommerce-accountant-software

> **What this is.** The project-scoped source of truth that `/cfo-financial-gate`
> (persona **Yusuf**, the CFO / Financial Controller) audits against. It **encodes
> existing policy** already written in the app's own docs — it does **not** create
> new accounting policy. Where the app has an unresolved accounting question, this
> file lists it as *awaiting a written decision*, never as settled.
>
> **Authority.** Per [`../governance.md`](../governance.md) §1, the app's in-repo
> rules win for code conventions. This doc is the portfolio-level *checklist* layer;
> the in-repo `ecommerce-accounting-rules` skill + `finance-accounting-reviewer`
> agent remain the per-diff reviewers. The two layers are additive.
>
> **Primary sources** (inside `workspace/ecommerce-accountant-software/`):
> `CLAUDE.md` (hard rules 1–6), `docs/ARCHITECTURE.md`,
> `docs/FINANCIAL_LOGIC_BLUEPRINT.md` (§4 universal invariants, §7 open questions),
> `docs/TESTING_RULES.md`, `docs/DATA_SAFETY_AND_MIGRATION.md`.

Each standard has: **Rule** · **Why it matters** · **How the gate checks it** · **Anchor** (real file/symbol confirmed in the codebase). Findings cite `file:line`.

---

## Severity vocabulary

| Tier | Meaning |
|------|---------|
| **P0** | Ledger-corrupting / money created or destroyed / unbalanced posting / liability lost. Blocks go-live and blocks the customer-credit work. |
| **P1** | Correctness or source-of-truth risk that must be resolved before real-data go-live. |
| **P2** | Hardening / consistency gap — fix in the next sprint. |
| **P3** | Advisory / observability / documentation. |

---

## 1. Money flows post a balanced journal

- **Rule**: Every money flow posts a balanced `JournalEntry` with ≥ 2 `JournalLine`s, debits = credits within 1¢.
- **Why**: Double-entry is the integrity guarantee; an unbalanced entry corrupts the trial balance and every report sourced from it.
- **How checked**: Confirm the flow routes through `postJournal()`, which throws if `|Dr − Cr| > 0.01`. Look for money-affecting writes with no paired entry.
- **Anchor**: `src/lib/services/posting.service.ts` → `postJournal()`; `FINANCIAL_LOGIC_BLUEPRINT.md` §4 invariant 1.

## 2. Operational write + journal + audit are atomic

- **Rule**: The originating write (order / payment / return / expense / stock movement), its journal posting, and its audit-log row live in a single `prisma.$transaction`.
- **Why**: A journal that commits without its operational row (or vice versa) leaves the ledger and the operational tables disagreeing — silently.
- **How checked**: For each posting helper call, confirm it shares the caller's transaction client (`db: Db`), not a fresh `prisma`. The helpers' doc-comments state "MUST be called inside the same transaction."
- **Anchor**: `posting.service.ts` helper contracts; `FINANCIAL_LOGIC_BLUEPRINT.md` §4 invariants 2 & 10; `$transaction` used across the service layer.

## 3. Audit actor comes from the verified session, not headers

- **Rule**: `AuditLog.actor_id` and `JournalEntry.posted_by_id` are populated from the verified session user, never from a client-supplied / spoofable header.
- **Why**: Repudiation. An attacker-set "who did this" defeats the audit trail.
- **How checked**: Trace `actor_id` / `posted_by_id` back to the session resolver, not to `req.headers`.
- **Anchor**: `prisma/schema.prisma` → `model AuditLog { actor_id … actor User? }`; `src/lib/services/audit.service.ts`; the app's custom HMAC session layer.

## 4. `current_avg_cost` is not overwritten by imports or generic update paths

- **Rule**: `Product.current_avg_cost` is written **only** by the purchase-receipt path. Workbook imports, generic product-update endpoints, and Shopify sync must not write it.
- **Why**: WAC is the basis for COGS and inventory valuation; a stray overwrite silently mis-states profit and the balance sheet.
- **How checked**: `current_avg_cost` appears across ~9 services — audit each occurrence as **read vs. write**. Only `purchasing.service` may *write*; everything else must only *read*.
- **Anchor**: `FINANCIAL_LOGIC_BLUEPRINT.md` §4 invariant 9; occurrences in `inventory.service.ts`, `sales.service.ts`, `product.service.ts`, `shopify.service.ts`, `import-review.service.ts`, `dashboard-charts.service.ts`, `vendor.service.ts`, `purchasing.service.ts`.

## 5. Official product cost comes from purchase receipts / WAC

- **Rule**: The authoritative unit cost is set at goods-receipt time via weighted-average cost in `receivePurchaseOrder`.
- **Why**: Single, auditable cost basis; no "estimated" cost leaking into the ledger.
- **How checked**: Confirm the only writer of `current_avg_cost` is the receipt path, and that the WAC formula folds new receipt qty × price into the running average.
- **Anchor**: `src/lib/services/purchasing.service.ts` → `receivePurchaseOrder`; `PurchaseReceipt` / `PurchaseReceiptLine` models.

## 6. COGS uses `cogs_snapshot` captured at sale/fulfillment

- **Rule**: COGS posts from `SalesOrderLine.cogs_snapshot` captured at fulfillment, **never** from live `current_avg_cost` at report time.
- **Why**: Cost drifts after the sale; reading live cost would restate historical margin every time inventory is received.
- **How checked**: Confirm the COGS journal sums `cogs_snapshot` (line total, not unit × qty again) and that nothing re-derives COGS from live cost.
- **Anchor**: `posting.service.ts` → `postSalesCogsJournal()`; `FINANCIAL_LOGIC_BLUEPRINT.md` §4 invariant 8.

## 7. Stock quantity truth comes from `StockMovement`

- **Rule**: On-hand quantity is derived from `StockMovement` rows. Manual edits to a product-level quantity field are not the source of truth.
- **Why**: An append-only movement log is auditable and reconcilable; a mutable scalar is not.
- **How checked**: Confirm quantity reads aggregate `StockMovement`; flag any direct write to a product quantity scalar that bypasses a movement.
- **Anchor**: `prisma/schema.prisma` → `model StockMovement`, `enum StockMovementType`; `src/lib/services/inventory.service.ts`.

## 8. Customer receivable KPIs use the approved summary source

- **Rule**: AR / receivable KPIs read from `summaries.service` (`customer_summary`) or another approved source — **not** the denormalised `Customer.open_receivable` / `amount_paid` / `gross_order_value` fields, which can go stale.
- **Why**: Denormalised counters drift from the ledger; reporting on them undermines trust in the numbers.
- **How checked**: Confirm KPI/report reads route through `summaries.service.ts`; flag report code reading the denormalised `Customer.*` rollups directly.
- **Anchor**: `src/lib/services/summaries.service.ts` (`customer_summary`); `prisma/schema.prisma` → `model Customer { … open_receivable amount_paid gross_order_value … }`.

## 9. Customer overpayments get explicit credit / deposit treatment

- **Rule**: When a customer pays more than they owe, the excess becomes an explicit **Customer Credit / Deposit liability** — it must **not** disappear into a zeroed/negative AR.
- **Why**: Overpayment is money the business owes back; hiding it in AR understates liabilities and can silently lose customer money.
- **How checked**: Trace the customer-payment path: when `amount > amount_due`, where does the excess go? Flag any path that floors AR at zero and drops the remainder.
- **Anchor**: `posting.service.ts` → `postCustomerPaymentJournal()` (today credits `1100` only); `CustomerPayment` model; `FINANCIAL_LOGIC_BLUEPRINT.md` §7 open question #4. **This is the gap the upcoming work must close — verify, don't assume.**

## 10. Prepayments / deposits get explicit liability accounting

- **Rule**: Customer prepayments and deposits post to a liability account (`2200 Customer deposits`, per-customer sub-account), not to revenue.
- **Why**: Cash received before delivery is a liability, not earned revenue; recognising it as revenue overstates the P&L.
- **How checked**: Confirm prepayment flows credit `2200` (per-customer), and revenue is only recognised at the documented recognition point. Flag any prepayment that hits `4000`.
- **Anchor**: chart-of-accounts `2200 Customer deposits` in `posting.service.ts` `DEFAULT_ACCOUNTS`; `FINANCIAL_LOGIC_BLUEPRINT.md` §7 #4 (per-customer sub-account recommended, not yet wired).

## 11. Customer-credit refunds reverse liability → cash/bank

- **Rule**: Refunding a customer credit / deposit debits the `2200` liability and credits cash/bank — it must not touch `4200` refunds-contra-revenue (that's for sale returns) or vanish.
- **Why**: A credit refund settles a liability; mis-routing it through contra-revenue double-counts against sales.
- **How checked**: Confirm the credit-refund path is distinct from the sale-return refund path (`postReturnRefundJournal` uses `4200`); a deposit refund must reduce `2200`.
- **Anchor**: `posting.service.ts` → `postReturnRefundJournal()` (sale returns, `4200`) vs. the (to-be-built) credit-refund path against `2200`.

## 12. Supplier payable logic is consistent with receipt/payment flows

- **Rule**: AP arises at goods-receipt; supplier payments (single, split, partner-funded) reduce AP `2000` consistently and never create/destroy money.
- **Why**: Inconsistent AP handling mis-states what the business owes and corrupts cash reconciliation.
- **How checked**: Confirm receipt posts `Dr 1200 / Cr 2000`; payments post `Dr 2000 / Cr <cash>`; partner-funded splits reconcile per the blueprint matrix.
- **Anchor**: `src/lib/services/purchasing.service.ts`; `SupplierPayment` model; `FINANCIAL_LOGIC_BLUEPRINT.md` §3.8–3.14.

## 13. Shopify is a channel, not the accounting source of truth

- **Rule**: The ledger lives in this app's `JournalEntry`/`JournalLine`. Shopify-imported orders go through the **same** posting path as manual orders.
- **Why**: Treating Shopify totals as authoritative bypasses double-entry and lets the channel dictate the books.
- **How checked**: Confirm webhook/imported orders call the same posting helpers; flag any Shopify-specific shortcut that writes financials directly.
- **Anchor**: app `CLAUDE.md` hard rule 3; `shopify.service.ts`; `FINANCIAL_LOGIC_BLUEPRINT.md` §2.2.38 (imported-order ledger posting).

## 14. No financial math in UI components

- **Rule**: Margins, totals, COGS, and any money arithmetic live in a service; `.tsx` reads pre-computed numbers.
- **Why**: Duplicated/divergent math in the UI produces numbers that don't tie to the ledger.
- **How checked**: Grep `.tsx` for arithmetic on money fields (`* qty`, margin/total computation); flag any.
- **Anchor**: app `CLAUDE.md` hard rule 1; `docs/ARCHITECTURE.md`.

## 15. Chart-of-account changes require accounting/migration review

- **Rule**: Adding or removing an account code is a deliberate accounting decision, made via `ensureChartOfAccounts()` (never raw insert), and reviewed.
- **Why**: Account codes are referenced by every posting helper; an ad-hoc code change can silently break postings or split a balance.
- **How checked**: Confirm new codes are added to `DEFAULT_ACCOUNTS` + `ensureChartOfAccounts()`; flag hardcoded `account_id`s or raw `accountingAccount.create` outside that helper.
- **Anchor**: `posting.service.ts` → `DEFAULT_ACCOUNTS`, `ensureChartOfAccounts()`; `FINANCIAL_LOGIC_BLUEPRINT.md` §4 invariant 4.

## 16. Schema / migration changes require a migration ticket + Migration AgDR

- **Rule**: Any `prisma/schema.prisma` or `prisma/migrations/**` change needs a labelled migration ticket and a Migration AgDR before edits.
- **Why**: High blast radius (data loss, downtime, lock contention); rollback must be articulated *before* the work.
- **How checked**: For schema-touching follow-ups, confirm the gate routes the recommendation through `/migration` (it never edits schema itself).
- **Anchor**: ApexYard migration gate (`require-migration-ticket.sh`, `/migration`); app `CLAUDE.md` hard rule 5 + `docs/DATA_SAFETY_AND_MIGRATION.md`.

## 17. No new accounting rules invented during ordinary feature work

- **Rule**: Open accounting questions (revenue-recognition timing, per-partner equity split, customer-credit treatment, refund routing, etc.) require a written decision in `docs/DECISIONS_LOG.md` before code is wired. Feature work must not silently settle them.
- **Why**: An accounting rule chosen implicitly in a PR is unauditable and may be wrong.
- **How checked**: Cross-reference the change against `FINANCIAL_LOGIC_BLUEPRINT.md` §7 open questions; if the change resolves one without a logged decision, flag P0/P1 and recommend the decision be recorded first.
- **Anchor**: `FINANCIAL_LOGIC_BLUEPRINT.md` §7 (10 open questions, incl. #4 customer credit vs. cash refund); `docs/DECISIONS_LOG.md`.

---

## Open accounting questions in scope for the upcoming work (verify, don't assume)

From `FINANCIAL_LOGIC_BLUEPRINT.md` §7 — these are **unresolved** and directly relevant to the customer credit / prepayment / refund work the gate is meant to precede:

- **#1** Revenue at order creation vs. at fulfillment — conflict between the operating model and today's code path.
- **#4** Customer credit balance vs. cash refund — `2200 Customer deposits` exists; per-customer sub-accounting **not yet wired**.
- **#8** Refund routing — original payment method vs. operator choice.

Any PR that touches these without a logged `DECISIONS_LOG.md` decision is, by Standard 17, at least a P1.
