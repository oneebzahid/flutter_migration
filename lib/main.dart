import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/storage/app_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPrefs.initPersistent();
  // Frontend-only: `InitialBindings` registers in-memory mock data sources;
  // they are swapped for Supabase ones when the backend is ready.
  runApp(const BullionApp());
}
