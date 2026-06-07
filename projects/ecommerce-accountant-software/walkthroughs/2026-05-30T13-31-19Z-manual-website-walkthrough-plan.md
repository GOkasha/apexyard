# Manual Website Walkthrough Plan — Ecommerce Accountant Software

**Generated**: 2026-05-30T13:31:19Z
**Repo**: `D:\Apexyard\apexyard\workspace\ecommerce-accountant-software`
**App HEAD at time of plan**: `a53f42c` on `main` (post-GH-188 merge)
**Mode**: READ-ONLY analysis — no edits, no branches, no commits, no issues filed
**Purpose**: Find what works, what's broken, what should be removed, what needs UX improvement, what touches accounting / inventory risk — before real data entry.

---

## Pre-flight state (at time of plan)

- App repo on `main`, up to date with `origin/main`, working tree clean (only gitignored `.claude/session/` showing as untracked).
- Latest commit: `a53f42c fix: roll up customer deposit subaccounts into balance sheet liabilities (#189)`.
- Ops repo on `docs/GH-12-persist-cfo-audit-artifact`, unchanged.

---

# A. Page-by-page walkthrough checklist

> **Sources of truth used to build this list**: `src/components/app-shell.tsx` (the canonical `NAV` array exported for tests), `src/app/**/page.tsx` (44 real route files), `src/lib/ui/module-definitions.ts` (the 14 generic-template `[module]` slugs), and `docs/FINANCIAL_LOGIC_BLUEPRINT.md` (which money/inventory flows post journals).
>
> **Legend**:
> - **Data**: `real` = backed by Prisma queries / ledger reads, `demo` = `module-definitions.ts` hardcoded rows/metrics, `unknown` = mixed or needs eyes-on confirmation.
> - **Money** / **Inventory** / **AuditLog**: marks whether a successful action on the page WRITES to the ledger, stock_movements, or audit_logs. Read-only views are noted explicitly.

---

## 1. Dashboard

### `/` — Dashboard

| Field | Value |
|---|---|
| Business purpose | Headline KPIs + revenue trend + stock-mix + low-stock + work queues |
| Operator | Every authenticated role (`dashboard:read`) |
| What to test | Page loads; 6 KPI cards render real numbers; revenue bars span ~30 days with at least some non-zero bars if you have history; low-stock table has stable column count; "Work queues" panel shows realistic counts; "New order" and "Reports" buttons in the header navigate correctly |
| Expected | Numbers match `/reports/pnl` for the same date window; `total_revenue` + `gross_profit` post-GH-188 now read via `getLedgerPnlSummary` (not raw `$queryRaw` aggregates); Customer Deposits surfaces correctly in `/reports/balance-sheet` |
| Money impact | Read-only |
| Inventory impact | Read-only |
| AuditLog | None |
| Data | real (via `getDashboardViewData`) |
| Risk if broken | **P0** — the page the operator opens every morning |
| Action | **Keep** + **Needs accounting review** (verify dashboard ↔ /reports/pnl ↔ /reports/balance-sheet parity for the same period) |

---

## 2. POS / sales creation

### `/orders/new` — New order / POS checkout

| Field | Value |
|---|---|
| Business purpose | Create either a standard order (revenue at fulfillment) or a POS checkout (immediate cash + fulfill) |
| Operator | `orders:write` |
| What to test | Submit a POS sale with CASH; submit one with INSTAPAY; submit a standard order with `amount_paid=0` (UNPAID); submit a multi-line order; test discount line; test add customer inline; test ATS / out-of-stock blocking; test cancel-flow exit |
| Expected | POS posts 3 entries per line: revenue (Dr 1100 / Cr 4000), COGS (Dr 5000 / Cr 1200), cash receipt (Dr 1000/1010/1020 / Cr 1100); standard order posts only revenue + COGS, AR remains until payment lands |
| Money impact | **HIGH** — every line creates posting + AR movement |
| Inventory impact | **HIGH** — fulfillment writes `stock_movement` OUT of `fulfillment_location_id` |
| AuditLog | Yes — `CREATE order`, `CREATE journal_entry`, `CREATE stock_movement` |
| Data | real |
| Risk if broken | **P0** — primary cash-in flow |
| Action | **Keep** + **Needs accounting review** + **Needs inventory review** |

---

## 3. Orders

### `/orders` — Order list

| Field | Value |
|---|---|
| Business purpose | Browse / search / filter orders |
| What to test | Filters by status, channel, date range, payment method; sort; pagination; "Open" / "Detail" links open correct order; column totals; CANCELLED-vs-not exclusion in summary stats |
| Expected | List reflects current Prisma data |
| Money impact | Read-only |
| Inventory impact | Read-only |
| AuditLog | Read-only |
| Data | real |
| Risk | **P1** |
| Action | **Keep** + **UX polish** (filter combinatorics often need review) |

