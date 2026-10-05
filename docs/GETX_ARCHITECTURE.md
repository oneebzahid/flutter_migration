# GetX architecture (matches pd_portal `CLAUDE.md`)

The app was converted from Redux + go_router to **GetX only** so it can be merged into
`pd_portal` (branch `acc_mig`). No Redux package or code remains (`pubspec.yaml`,
`pubspec.lock`, `lib/`, `test/` are clean).

## Layout

```
lib/
  core/            error/ (Failure, exceptions, guardCall) · usecase/ · state/ (Loadable, Notice)
                   routes/ (app_routes.dart, app_pages.dart, auth_guard.dart) · di/ · settings/ · widgets/ · theme/
  app/             app.dart (GetMaterialApp) · shell/ (AppShell, ShellController, sidebar)
  features/
    auth/                      shared session (AuthController implements SessionProvider)
    accounts/{inventory,settings,dashboard,...}
    admin/user_management/
    hr/employees/
      <feature>/{data,domain,presentation}
        data/datasources/      *_datasource.dart (interface) + mock_*_datasource.dart (throws typed exceptions)
        data/repositories/     *_repository_impl.dart  (the only try/catch: guardCall -> Either<Failure,T>)
        domain/entities|rules|repositories|usecases   (pure Dart, no flutter/get)
        presentation/bindings|controllers|pages|widgets
```

## Rules applied
- One use case per user action (`GetProductsUseCase`, `DispatchTransferUseCase`, ...).
- Controllers expose `Rx` state, call use cases only, publish feedback through `NoticeMixin`
  (`notice`), pages show it with `NoticeListener`. Pages read state with `Obx`.
- Routes are `AppRoutes` constants; `AuthGuard` (GetMiddleware) handles login redirect and
  per-screen permission. Every signed-in page is wrapped in `AppShell`; its collapse state
  lives in `ShellController`.
- Cross-feature access only through domain/core: `SessionProvider` (current user) and
  `CurrencyProvider` (system currency); `CurrencyPicker` lives in `core/widgets`.
- `InitialBindings({authDataSource, userDataSource, settingsDataSource, inventoryDataSource})`
  registers the in-memory mock data sources app-wide (a mock must outlive a route). Tests pass
  zero-latency mocks; the real app will pass Supabase data sources.

## Differences from pd_portal's template (for review)
1. Feature groups `accounts/ admin/ hr/` sit between `features/` and the feature folder.
2. Pure rules/calculators live in `domain/rules/` (not in the template's fixed list).
3. No `data/models/` (no JSON yet - mock stage); added when the Supabase datasources arrive.
4. Mock data sources are registered in `InitialBindings` (app-wide), not in each feature binding.
5. Filters, selection, pagination and form fields stay in `StatefulWidget`s as ephemeral view
   state; all data loading and operations are in controllers.
6. `core/routes/app_pages.dart` and `core/di/initial_bindings.dart` import feature code (the
   template's do too); `core/widgets/currency_picker.dart` uses the `CurrencyProvider` interface.
7. Non-reactive `SessionProvider.currentUser` (read once per page build).

## Tests
`test/support/harness.dart`: `Harness.install()` + feature bindings for controller tests,
`BullionApp(initialBinding: Harness.fresh().bindings)` for widget tests, and `until(condition)`
which waits on controller state (event-loop turns, never wall-clock sleeps).
