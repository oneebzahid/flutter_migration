import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import '../core/config/company_config.dart';
import '../core/di/initial_bindings.dart';
import '../core/routes/app_pages.dart';
import '../core/theme/app_theme.dart';

/// App root: theme, DI and routing only - no business logic here.
class BullionApp extends StatelessWidget {
  const BullionApp({
    super.key,
    this.company = CompanyConfig.bullion,
    this.initialBinding,
  });

  final CompanyConfig company;

  /// Override to inject other data sources (tests, a real backend).
  final Bindings? initialBinding;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: company.shortName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialBinding: initialBinding ?? InitialBindings(),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
      unknownRoute: AppPages.unknownRoute,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
    );
  }
}