### `/orders/[id]` — Order detail + lifecycle controls

| Field | Value |
|---|---|
| Business purpose | View order + fulfill / cancel / refund actions |
| What to test | Fulfill UNPAID order → revenue + COGS post, stock moves out; cancel partly-fulfilled → reversal journal posts proportionally per `DECISIONS_LOG`; record customer payment from order page; navigate to printable views |
| Expected | Per `FINANCIAL_LOGIC_BLUEPRINT §3.25`: cancellation creates a fresh reverse entry, original stays |
| Money impact | **HIGH** (lifecycle controls trigger postings) |
| Inventory impact | **HIGH** (fulfill / cancel) |
| AuditLog | Yes per action |
| Data | real |
| Risk | **P0** |
| Action | **Keep** + **Needs accounting review** + **Needs inventory review** |

### `/orders/[id]/invoice`, `/packing-slip`, `/receipt` — Print formats

| Field | Value |
|---|---|
| Business purpose | Printable layouts |
| What to test | All three render without errors; totals match order header; line-item rounding; print-CSS in browser print preview |
| Expected | No interactive controls; numbers identical to order detail |
| Money / Inventory / AuditLog | Read-only |
| Data | real |
| Risk | **P3** |
| Action | **Keep** + **UX polish** (print layout) |

---

## 4. Customers

### `/customers` — Customer list

| Field | Value |
|---|---|
| Business purpose | Browse customers |
| What to test | Search by phone / name; click row → detail; "new customer" inline create from elsewhere; pagination |
| Money / Inventory | Read-only |
| AuditLog | Read-only |
| Data | real |
| Risk | **P1** |
| Action | **Keep** + **UX polish** |

### `/customers/[id]` — Customer detail

| Field | Value |
|---|---|
| Business purpose | Per-customer history + open AR + customer-credit balance |
| What to test | Open receivable matches `1100 AR` for this customer; **customer-credit / deposit balance** (per `2200-{customer_code}` ledger) is shown distinctly from AR per DECISIONS_LOG §22 #9; order list filtered correctly; CSV / activity export if any |
| Money | Read-only DISPLAY of money state |
| Inventory | None |
| AuditLog | Read-only |
| Data | unknown — **the customer_summary credit balance is per CFO audit a documented gap** (carved out of GH-188 scope); needs verification |
| Risk | **P1** — wrong AR / deposit display silently misleads collections decisions |
| Action | **Needs accounting review** — confirm per-customer `2200-{customer_code}` balance is surfaced; if NOT, file a follow-up (the CFO ticket already flagged this area) |

---

## 5. Receivables / customer payments

### `/receivables` — Receivables / customer payment entry

| Field | Value |
|---|---|
| Business purpose | Browse open AR + record customer payments |
| What to test | Record payment ≤ open receivable → `Dr cash / Cr 1100`; record OVERPAYMENT (e.g. AR=100, pay 150) → split: `Dr 1000=150 / Cr 1100=100 / Cr 2200-{code}=50` per GH-186; record STANDALONE PREPAYMENT (no order) → `Dr 1000 / Cr 2200-{code}`; payment method routing (CASH→1000, INSTAPAY→1010, MOBILE WALLET→1020); audit row written |
| Expected | Trial balance stays balanced; balance sheet Customer Deposits surfaces the deposit (post-GH-188); customer's `open_receivable` is NEVER clamped to hide negative AR |
| Money impact | **HIGH** |
| Inventory impact | None |
| AuditLog | Yes |
| Data | real |
| Risk | **P0** — combines GH-186 (posting) and GH-188 (reporting) |
| Action | **Keep** + **Needs accounting review** (verify split UX is obvious; confirm a normal payment does NOT post a deposit) |

---

## 6. Returns / refunds / damage

### `/returns-damage` — Returns + damaged returns

| Field | Value |
|---|---|
| Business purpose | Sellable returns (restock) + damaged returns (write-off) |
| What to test | SELLABLE return on POS → refund cash + restock to sellable location; DAMAGED return → refund cash + reclassify cost from `5000 COGS` to `5100 Stock Loss`; partial-quantity return; AR-first refund split (per FINANCIAL_LOGIC_BLUEPRINT §3.7); refund to original payment method vs operator override |
| Expected | Refund journal posts `Dr 4200 / Cr cash` (or `Cr 1100` if AR open); damaged reclass moves cost to `5100`; restock writes `stock_movement` IN to sellable location, NOT to damaged location |
| Money impact | **HIGH** |
| Inventory impact | **HIGH** |
| AuditLog | Yes (return event + journal + stock movement) |
| Data | real |
| Risk | **P0** |
| Action | **Keep** + **Needs accounting review** + **Needs inventory review** |

