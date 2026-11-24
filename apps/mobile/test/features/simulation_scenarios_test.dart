import 'package:cypress_realworld_for_personal_portfolio_mobile/core/providers.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/core/router.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/core/session.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/core/theme.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/notifications/notification_live_sync.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/simulation/simulation_case.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/simulation/simulation_host.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/simulation/simulation_run.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/simulation/simulation_scenarios.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/simulation_server.dart';

void main() {
  for (final selected in SimulationCase.values) {
    testWidgets('${selected.code} native scenario drives the real app', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final server = SimulationServer();
      final client = server.client();
      SimulationRun? run;
      String lastStep = '';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(client),
            liveNotificationsEnabledProvider.overrideWithValue(false),
          ],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp.router(
              theme: appTheme,
              routerConfig: ref.watch(routerProvider),
              builder: (context, child) => SimulationHost(
                execute: (which, ui, task) {
                  run = task;
                  task.addListener(() => lastStep = task.message);
                  return SimulationScenarios(
                    api: client,
                    session: ref.read(sessionProvider.notifier),
                    router: ref.read(routerProvider),
                    ui: ui,
                    run: task,
                    clientFactory: server.client,
                  ).execute(which);
                },
                child: child!,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(byId('signin-simulation'));
      await tester.tap(byId('signin-simulation'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(byId('simulation-case-${selected.code}'));
      expect(find.text(selected.fileName), findsOneWidget);
      await tester.tap(byId('simulation-case-${selected.code}'));
      for (var i = 0; i < 20000; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (run?.phase == SimulationPhase.idle ||
            run?.phase == SimulationPhase.failed) {
          break;
        }
      }
      expect(
        run?.phase,
        SimulationPhase.idle,
        reason: '$lastStep / ${run?.failure}',
      );
      expect(run?.cleanupWarning, isFalse);
      expect(
        server.accounts,
        isEmpty,
        reason: 'Only this simulation\'s accounts should be cleaned up',
      );
      if (selected == SimulationCase.bankAccount) {
        expect(
          server.requests.where((r) => r == 'POST /bankAccounts').length,
          greaterThanOrEqualTo(61),
        );
      }
      await tester.pumpAndSettle();
      expect(byId('signin-username'), findsOneWidget);
      expect(byId('simulation-stop'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
