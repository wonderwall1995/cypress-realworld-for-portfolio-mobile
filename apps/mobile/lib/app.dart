import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'core/providers.dart';
import 'core/session.dart';
import 'features/simulation/simulation_host.dart';
import 'features/simulation/simulation_scenarios.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Cypress Realworld For Personal Portfolio Mobile',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      // Korean texts for the date picker, back button, tooltips, and so on.
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => SimulationHost(
        execute: (selected, driver, run) => SimulationScenarios(
          api: ref.read(apiClientProvider),
          session: ref.read(sessionProvider.notifier),
          router: ref.read(routerProvider),
          ui: driver,
          run: run,
        ).execute(selected),
        child: child!,
      ),
    );
  }
}