---

## 7. Products / catalog

### `/catalog` — Product list

| Field | Value |
|---|---|
| Business purpose | Browse products |
| What to test | Search by SKU / name / vendor; filter by sales channel; assortment status flags; sort by stock value |
| Money / Inventory / AuditLog | Read-only |
| Data | real |
| Risk | **P1** |
| Action | **Keep** + **UX polish** |

### `/catalog/new` and `/catalog/[id]` — Create / edit product

| Field | Value |
|---|---|
| Business purpose | SKU + pricing + assortment + Shopify mapping |
| What to test | Required-field validation; SKU uniqueness; current_avg_cost cannot be edited directly (changes only via PO receive / opening balance); assortment toggles propagate to Shopify if linked; ext_id idempotency |
| Money impact | **MEDIUM** — `current_avg_cost` is WAC; changing it affects future COGS snapshots. If the form exposes a direct edit, that is a **P0 finding**. |
| Inventory impact | Indirect (per-location stock managed elsewhere) |
| AuditLog | Yes on save |
| Data | real |
| Risk | **P1** (P0 if WAC editable directly) |
| Action | **Keep** + **Needs accounting review** (confirm WAC is read-only on the form) |

### `/labels/[productId]` — Print product labels / barcodes

| Field | Value |
|---|---|
| Business purpose | Barcode printing (Code128) |
| What to test | Page loads; QR / barcode renders; print preview |
| Money / Inventory / AuditLog | None |
| Data | real |
| Risk | **P3** |
| Action | **Keep** |

---

## 8. Inventory / stock / locations / transfers

### `/products/inventory` — Inventory by SKU × location

| Field | Value |
|---|---|
| Business purpose | Stock-on-hand grid |
| What to test | Per-location quantities reconcile to `stock_movements` sum; ATS calculation excludes reserved; refresh after a transfer / fulfillment reflects new totals |
| Money / Inventory | Read-only |
| AuditLog | Read-only |
| Data | real |
| Risk | **P1** |
| Action | **Keep** |

### `/products/locations` and `/products/locations/[id]` — Locations CRUD

| Field | Value |
|---|---|
| Business purpose | Warehouses, stores, damaged-quarantine |
| What to test | Create location; toggle `used_for_ats`; toggle `type` (WAREHOUSE / DAMAGED / etc.); archive blocks future use; "DMG-01" present as the damaged-return target |
| Money | None |
| Inventory | **HIGH** structural impact — `used_for_ats=false` excludes from ATS; type=DAMAGED is the target of damaged-return restock |
| AuditLog | Yes on edit |
| Data | real |
| Risk | **P1** |
| Action | **Keep** + **Needs inventory review** (confirm DAMAGED + ATS flags behave per the operating model) |

### `/products/transfers` — Stock transfers between locations

| Field | Value |
|---|---|
| Business purpose | Move stock from one location to another |
| What to test | One-step transfer; multi-line; cancel mid-transfer; transfer FROM a non-ATS location; transfer TO a DAMAGED location (should likely be blocked) |
| Money | None (transfers do not touch P&L) |
| Inventory | **HIGH** — one balanced from/to stock_movement pair |
| AuditLog | Yes |
| Data | real |
| Risk | **P1** |
| Action | **Keep** + **Needs inventory review** |

### `/stock-count` — Cycle count adjustments **(dynamic [module] page)**

| Field | Value |
|---|---|
| Business purpose | Post +/− stock-count adjustment with reason |
| What to test | What actually renders — this URL falls through to `[module]/page.tsx` with the demo `stock-count` slug from `module-definitions.ts`. Confirm whether real cycle-count tooling exists or it's just the demo template |
| Money | Indirect (inventory value changes) |
| Inventory | **HIGH** if real |
| AuditLog | Yes if real |
| Data | **demo** (metrics hardcoded in `module-definitions.ts:140-145`) — needs eyes-on to confirm if `getLiveModuleData('stock-count')` returns anything real |
| Risk | **P0** — adjustments silently change inventory value |
| Action | **Investigate first** → likely **Fix** (real form needed) or **Remove** if not used; **Needs accounting review** + **Needs inventory review** |

---

## 9. Purchasing / suppliers / supplier payments

### `/products/suppliers` and `/products/suppliers/[id]` — Suppliers

