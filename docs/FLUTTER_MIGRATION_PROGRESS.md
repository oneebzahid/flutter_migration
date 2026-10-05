# Flutter Migration Progress

Scope: **frontend only**. Logic and backend are built separately; all data is mocked behind repository interfaces.
State management: **Redux** (`redux` + `flutter_redux`), routing: `go_router`.

## Modules discovered (live routes in the React app)

| # | Module | Status |
|---|---|---|
| 0 | Foundation (design system, adaptive shell, shared widgets) | Approved (dark sidebar restyle applied) |
| 1 | Auth (login, forgot password) | Approved |
| 2 | User management (+ system currency) | Approved |
| 3 | Dashboard | Pending (placeholder only, no figures) |
| 4a | Inventory — dashboard (per-serial) + product list | Approved (⋮ row menu, Download added) |
| 4b | Inventory — Damaged, Deleted, Report, Add Stock (existing), Add Returned, Add Inventory (unified form) | Implemented, awaiting review |
| 4c | Inventory — legacy costing wizard (costing options → costing details → details / multi-models → payment) | Not built: unreachable from React's UI; calculator done + tested |
| 4d | Product transfer (list + create) | Pending (placeholder) |
| 5 | Purchased orders | Pending |
| 6 | Transactions | Pending |
| 7 | Invoices (+ fictitious) | Pending |
| 8 | Product transfer | Pending |
| 9 | Employees | Pending |
| 10 | Reports | Pending |
| 11 | Payable to Futuristic | Pending |

Not ported (dead code in React): payroll, loans, bills, commissions, budgets, assets (BR-15).

## Foundation + Auth — what exists

- Tokens: `core/theme` (colors, spacing, typography, breakpoints, theme).
- Shared widgets: `AppButton`, `AppTextField`, `StatusBadge`, `AppLoading`/`AppEmptyState`/`AppErrorState`, `AppDialog` + `showConfirmDialog`.
- Shell: sidebar (>=1024), icon rail (600-1024), drawer (<600); permission-filtered nav mirroring React `Sidebar.tsx`.
- Redux: `AppState` -> `AuthState`; side effects in middleware; `AuthRepository` interface with `MockAuthRepository`.
- Login: email/password validation, error banner, show/hide password, forgot-password dialog, pending/rejected/no-profile messages as in React.

## UI standards (apply to every module)

- **Tables:** always `AppDataTable`. Fixed-height card, sticky header/footer, **always-visible horizontal scrollbar pinned to the bottom of the table**, right-edge "more columns" arrow, Actions column pinned right, light styling (owner request, 2026-10-03).

- **Downloads:** every list/sheet screen has a Download menu (Excel + PDF) via `ExportMenu`/`ExportTable`; exports all filtered rows.

## User-approved changes

- Redux instead of Riverpod (owner decision).
- Project location: `Desktop/MIGRATION_FLUTTER`.

## Deviations from React (need your OK)

1. Dashboard added as an explicit nav item (React only reaches it via the logo).
2. Route-level permission check: a user without permission is redirected to the dashboard (React only hides menu items).
3. `/register` not built: registration policy is open decision D4 (plan recommends invite-only).
4. Login "Demo mode" hint card shows only in debug builds.

## Known limitations

- Mock auth only (demo accounts listed on the login screen in debug).
- No persistence: refreshing the app signs you out.
- Dashboard and all other modules are placeholders.
- Windows desktop build needs Developer Mode enabled (symlink support).
- Logo image not used yet (text brand mark); React uses `/BullionLogo.jpeg`.

## Testing results

- `dart format`: clean.
- `flutter analyze`: no issues.
- `flutter test`: 111/111 pass (auth, permissions, user management, inventory incl. damaged/deleted/add stock/returns/add inventory/costing calculator, Excel/PDF export).
- `flutter build web`: compiles.

## Next proposed module

Inventory legacy costing wizard (if wanted) or Product transfer; then Purchased orders, Transactions, Invoices.

## Inventory sections — notes and deviations from React (need your OK)

- **Add Inventory (`/inventory/create-new`)** is React's unified form (the type-selection / costing wizard is not linked from it). Owned stock is entered from a shipment (landed cost, retail at a margin, default 25%); Credit stock by hand, saved as supplier payable (unpaid). Product images are not built (needs a file picker).
- Success toasts have no emoji (they do not render on Windows).
- Helper text under the shipment picker is corrected: React says cost cannot be edited, but the code allows it.
- **Add Returned:** editing the serial clears a previous search result (React could submit a result under changed text); a sold serial marked damaged no longer decrements stock (React under-counts).
- **Add Stock:** serials are trimmed; per-unit location can be chosen before typing the serial (React needed the serial first).
- **Report:** has Excel **and** PDF (React: Excel only) and per-serial delete wording (React's text said "product").
- **Deleted Inventory:** read-only like React (restore exists only as a service function there). Added Download.
- Currency: symbol-only, no conversion (D5).

## User Management — notes

- Not built: **Factory Reset** (BR-17 undecided: remove, or owner-only server operation).
- Added vs React: confirm dialog before Reject; search on Active users.
- React quirk kept visible: branch stored lower-case on create but 'Saudia' default on approve; Flutter normalises to lower-case.
- Rejected users are stored but not listed anywhere (same as React).
- Currency list has no flag emoji (they do not render on Windows).
