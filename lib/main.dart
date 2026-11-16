import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'data/database/app_database.dart';
import 'providers/repository_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_GB');
  try {
    final db = await AppDatabase.open();
    runApp(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const SmartPantryApp(),
      ),
    );
  } catch (e) {
    runApp(_StartupErrorApp(error: e));
  }
}

/// Shown only if the local database can't be opened. Nothing is deleted.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Center(
              child: Text(
                'Smart Pantry couldn’t open its local database. Your data has '
                'not been deleted. Please restart the app.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