| Field | Value |
|---|---|
| Business purpose | Supplier master |
| What to test | Create; edit; archive; open PO count; outstanding payable; payment terms display |
| Money | Indirect (drives AP) |
| Inventory | None |
| AuditLog | Yes on edit |
| Data | real |
| Risk | **P1** |
| Action | **Keep** |

### `/products/purchase-orders`, `/new`, `/[id]` — Purchase orders

| Field | Value |
|---|---|
| Business purpose | Create + receive POs (updates WAC + posts AP) |
| What to test | Create PO; receive ALL lines; receive PARTIAL; receive with cost change → WAC weighted-average update; supplier payment from PO detail; cancel partly-received PO |
| Money | **HIGH** — receiving posts `Dr 1200 Inventory / Cr 2000 AP`; payment posts `Dr 2000 / Cr cash`; supplier-deposit prepayment posts `Dr 1300 / Cr cash` |
| Inventory | **HIGH** — stock_movement IN; WAC recomputed |
| AuditLog | Yes |
| Data | real |
| Risk | **P0** |
| Action | **Keep** + **Needs accounting review** + **Needs inventory review** (WAC math is the most error-prone surface) |

### `/products/vendors` and `/products/vendors/[id]` — Vendors

| Field | Value |
|---|---|
| Business purpose | Vendor master (distinct from `suppliers` in the navigation — clarify the difference) |
| What to test | Confirm the entity model; is "vendor" a wholesale-distributor concept or a duplicate of "supplier"? |
| Money / Inventory / AuditLog | Unknown without page-load |
| Data | unknown |
| Risk | **P2** |
| Action | **Investigate** → possibly **Remove** if duplicate of Suppliers, or **Keep** with a UX rename if distinct |

### `/products/sales-channels` — Sales channels

| Field | Value |
|---|---|
| Business purpose | Channel master (POS, Shopify, online, wholesale, etc.) |
| What to test | Create / archive; channel-PnL drill-through |
| Money / Inventory | None direct |
| AuditLog | Yes on edit |
| Data | real |
| Risk | **P2** |
| Action | **Keep** |

### `/products/import` and `/products/export` — Bulk operations

| Field | Value |
|---|---|
| Business purpose | Workbook-based bulk import / sample export |
| What to test | Upload sample; validation errors surface row-by-row; idempotency on re-upload; downstream Prisma rows match preview |
| Money | Indirect (cost / price changes propagate) |
| Inventory | Indirect (initial stock posting) |
| AuditLog | Yes |
| Data | real (bulk path) |
| Risk | **P1** |
| Action | **Keep** + **Needs accounting review** for opening-stock pathway |

---

## 10. Reports

### `/reports` (root) — Reports landing **(dynamic [module] page)**

| Field | Value |
|---|---|
| Business purpose | None visible — falls through to `[module]/page.tsx` with `slug=reports` |
| Data | **demo** |
| Risk | **P2** |
| Action | **Remove or replace** with a real reports index linking to the specific reports below |

### `/reports/financial-summary` — One-page financials

| Field | Value |
|---|---|
| Business purpose | Composed PnL + balance sheet + cashflow view |
| What to test | Numbers match the individual reports for the same window; retained_earnings on BS == PnL net_profit since inception (proven by GH-188 test C) |
| Data | real |
| Risk | **P1** |
| Action | **Keep** |

### `/reports/kpis` — CFO KPIs

| Field | Value |
|---|---|
| Business purpose | DSO, DPO, DIO, CCC, CAC, LTV, contribution margin |
| What to test | Each metric formula matches `finance.service.getKpiReport`; date range respects sales-data exclusion of CANCELLED |
| Data | real |
| Risk | **P1** |
| Action | **Keep** + **Needs accounting review** for formula sanity |

### `/reports/accounting` — Ledger / trial balance

| Field | Value |
|---|---|
| Business purpose | Raw `JournalEntry` browser + trial balance |
| What to test | Date filter; click entry → see all lines; trial balance `is_balanced=true`; per-account drill-down |
| Money | Read-only |
| AuditLog | Read-only |
| Data | real |
| Risk | **P0** — the operator's "show me the books" page |
| Action | **Keep** |

### `/reports/accounting/opening-balance` — Opening balance posting

| Field | Value |
|---|---|
| Business purpose | One-time opening-balance journal entry (Phase 7H / 7I migration tool) |
| What to test | Form rejects unbalanced totals; idempotent (re-posting blocked); journal lands at the correct entry_date; appears on balance sheet `asOf >= entry_date` |
| Money | **HIGH** — posts a journal |
| Inventory | Indirect (`1200 Inventory` opening) |
| AuditLog | Yes |
| Data | real |
| Risk | **P0** — wrong opening balance corrupts every report forever |
| Action | **Keep** + **Needs accounting review** (this is the migration tool for go-live) |

