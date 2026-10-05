# Business Logic Review — Inventory (Stage A, database-independent)

Source of truth: the React app. Nothing below has been changed in Dart; each item is
**BUSINESS LOGIC REVIEW REQUIRED — decision needed** and the affected Dart logic stays
as-is (React-parity where ported) until the owner answers.

Status key: Dart = what the Flutter port does today.

| # | Area | React behaviour | Why suspicious | Recommended | Dart today |
|---|------|-----------------|----------------|-------------|------------|
| 1 | Stock count vs serials | Sold serials stay in `serialNumbers` (status Sold). Three different formulas write `stock` (sale: −qty; add batch: `serialNumbers.length`; invoice delete: `nextSerials.length`). Return of a sold serial does not +1; damaging a sold serial −1 again. | One field, three formulas → drifts every sell/return/damage cycle | Derive on-hand = count(serials with status Available), never store | Mock keeps sold rows separately and is self-consistent, but does not mirror React data |
| 2 | Atomicity | Sale, stock-in, transfer create/receive, delete/restore product, return are multi-step read-then-write with no transaction; failures only logged | Invoice without sold serials, double-sell, duplicate/lost product, receive overwrites stale maps | Each business operation is one atomic repository call (transaction + precondition) | In-memory, so not represented; repository interface must expose atomic ops |
| 3 | Weighted-average cost | `(oldQty*oldCost + newQty*landed)/(oldQty+newQty)` with oldQty = all serials incl. sold; top-up spreads over all serials | Valuation/COGS wrong. 4 serials@100 (1 sold) + 2@130 → 110.00 (should be 112.00 over unsold) | Average over Available only, or value = Σ serialCostPrice | Not preserved: Dart `addStock` overwrites cost & sell price |
| 4 | Legacy PKR heuristic | On read, price > 50 000 ⇒ ÷279.5 ×3.67 | Genuine AED > 50 000 shown ≈1/76; corrupted value can be saved back | Explicit `currency` field + one-off migration | Not ported (correct) |
| 5 | Supplier payment | No amount checks, overpay stored, double-click pays twice, undefined cost ⇒ Cleared, not atomic | Financially unsafe | Immutable payment ledger, 0 < amt ≤ remaining, atomic with bank posting | Not ported |
| 6 | Sell-price floor | floor = round2(landed); sell only ever raised on add-stock | Dart compares un-rounded cost (100.004 vs 100.00 rejected in Dart, allowed in React); Dart add-stock can lower price | Share one round2 floor; keep "only raise" | Differs (stricter) |
| 7 | Duplicate serials | Case-sensitive, add-existing checks only same product, ignores deleted/damaged/sold archives, no trim in React | Same serial can exist twice | Global unique, trimmed+upper-cased serial registry | Trims (deliberate improvement); live only; not case-normalised |
| 8 | Product transfer | Always created "In Transit" (Pending tile always 0); no cancel/partial; Receive doesn't verify serials still In Transit/not sold; deleting a Received transfer doesn't revert locations; receive resets stock-in date (distorts ageing); `shipmentCost` copied onto each of N docs (sum ×N); freight split equally per unit | Status machine incomplete; cost double-counts; ageing reset | Server-side machine In Transit→Received/Cancelled; allocate freight by value; keep original stock-in date | **Not built — paused for decision** |
| 9 | Rounding | Totals use unrounded per-unit; displayed unit×qty ≠ total (33.33×3 vs 100.00); customs shares not remainder-corrected; negative ties differ JS vs Dart | Visible mismatches | Keep for parity; add largest-remainder allocation only if approved | Parity preserved incl. weaknesses |
| 10 | Late-charge absorption | Remaining-unit cost = max(0, landed − stocked)/remaining → can be 0 | Free unit, zero sell floor | Post as revaluation/variance | Not ported |
| 11 | Charge currency | List charges assumed AED; legacy 4-field charges × rate; overpay clamped invisible | Mixed-currency mis-costing | Currency+rate per charge | Not ported |
| 12 | Delete/return | Delete sold serial leaves invoice dangling, orphan cost maps; damaged keeps no cost (no loss posting); return flips ownership of whole credit lot; invoice deleted (no credit note) | Financial docs deleted instead of reversed | Credit note; per-serial ownership | Mock mirrors ownership flip + invoice delete |

