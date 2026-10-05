# PR: Inventory module (UI/UX on mock data)

Base: `acc_mig` - Compare: `acc_mig...<inventory branch>`

NOTE: the branch name `acc_mig/ui-ux/inventory` cannot exist while the branch
`acc_mig` exists (git stores refs as paths: `refs/heads/acc_mig` is a file, so it
cannot also be a directory). The work is committed locally on
`wip-acc-mig-ui-ux-inventory` and is NOT pushed yet - the owner must pick another
name (for example `acc_mig-ui-ux-inventory`, or rename the base branch).

## Summary

Ports the finished Inventory feature from the Bullion ERP Flutter prototype into
`pd_portal`, with every screen working end to end on an in-memory MOCK datasource.
No Supabase code is added (the schema is not approved yet); see
`lib/features/inventory/README.md` for what the future Supabase repository must do.

## What was ported

- `lib/features/inventory/` (flat, per CLAUDE.md): domain (entities, `rules/`,
  repositories, 37 use cases), data (datasource interface + mock, 4 repository
  impls using `guardCall`), presentation (bindings, controllers, pages, widgets,
  transfer-note PDF).
- Screens: Inventory dashboard + Report, Product list, Add Inventory, Add Stock,
  Add Returned, Damaged, Deleted, Inventory Payables, Product Transfer (list/create).
- Shared core pieces: `core/state` (Loadable, Notice + NoticeMixin),
  `core/widgets` (AppDataTable, TableToolbar, ExportMenu, FormCard/FormSection,
  dialogs, filters, pagination, ...), `core/utils` (currency/date formatters,
  Excel + PDF table export, file downloader), `core/storage/app_prefs`,
  `core/settings` (currency option/provider + in-memory `SettingsController`),
  `core/error/guard.dart` (`guardCall`).
- Auth DOMAIN only: `AuthUser`, `Screens`, `SessionProvider` under
  `features/auth/domain`, plus `features/auth/data/mock_session_provider.dart`
  (clearly marked MOCK demo super admin, registered in `InitialBindings`).
- App shell (`core/shell`: sidebar, top bar, `ShellController`) with Dashboard
  placeholder + Inventory nav items; `PermissionGuard` middleware.
- Business rules and their tests preserved (approved decisions: derived stock,
  available-only average cost, remainder-correct allocation, transfer state
  machine, payment guards, serial uniqueness). No Cash/Bank module; the payables
  bank dropdown is a small hardcoded list in the mock datasource.

## Deviations from pd_portal's template / CLAUDE.md (for the lead)

1. **Richer palette with hardcoded colors** in `core/theme/erp/` (`ErpColors`,
   `ErpSpacing`, `ErpRadius`, `ErpDimensions`, `ErpShadows`, `ErpTypography`,
   `ErpBreakpoints`) - renamed so nothing clashes with `AppColors`/`AppSizes`,
   which are untouched. This is the ONLY place hex colors live; feature code has
   none (enforced by `test/architecture_test.dart`). `ErpTheme.apply` layers the
   ERP component themes (inputs, buttons, cards, dividers, dialogs, snackbars)
   on top of `AppTheme`'s seed-based `ColorScheme`. Please review.
2. Feature layout is FLAT (`features/inventory`). The prototype groups features as
   `accounts/ admin/ hr/` - lead: which do you want long term?
3. `App` is pinned to `ThemeMode.light` because the ERP palette is light only.
   `AppPages.initial` is now `/dashboard`; the template stays at `/home`.
4. The mock `InventoryDataSource`, the mock session and `SettingsController` are
   registered in `InitialBindings` (permanent), because a mock must outlive a
   route. The real Supabase datasource is stateless and moves into
   `InventoryBinding` later.
5. `domain/rules/` folder (pure calculators/validators) in addition to the
   template's `entities/repositories/usecases`; no `data/models/` yet (no JSON
   until Supabase).
6. Filters/selection/pagination/form fields stay in `StatefulWidget`s as ephemeral
   view state; all data loading and operations live in controllers.
7. Export company name is the constant `CompanyConfig.bullion` ('BULLION'), not
   the flavor's `appName` - keep it simple until branding is per flavor.
8. `_template` files only received `dart format` whitespace changes.
9. `core/shell` imports the auth DOMAIN (`SessionProvider`, `Screens`) and
   `core/routes` imports feature pages (the template's `app_pages` already does).

## New packages (pubspec.yaml)

| Package | Purpose |
|---|---|
| `intl` | date and number formatting |
| `excel` | `.xlsx` export of every table (needs `equatable` 2.x, already ^2.0.7) |
| `pdf` | PDF table export and the stock transfer note |
| `file_saver` | saves/downloads exported files (web + mobile/desktop) |
| `shared_preferences` | persists per-user UI prefs (rows per page) |
| `flutter_localizations` (sdk) | Material localizations for date pickers |

Asset added: `assets/images/bullion_logo.jpeg` (export letterhead + sidebar logo).

## How to test

```
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test            # 159 tests
flutter build web -t lib/main_bullion.dart   # needs .env.pd/.env.bullion (copy .env.example)
flutter run -d chrome -t lib/main_bullion.dart --flavor bullion
```
Local `.env.pd` / `.env.bullion` are git-ignored; never commit them.

Tests: 144 ported (business rules, costing, transfer, payables, add inventory,
sections, export, widget flows) adapted to a small Get harness
(`test/support/harness.dart`), plus new mocktail tests (`guardCall`,
repository impl, use case), shell navigation, app boot and an architecture test
(domain purity, no cross-feature data/presentation imports, no `print`, no hex
colors in features, `Supabase.instance` only in `core/supabase`).

## Manual checklist

- [ ] App opens on Dashboard; sidebar shows Dashboard + Inventory; collapse works.
- [ ] Inventory dashboard: table, filters (chips), sort, pagination, Download
      Excel + PDF (all filtered rows; PDF has BULLION + logo + date/time).
- [ ] Product list: KPIs, row menu (View details / Delete with confirm).
- [ ] Add Inventory (Owned/Credit), Add Stock, Add Returned (returned + damaged).
- [ ] Damaged and Deleted pages list records and open details.
- [ ] Inventory Payables: record a payment (overpayment rejected), history dialog.
- [ ] Product Transfer: create, dispatch, receive, cancel, delete, PDF note.
- [ ] System currency picker relabels amounts (symbol only).
- [ ] Mobile width: cards instead of tables, filters in a bottom sheet.
- [ ] `/home` still shows the template page (needs a real Supabase env).

## Known gaps

- Mock data only; nothing persists across restarts. No Supabase datasources.
- No real auth: a demo super admin is always signed in (`MockSessionProvider`).
- Dark theme is not supported by the ERP palette (app pinned to light).
- Other modules (transactions, purchased orders, invoices, HR) are not ported;
  returns via credit note wait for the Invoices module.
- Download uses `file_saver`; verified by tests with a fake downloader and by the
  web build, not on every platform.
- PDF text is ASCII-folded (built-in Helvetica has no Unicode).