### `/reports/pnl` — P&L

| Field | Value |
|---|---|
| Business purpose | Period P&L (revenue, refunds, COGS, stock loss, opex, net profit) |
| What to test | Date window; sums match `getLedgerPnlSummary`; opex bucket totals match per-category drill-down |
| Data | real (Phase 7B ledger-sourced) |
| Risk | **P0** |
| Action | **Keep** |

### `/reports/balance-sheet` — Balance sheet **(GH-188 fix landed here)**

| Field | Value |
|---|---|
| Business purpose | Assets / liabilities / equity at `asOf` |
| What to test | **Specifically for GH-188**: post an overpayment via `/receivables`, then reload BS — Customer Deposits should reflect the new `2200-{customer_code}` balance; legacy direct `2200` parent posting still appears; identity `assets = liabilities + equity` holds (`unreconciled_adjustment ≈ 0`); inventory negative or positive both surface honestly (no clamp) |
| Data | real (ledger-sourced + transitional settings additive on a few lines per `FINANCIAL_LOGIC_BLUEPRINT §2.2.14`) |
| Risk | **P0** |
| Action | **Keep** + verify GH-188 fix end-to-end in the browser |

### `/reports/cashflow` — Direct-method cashflow

| Field | Value |
|---|---|
| Business purpose | Operating / investing / financing cashflow by `source_type` |
| What to test | Customer receipts, supplier payments, expense pays, refunds align with PnL drill-down; warnings appear when `other_cash_*` is non-zero or net_operating diverges from raw ledger cash movement |
| Data | real (Phase 7C ledger-sourced) |
| Risk | **P0** |
| Action | **Keep** + **Needs accounting review** for the warning-notes UX |

### `/reports/budget` — Budget vs actual

| Field | Value |
|---|---|
| Business purpose | Compare planned vs actual opex / revenue per category |
| What to test | Budget lines can be added / edited / archived; variance % calculation; period-handling |
| Money | Read-only (compared to actuals) |
| Data | real for actuals, operator-entered for budget |
| Risk | **P2** |
| Action | **Keep** + **UX polish** |

### `/reports/cohorts` — LTV cohorts

| Field | Value |
|---|---|
| Business purpose | Customer-cohort retention + revenue |
| What to test | Cohort grouping by first_order_date; retention % per month-offset; LTV reflects sum of (order_total − discount) |
| Data | real |
| Risk | **P2** |
| Action | **Keep** |

### `/reports/marketing` — Marketing report

| Field | Value |
|---|---|
| Business purpose | Ad spend vs revenue, ROAS, CAC, LTV:CAC, payback months, phase budgets |
| What to test | Confirm ad_spend = opex.marketing_ads bucket; CAC = ad_spend / new_customers; phase budget vs actual |
| Data | real (computed from PnL + ops) |
| Risk | **P2** |
| Action | **Keep** + **UX polish** |

### `/reports/marketing-funnel` — Funnel entries

| Field | Value |
|---|---|
| Business purpose | Funnel-stage entries (operator-maintained) |
| What to test | Add / edit / archive funnel entries; period-by-period stage counts |
| Data | real |
| Risk | **P3** |
| Action | **Keep** |

### `/reports/partners` — Partners & capital

| Field | Value |
|---|---|
| Business purpose | Partner contributions & drawings |
| What to test | Per `FINANCIAL_LOGIC_BLUEPRINT §1D`, partner CoA work is pending — confirm what actually renders; likely shows placeholder or a settings-driven proxy |
| Money | Indirect (equity lines on BS may proxy this) |
| Data | **unknown** — likely **demo** until Phase 1D lands |
| Risk | **P2** |
| Action | **Investigate** → either **Keep with a "not yet wired" banner** or **Hide until Phase 1D**; **Needs accounting review** |

### `/expenses` — Expense entry

| Field | Value |
|---|---|
| Business purpose | Record an expense (cash out) |
| What to test | Choose category → `gl_account_code` resolves; legacy free-text fallback path; CASH/INSTAPAY/WALLET routing; reject archived category; journal posts in the same transaction |
| Money | **HIGH** — `Dr <gl> / Cr cash` |
| Inventory | None |
| AuditLog | Yes |
| Data | real |
| Risk | **P0** |
| Action | **Keep** + **Needs accounting review** |

### `/products/expense-categories` and `/[id]` — Expense categories

| Field | Value |
|---|---|
| Business purpose | Category → GL code mapping |
| What to test | Archive a category in use → existing expenses keep historical category but new ones are blocked; gl_account_code change for live category (should warn) |
| Money | Indirect (governs posting) |
| Data | real |
| Risk | **P1** |
| Action | **Keep** |

