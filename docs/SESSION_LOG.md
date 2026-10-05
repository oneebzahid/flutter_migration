# Session log - Bullion ERP: React -> Flutter migration

> Purpose: let another developer, IDE or AI take over with zero context loss.
> Append a new dated entry at the TOP of "Log" after every working session
> (what was done, decisions, what is next). Keep "Current state" accurate.
> Last updated: 2026-10-05.

---------------------------------------------------------------------------
## 1. Project in one paragraph

Migrate the React/Firebase **Bullion ERP** (`C:\Users\NOOR UL IEMAN\OneDrive\Desktop\accounts_bullion_oor\Bullion-System-main`,
the *functional reference only*) to a **Flutter** app, and merge it into the team's
`pd_portal` repo (https://github.com/oneebzahid/pd_portal) on branch `acc_mig`.
Phase now: **UI/UX + mock database** (no Supabase yet). Business logic is migrated as
pure Dart and validated with tests; the owner approves every questionable rule.

Two Flutter projects exist:
| Project | Path | Role |
|---|---|---|
| `bullion_erp` (this repo) | `C:\Users\NOOR UL IEMAN\OneDrive\Desktop\MIGRATION_FLUTTER` | working copy, not a git repo |
| `pd_portal` | `C:\Users\NOOR UL IEMAN\OneDrive\Desktop\pd_portal` | team repo (git), target of the merge |

Owner: khaleejdetectors@gmail.com (GitHub user Iemannoorul614). Lead = pd_portal owner (oneebzahid).

---------------------------------------------------------------------------
## 2. Current state (read this first)

### bullion_erp (MIGRATION_FLUTTER)
- Stack: **GetX only** (state, DI via Bindings, routing). **No Redux / go_router** anywhere.
- Quality gates (last run): `flutter analyze` clean, `flutter test` **170 passing**, `flutter build web` OK.
- Modules done: **Auth/login, User Management, Settings (currency), Dashboard (basic),
  Inventory (dashboard, report, product list, add inventory, add stock, add returned,
  damaged, deleted, product transfer, inventory payables)**.
- Not built (placeholders): Transactions, Purchased Orders, Invoices (+dummy), Employees/HR,
  Banking/Cash (**deleted on the owner's side - never build**), legacy costing wizard
  (unreachable from the React UI - owner said skip).
- Data: in-memory mock data sources (invented data), zero Supabase code.

### pd_portal
- Cloned to `...\Desktop\pd_portal`. Branch `acc_mig` published (identical to `main`).
- Branch `acc_mig/ui-ux/inventory`: the Inventory port (see section 9 for status).
- pd_portal rules (its `CLAUDE.md`): GetX only; clean architecture
  `lib/features/<feature>/{data,domain,presentation}`; `Either<Failure,T>` (dartz);
  datasources throw typed exceptions, ONLY repository impls catch; no hardcoded colors
  in features (use `Theme.of(context).colorScheme` + `AppColors` semantic colors + `AppSizes`);
  route names are constants (`AppRoutes`); no `print`; no cross-feature import of another
  feature's data/presentation; mocktail unit tests mirror `lib/` under `test/`.

---------------------------------------------------------------------------
## 3. How to run (Windows, PowerShell)

```powershell
$env:Path = "C:\flutter\bin;" + $env:Path      # Flutter 3.47.6 / Dart 3.13.5 lives in C:\flutter
cd "C:\Users\NOOR UL IEMAN\OneDrive\Desktop\MIGRATION_FLUTTER"
flutter pub get
flutter analyze
flutter test                      # ~170 tests, ~1.5 min
flutter run -d chrome             # or: flutter build web
```
Demo logins (mock): `admin@demo.com / admin123` (super admin), `user@demo.com / user123`
(limited), plus `pending@demo.com`, `rejected@demo.com`, `noprofile@demo.com` for the error states.

Visual audit tool (renders screens to PNG with real fonts, not part of `flutter test`):
`flutter test test_shots/shots_test.dart --dart-define=SHOT_DIR=<folder>`.

Windows desktop builds need Developer Mode (symlinks). Web is the easiest target.

---------------------------------------------------------------------------
## 4. Architecture of bullion_erp

```
lib/
  core/   error/ (Failure, exceptions, guardCall) · usecase/ · state/ (Loadable, Notice+NoticeMixin)
          routes/ (app_routes, app_pages, auth_guard) · di/initial_bindings · settings/ (CurrencyProvider)
          storage/app_prefs · theme/ (tokens) · utils/ (currency, date, table_export, file_downloader)
          widgets/ (shared UI kit: AppDataTable, TableToolbar, ExportMenu, FormCard/FormSection, ...)
  app/    app.dart (GetMaterialApp) · shell/ (AppShell, ShellController, SideNavigation, TopBar, nav_items)
  features/
    auth/                       session (AuthController implements SessionProvider)
    accounts/{inventory,settings,dashboard,...}
    admin/user_management/
    hr/employees/               (empty scaffold)
      <feature>/{data,domain,presentation}
```
Layers per feature: `domain/{entities,rules,repositories,usecases}` (pure Dart) ·
`data/{datasources,repositories}` · `presentation/{bindings,controllers,pages,widgets}`.
`rules/` holds pure calculators/validators (costing, stock valuation, transfer, payables).

Key patterns
- One use case per action; repositories return `Either<Failure,T>` via `guardCall`.
- Controllers: `Rx` fields, call use cases; `NoticeMixin.notify()` publishes feedback; pages wrap
  content in `NoticeListener` (shows the snackbar) and read state with `Obx`.
- `InitialBindings({authDataSource,userDataSource,settingsDataSource,inventoryDataSource})` registers
  mock data sources app-wide (a mock must outlive a route). Tests inject zero-latency mocks.
- Cross-feature access only via domain/core: `SessionProvider` (current user), `CurrencyProvider`.
- `AuthGuard` (GetMiddleware) = login redirect + per-screen permission (`requiredScreenFor`).
- Every signed-in page is wrapped by `AppShell` (sidebar state in `ShellController`).
- Route constants: `core/routes/app_routes.dart`. Permission screen names: `Screens` in
  `features/auth/domain/entities/auth_user.dart` + catalog in `screen_catalog.dart`.

Details: `docs/GETX_ARCHITECTURE.md`, `docs/ARCHITECTURE.md`, `docs/MIGRATION_MAP.md`.

---------------------------------------------------------------------------
## 5. Owner standing rules (obey; they came from the owner)

UI
1. Every table uses `AppDataTable`: always-visible horizontal scrollbar pinned to the bottom, light/
   uncrowded look, Actions column pinned right, row actions as a labelled `⋮` `RowActionMenu`
   (destructive item last, red), sort, skeleton loading, rows-per-page persisted.
2. Every table sheet has Download (Excel .xlsx + PDF) exporting ALL filtered rows; PDF has company
   name **BULLION**, the React logo (`assets/images/bullion_logo.jpeg`), generated date+time, filters.
3. Filters are tucked away (button / bottom sheet on mobile) with removable chips; mobile uses cards.
4. All forms use the shared `FormCard` / `FormSection` (raised, shadowed panels). Option cards equal size.
5. Currency is **symbol-only** (no conversion); mock data is invented.
Process
6. Module -> test -> owner feedback -> approval -> next module. Show a manual test checklist.
7. Do NOT change business behaviour without owner approval; the React app is the behavioural source
   of truth until approved. Questionable logic -> write a "BUSINESS LOGIC REVIEW REQUIRED" item and stop.
8. Anything major/destructive/prod/financial needs an owner approval ("change request").
9. Never hardcode secrets; no Supabase service-role key in Flutter; never delete Firebase data.
10. Deleting user files needs explicit permission.

---------------------------------------------------------------------------
## 6. Approved business decisions (details: `docs/BUSINESS_LOGIC_REVIEW.md`)

- Stock on hand = count of **Available** serials (derived, never stored) - `Product.stock` is a getter.
- Average cost over Available units only; add-stock averages cost and **only raises** the sell price.
- Costing/customs/freight allocation is **remainder-correct** (parts add to the exact total). Known
  1-cent differences vs React are documented in `test/costing_calculator_test.dart`.
- Product Transfer: Pending -> In Transit -> Received, Cancel from Pending/In Transit, freight split by
  value, original stock-in date kept, receive requires every serial still In Transit, deleting a Received
  transfer reverts locations, one request id per submit (no double submit).
- Supplier payment: reject overpayment, require a positive cost, never "Cleared" without cost, one request id
  per dialog, every payment kept as a record (reference `SUP-PAY-<productId>-<timestamp>`).
- Serial uniqueness: global, trimmed, case-insensitive (live + sold units). Duplicate scan of REAL data is a
  Supabase-migration step.
- NOT ported: the "price > 50 000 means PKR" heuristic. Late-charge rule must error, never silently 0.
- Returns via credit note + per-serial ownership: **later, with the Invoices module** (today returns mirror React).
- Inventory Payables: new permission **"Inventory Payables"**, route `/inventory/payables`. No Cash/Bank modules
  (deleted by the owner): the payment record keeps only channel (Cash/Bank) + bank name; the bank dropdown is a
  small hardcoded list. In the future Supabase repository the payment and its ledger entry (kept inside the
  payment record) must be written **atomically** (single transaction).

---------------------------------------------------------------------------
## 7. Testing notes / gotchas

- Tests use `test/support/harness.dart`: `Harness.install()` + feature bindings for controller tests;
  `BullionApp(initialBinding: Harness.fresh().bindings)` for widget tests; `until(cond)` waits on controller
  state (event-loop turns) - never sleep on the wall clock.
- In `testWidgets` never `await Future.delayed` or call mock-datasource futures directly (fake clock hangs);
  use `tester.pump(Duration)` / `tester.runAsync(...)`.
- Ahem font in tests makes text wide -> use Flexible/Wrap to avoid overflow in test only.
- Windows PowerShell 5.1: inline `python -c "..."` and here-strings mangle quotes; write scripts to a file
  (Temp dir) and run them. .NET `File.ReadAllText` with relative paths resolves against the process cwd, not
  the PS location; use absolute paths and UTF-8 without BOM (`Set-Content` without `-Encoding` corrupts
  non-ASCII such as the em dash).
- Shell `cd` inside tool calls is reset; use absolute paths.
- Empty 0-byte scaffold files exist under several features (stubs from the first scaffold); ignore them.

---------------------------------------------------------------------------
## 8. Documents in `docs/`

| File | What |
|---|---|
| `SESSION_LOG.md` | this handoff + running log |
| `GETX_ARCHITECTURE.md` | GetX/clean-architecture conversion and deviations |
| `BUSINESS_LOGIC_REVIEW.md` | 12 audited logic issues, owner decisions, parity vectors |
| `FLUTTER_MIGRATION_PROGRESS.md` | older module table / UI standards (partly outdated: Redux era) |
| `ARCHITECTURE.md`, `MIGRATION_MAP.md`, `REACT_ANALYSIS.md` | earlier analysis |
| `acc_mig/` | pd_portal port notes (created by the port task) |

Memory files (Claude-specific, optional) live in `C:\Users\NOOR UL IEMAN\.claude\projects\...\memory\`.

---------------------------------------------------------------------------
## 9. pd_portal port status

Branch: `acc_mig/ui-ux/inventory` (from `acc_mig`). See `docs/acc_mig/` for the port notes and the PR text.
Rules for the port: flat `lib/features/inventory/`, `package:pd_portal/...` imports, mock datasources only,
no Supabase implementation yet (Stage B), no Cash/Bank modules, pubspec additions listed in the PR.
Status 2026-10-05: port done and committed locally on `wip-acc-mig-ui-ux-inventory` (4 commits; analyze clean,
159 tests, web build OK). PUSH BLOCKED: `acc_mig/ui-ux/inventory` cannot be created because the branch `acc_mig`
exists (git ref directory/file conflict). Needs an owner decision on another branch name. PR text: `docs/acc_mig/PR_inventory.md`.
(Update this section when the PR is opened/merged.)

---------------------------------------------------------------------------
## 10. Open items / next steps

1. Finish + push + open PR for `acc_mig/ui-ux/inventory` (lead merges into `acc_mig`).
2. Next feature branches: `acc_mig/ui-ux/invoices` (unlocks credit-note returns), purchased orders, transactions.
3. Open questions for the lead: feature grouping (`accounts/admin/hr` vs flat), new packages
   (excel, pdf, file_saver, shared_preferences, intl), where the shared UI kit lives (`core/widgets`).
4. Before Supabase (Stage B): approval checkpoint report (Approved/Suspicious/Changed/Preserved/DB deps/Open
   decisions) - see `BUSINESS_LOGIC_REVIEW.md`.
5. Pending UI items: unsaved-changes guard on add forms, breadcrumbs, date-range filter, fresh screenshot audit.

---------------------------------------------------------------------------
## Log (newest first)

### 2026-10-05
- Converted the whole app from Redux/go_router to GetX + clean architecture (matches pd_portal).
- Built Inventory Payables (rules, repo, use cases, controller, page, dialogs, tests); owner approved with
  the "Inventory Payables" permission and "no Cash/Bank modules" decision.
- Business-logic review: 12 findings audited; owner decisions applied (derived stock, available-only
  average cost, remainder-correct allocation, transfer state machine, payment guards, serial uniqueness).
- Product Transfer built (list, create, dispatch, receive, cancel, delete, PDF note).
- Replaced timer-based test waits with state-based waits (no flaky tests).
- Cloned pd_portal, published `acc_mig`; started `acc_mig/ui-ux/inventory`.
- Earlier (previous contexts): React analysis, shared UI kit (tables, export, forms), inventory screens,
  login/shell/user management, design tokens, screenshot audit tooling.