## Parity vectors ready for tests (React-verified formulas)
- Landed cost: A 10×$100, B 5×$200, rate 280, customs 1000, freight 500 → landed A 28 075, B 56 150, each total 280 750; consignment 560 000; brand value 561 500.
- Rounding: 3 units, $10, rate 1, customs 100 → customs/unit 33.33, landed 43.33, total 130.00.
- Shipment costing: 10×$50 + 10×$150, rate 3.67, freight 1000, customs 500 → landed 221.00 / 663.00, total 8 840.
- Sell price: (100, 25%) → 125.00; (80, 25%) → 100.00. Markup on cost, not margin.
- Weighted average (flawed, for characterisation only): 4@100 + 2@130 → 110.00.
- Supplier payment: cost 1000, pay 400 → Partial, 600 left; +600 → Cleared.
- Transfer cost: shipmentCost 90 over 3 serials → 30/unit.

## Decisions needed (owner)
1. Stock model: derive on-hand from Available serials (recommended) or keep React's stored `stock`?
2. Weighted average: keep React (counts sold) or Available-only?
3. Add-stock: keep Dart overwrite of cost/sell, or React-style average + "only raise" sell price?
4. Transfer: approve status machine (add Cancel), freight allocation, keep/reset stock-in date on receive, behaviour when deleting a Received transfer.
5. Supplier payment guards and ledger (needed before the Payables module).
6. Serial uniqueness: global, trimmed, case-insensitive?
7. Returns: credit note instead of deleting the invoice; per-serial ownership?
8. Rounding: add remainder-correct allocation, or strict parity?

## Architecture note
The directive's diagrams name Riverpod; the owner chose **Redux** earlier. Redux is kept
(UI → Redux middleware → repository interface); domain classes (`costing_calculator`,
`add_*_rules`) are pure Dart with no Firebase/Supabase/UI imports.

---

## Owner decisions received and applied (Stage A)

| # | Decision | Status |
|---|----------|--------|
| 1 | Stock derived from Available serials | DONE - `Product.stock` is a getter (`StockValuation.onHand`); stored count removed |
| 2 | Average cost over Available only | DONE - `StockValuation.weightedAverageCost`, used by `addStock` (112.00 vector tested) |
| 3 | Add stock averages cost, only raises sell price | DONE - `raiseOnlySellPrice` |
| 4 | Transfer: Pending -> In Transit -> Received, Cancel, freight by value, keep stock-in date, revert on delete of Received, receive checks In Transit | DONE - domain + mock repo + Redux + screens + PDF note; 12 tests |
| 5 | Supplier payment guards | RULES DONE + TESTED (`SupplierPaymentRules`); repository method + UI belong to the Payables module (not built). Request-id double-submit guard is already used by transfers |
| 6 | Serial uniqueness, trimmed + case-insensitive | DONE for live + sold units in create/add-stock. NOT DONE: duplicate scan of real Firestore data (Stage B migration step) |
| 7 | Returns via credit note + per-serial ownership | NOT DONE - needs the Invoices module; current return still mirrors React (ownership flip, invoice moved to Deleted Invoices) |
| 8 | Remainder-correct allocation | DONE - customs/freight in `CostingCalculator`, transfer freight. Documented differences: costing example 2 line totals 665.98 / 475.69 (React 665.97 / 475.70) |
| - | No PKR heuristic | Respected (not ported) |
| - | Late charge never silently 0 | DONE - `RemainingLayerCost` returns an error (UI wiring with Purchased Orders) |
| - | Architecture | Redux kept (pd_portal is not on this machine, so its state-management choice could not be verified - please confirm). Domain is pure Dart; transfer ops are single atomic repository calls |

Open: intermittent timing flake (1 of ~146 tests, timer-based `_settle`) seen twice under CPU load; passes on rerun.
