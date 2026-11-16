import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';

class SmartPantryApp extends StatefulWidget {
  const SmartPantryApp({super.key});

  @override
  State<SmartPantryApp> createState() => _SmartPantryAppState();
}

class _SmartPantryAppState extends State<SmartPantryApp> {
  late final GoRouter _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Smart Pantry',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: _router,
      locale: const Locale('en', 'GB'),
      supportedLocales: const [Locale('en', 'GB'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