### `/currencies` — Currencies / FX

| Field | Value |
|---|---|
| Business purpose | FX rate management (likely placeholder per blueprint open question #9) |
| What to test | What actually renders; if a real form, does anything use the rates? |
| Money | None currently |
| Data | **unknown** — likely demo |
| Risk | **P2** |
| Action | **Investigate** → likely **Remove or hide** until FX is wired |

---

## 11. Shopify sync / admin

### `/shopify-sync` — Shopify sync dashboard

| Field | Value |
|---|---|
| Business purpose | Shopify integration status |
| What to test | Connect a store / show connected stores; sync status indicators; manual sync trigger |
| Money / Inventory | Indirect — imported orders post via `posting.service` (same path as manual) per the operating-model rule 3 |
| Data | real |
| Risk | **P1** (imported orders are P0 — see below) |
| Action | **Keep** |

### `/shopify-sync/inventory-preview` — Aggregate inventory preview

| Field | Value |
|---|---|
| Business purpose | Preview the inventory levels that would be pushed to Shopify |
| What to test | Aggregation matches `/products/inventory` for ATS-eligible locations only |
| Inventory | Read-only (preview) |
| Data | real |
| Risk | **P1** |
| Action | **Keep** |

### `/shopify-sync/locations` — Shopify location mapping

| Field | Value |
|---|---|
| Business purpose | Map Shopify locations ↔ internal locations |
| What to test | Bind a Shopify location; rebind; audit row written |
| Inventory | Indirect (drives the push) |
| Data | real |
| Risk | **P1** |
| Action | **Keep** + **Needs inventory review** |

### `/shopify-sync/stores` — Store list

| Field | Value |
|---|---|
| Business purpose | Multi-store management |
| What to test | Add store; archive store; per-store sync mode |
| Data | real |
| Risk | **P2** |
| Action | **Keep** |

### `/shopify-sync/[id]` — Per-store detail

| Field | Value |
|---|---|
| Business purpose | Store-specific sync controls |
| What to test | Push / pull triggers; notification settings |
| Data | real |
| Risk | **P1** |
| Action | **Keep** |

---

## 12. Users / roles / audit log

### `/users` — Team & Access (OWNER-only)

| Field | Value |
|---|---|
| Business purpose | Invite operators, assign roles |
| What to test | OWNER can land; non-OWNER bounces through `/login?error=forbidden`; role list matches `roles.ts`; revoke / reactivate |
| Money / Inventory | None |
| AuditLog | Yes |
| Data | real |
| Risk | **P2** (P1 if RBAC fails open) |
| Action | **Keep** + **UX polish** |

### `/audit-log` — Audit trail

| Field | Value |
|---|---|
| Business purpose | Read-only audit log |
| What to test | Filter by entity_type / actor / action / date; latest entries align with the actions you just performed; export if any |
| Money / Inventory | Read-only |
| Data | real |
| Risk | **P1** — audit completeness matters for compliance |
| Action | **Keep** |

### `/login` — Sign-in

| Field | Value |
|---|---|
| Business purpose | Auth |
| What to test | Wrong password rejects without leaking; `?next=` redirect lands on intended page; `?error=forbidden` displays a clear message |
| Money / Inventory | None |
| AuditLog | Yes (login attempt) |
| Data | real |
| Risk | **P2** |
| Action | **Keep** |

---

## 13. Settings

### `/settings` — Settings **(dynamic [module] page)**

| Field | Value |
|---|---|
| Business purpose | Operator config: opening-balance settings (`accrued_expenses`, `customer_deposits`, `owner_capital`, `drawings`, cashflow investing/financing inputs, marketing targets) |
| What to test | What actually renders — this URL also falls through to `[module]/page.tsx` with `slug=settings` from `module-definitions.ts`. Inspect whether real key/value editing exists. Each transitional setting that survives is a balance-sheet input (per `finance.service.ts` JSDoc § Phase 7D) |
| Money | **HIGH** if the form writes to `Setting` rows — those values become additive to balance sheet liabilities + equity until their accounts get posting helpers |
| Inventory | None |
| AuditLog | Yes (settings changes) |
| Data | **demo metrics; settings table is real** — needs eyes-on |
| Risk | **P0** — wrong setting values silently inflate liabilities or equity |
| Action | **Investigate first** → likely **Fix** (build a real settings UI) or **Remove the demo template** and replace with per-area settings pages; **Needs accounting review** |

---

## 14. Dead nav links and demo-only pages

Pages where I found **no specific `src/app/<route>/page.tsx`** but the nav links exist, falling through to the generic `[module]/page.tsx` with hardcoded metrics from `module-definitions.ts`:

| Route | Status | Action |
|---|---|---|
| `/stock-count` | demo template + `getLiveModuleData('stock-count')` | **Investigate** — covered above |
| `/settings` | demo template + `getLiveModuleData('settings')` | **Investigate** — covered above |
| `/reports` | demo template — but every sub-report has a real page | **Remove or replace** with a real index |

Plus these `module-definitions.ts` slugs that don't appear in the current `NAV` and thus aren't reachable via the sidebar (but ARE reachable by typing the URL):

| Route | Reachable | Action |
|---|---|---|
| `/[module]?module=suppliers` | URL only | Probably superseded by `/products/suppliers` — **Remove from module-definitions.ts** |
| `/[module]?module=purchase-orders` | URL only | Superseded by `/products/purchase-orders` — **Remove** |
| `/[module]?module=import-pipeline` | URL only | Superseded by `/products/import` — **Remove** |
| `/[module]?module=inventory` | URL only | Superseded by `/products/inventory` — **Remove** |
| `/[module]?module=transfers` | URL only | Superseded by `/products/transfers` — **Remove** |
| `/[module]?module=orders` / `customers` / `receivables` / `returns-damage` / `expenses` / `audit-log` | URL only | All have specific pages now — **Remove the unused slugs** |

> The `[module]` catch-all is a legacy scaffolding shape. As specific pages have been built, the demo slugs have been left behind. Consider a single tracking ticket to retire the `module-definitions.ts` template entirely once `/stock-count` and `/settings` get real pages.

---

# B. Suggested manual-testing order

Follow this order so each test's output feeds the next:

1. **`/`** — confirm baseline KPIs render
2. **`/reports/accounting`** — read the empty/seeded ledger first; this is your reference point
3. **`/products/locations`** — confirm at least one ATS-eligible location + one DAMAGED location exist
4. **`/catalog`** + **`/catalog/new`** — create one test product if none exist; set `current_avg_cost` via opening balance
5. **`/reports/accounting/opening-balance`** — post an opening cash + inventory journal so subsequent flows have a starting state
6. **`/products/purchase-orders/new`** → **receive** — exercises WAC math + AP
7. **`/orders/new`** as **POS** — exercises revenue + COGS + cash receipt in one shot (the simplest end-to-end)
8. **`/orders/new`** as **standard order** (UNPAID) — exercises AR creation without payment
9. **`/receivables`** — record a normal payment (within AR)
10. **`/receivables`** — record an **overpayment** (GH-186 / GH-188 verification — the headline test)
11. **`/receivables`** — record a **standalone prepayment** (deposit, no order)
12. **`/customers/[id]`** — verify the customer's open AR + deposit balance render distinctly
13. **`/returns-damage`** — sellable return on the POS order
14. **`/returns-damage`** — damaged return on the standard order
15. **`/orders/[id]`** — cancel a partly-fulfilled order to test the reversal path
16. **`/expenses`** — record an expense with `category_id` (journal-posting path)
17. **`/products/transfers`** — move stock between locations
18. **`/stock-count`** — try a count adjustment if the page is real; otherwise note as demo
19. **`/reports/pnl`**, **`/reports/balance-sheet`**, **`/reports/cashflow`** — verify all three reconcile after the flows above
20. **`/reports/financial-summary`** + **`/reports/kpis`** — verify composed views match the underlying reports
21. **`/audit-log`** — every action above should have left a trail
22. **`/shopify-sync`** + sub-pages — only if a sandbox store is connected; otherwise visit and note "no store connected" UX
23. **`/users`** as OWNER, then sign in as a non-OWNER role and verify RBAC bouncing
24. **`/settings`** — last, because it's the highest-risk surface to discover broken

After this 24-step walk, the remaining marketing / cohorts / budget / partners pages are read-only and can be visited in any order to assess UX.

---

# C. Screenshots / logs to capture per finding

For every bug or odd behaviour, capture **all five** of these so a follow-up ticket isn't blocked by re-reproduction:

1. **Screenshot of the page** showing the bad state (full viewport, browser URL bar visible).
2. **Browser DevTools → Network tab** — filter to the failing request, screenshot Status + Response payload (redact any auth tokens).
3. **Browser DevTools → Console** — capture any client-side errors / warnings, especially React hydration or hook-order warnings.
4. **Server-side logs** — open the terminal running `npm run dev`, copy the last ~20 lines around the failing request (Prisma error stacks are gold). Redact any database URL substring.
5. **Reproduction recipe** — the literal sequence: "From `/`, click X, fill Y=foo, click Z, observe W". One bug per recipe.

For accounting-relevant bugs, additionally capture:

6. **Trial balance snapshot** from `/reports/accounting` immediately BEFORE and AFTER the failing action — proves whether the books balanced or not.
7. **The journal entry the action created** (if any) — `JournalEntry.entry_code` + the lines.
8. **The AuditLog row(s)** — `entity_type`, `entity_id`, `action`, `new_value`/`old_value`.

For inventory bugs:

9. **Pre/post `stock_movement` rows** for the affected product + location.
10. **The product's `current_avg_cost`** before and after, if it changed.

---

# D. Rules for converting findings into GitHub issues

**Do not file as you walk.** Take notes during the walkthrough, then triage in one batch at the end. This avoids 30 single-issue PRs and lets you collapse duplicates.

### Triage rubric per finding

| Pattern | Issue type | Skill to invoke | Label set |
|---|---|---|---|
| Page crashes / 500 / hydration error | `[Bug]` | `/bug` | `bug, <area>, P0/P1` |
| Wrong number on a report or KPI | `[Bug]` | `/bug` | `bug, accounting`/`inventory`, `reports`-equivalent label, `P0/P1`, `go-live-readiness` |
| Action posts wrong journal or no journal | `[Bug]` | `/bug` | `bug, accounting, finance, P0, go-live-readiness` |
| Action moves stock incorrectly | `[Bug]` | `/bug` | `bug, inventory, P0/P1` |
| Demo data still on a "real" page | `[Task]` "Replace demo data with live read" | `/task` | `chore, ui` (or relevant area) |
| Dead nav link / nav points to a `[module]` catch-all | `[Task]` "Remove dead nav entry X" | `/task` | `chore, ui` |
| UX confusion (labels, ordering, missing affordance) | `[Feature]` "UX: …" | `/feature` | `feature, ui` |
| Missing AC for a future flow you spotted | `[Feature]` | `/feature` | `feature, <area>` |
| Hypothesis-driven "I think X is wrong but need to verify" | `[Spike]` (time-box ≤ 1d) | `/spike` | `spike, <area>` |
| Multi-step root-cause investigation (e.g. "where is customer-credit displayed?") | `[Investigation]` | `/investigation` | `investigation` |
| **Don't file** | Documentation typos, comment fixes, single-character renames | n/a | fix in-line in the next nearby PR |

### Each issue MUST include

1. **Given / When / Then** (project's bug-schema validator enforces this on `[Bug]`).
2. **Repro** with literal click-by-click steps.
3. **Acceptance criteria** as numbered checkboxes (`/feature` and `/task` templates already enforce this).
4. **The 5–10 captured artifacts** from section C, attached or pasted.
5. **Out-of-scope** section listing what this specific ticket will NOT touch — keep tickets small.
6. **Glossary** if it touches accounting terminology.

### Severity escalation rules

- **P0**: trial balance doesn't balance after a normal operator flow; the books are wrong; a money flow doesn't post a journal at all; an inventory action over- or under-counts stock; a payment is silently lost; an RBAC bypass.
- **P1**: a reported number is wrong but no money actually moved (display issue on a real page); a flow posts the right journal but the audit row is missing or wrong; an obvious UX dead-end.
- **P2**: the right number, wrong label / placement / format; a feature that visibly exists but does nothing harmful.
- **P3**: cosmetic, print-layout polish, dead nav links to demo pages with no money impact.

### Don't file (in this batch) — defer with a note

- Anything that touches `schema.prisma` / migrations / `package*.json` / `.env*` / workflows — those go through their dedicated skills (`/migration`, dependency-audit, etc.).
- Anything you'd need to relitigate against `DECISIONS_LOG.md` — leave a note, raise it as a separate `[Spike]` if the decision needs revisiting.
- Customer-credit display work — there's already a CFO-flagged area; consolidate into ONE follow-up ticket rather than three near-duplicates.

### After triage

Once you have your batch (typically 5–20 tickets), use **`/tickets-batch`** rather than `/bug` × 20 sequentially — the batch skill asks shared-context questions once.

---

# E. Stop notice

This is read-only output only. No files were edited in the app repo, no branches created, no commits, no pushes, no PRs, no GitHub issues filed, no schema / migrations / package / `.env` / workflow files touched, no destructive commands run.

- App repo: on `main` at `a53f42c`, working tree clean (only gitignored `.claude/session/` showing as untracked).
- Ops repo: still on `docs/GH-12-persist-cfo-audit-artifact`, unchanged from session start aside from this walkthrough plan being saved as a new file under `projects/ecommerce-accountant-software/walkthroughs/`.
- No new ticket started.
- Not proceeding past the checklist.

Walk the pages in section B's order, capture per section C, triage per section D — ping back when you have the findings batch.
