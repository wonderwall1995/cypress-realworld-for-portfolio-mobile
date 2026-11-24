import 'dart:async';

import 'package:cypress_realworld_for_personal_portfolio_mobile/core/providers.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/core/router.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/core/session.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/core/theme.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/notifications/notification_live_sync.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/simulation/simulation_host.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/simulation/simulation_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

void main() {
  for (final stopControl in ['simulation-stop', 'simulation-select']) {
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      testWidgets(
        'controls stay above dialogs; $stopControl signs out (${size.width})',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final server = FakeServer();
          late SimulationRun run;
          late WidgetRef appRef;
          final gate = Completer<void>();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                apiClientProvider.overrideWithValue(server.client()),
                liveNotificationsEnabledProvider.overrideWithValue(false),
              ],
              child: Consumer(
                builder: (context, ref, _) {
                  appRef = ref;
                  return MaterialApp.router(
                    theme: appTheme,
                    routerConfig: ref.watch(routerProvider),
                    builder: (context, child) => SimulationHost(
                      execute: (_, driver, activeRun) async {
                        run = activeRun;
                        await ref
                            .read(sessionProvider.notifier)
                            .signIn(
                              username: 'tester',
                              password: 'pass',
                              remember: false,
                            );
                        await driver.waitFor('sidenav-home');
                        final nav = ref
                            .read(routerProvider)
                            .routerDelegate
                            .navigatorKey;
                        unawaited(
                          showDialog<void>(
                            context: nav.currentContext!,
                            builder: (_) =>
                                const AlertDialog(title: Text('대화상자 위에도 중지')),
                          ),
                        );
                        await gate.future;
                        await run.checkpoint();
                      },
                      child: child!,
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(byId('signin-simulation'));
          await tapId(tester, 'signin-simulation');
          expect(byId('simulation-case-000'), findsOneWidget);
          await tapId(tester, 'simulation-case-000');
          expect(find.text('대화상자 위에도 중지'), findsOneWidget);
          expect(run.phase, SimulationPhase.running);
          for (final state in [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
          await tester.pump();
          expect(run.phase, SimulationPhase.paused);
          for (final state in [
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
          await tester.pump();
          expect(run.phase, SimulationPhase.paused);
          await tapId(tester, 'simulation-pause-resume');
          // Tapping the dialog is a human touch and pauses, even over a modal barrier.
          await tester.tap(find.text('대화상자 위에도 중지'));
          await tester.pump();
          expect(run.phase, SimulationPhase.paused);
          await tapId(tester, 'simulation-pause-resume');
          expect(run.phase, SimulationPhase.running);
          await tapId(tester, stopControl);
          expect(run.phase, SimulationPhase.stopping);
          gate.complete();
          await tester.pumpAndSettle(const Duration(milliseconds: 100));
          // Traffic drain requires a quiet interval, independent of rendered frames.
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();
          expect(
            appRef.read(sessionProvider).status,
            SessionStatus.unauthenticated,
          );
          expect(server.signedIn, isFalse);
          expect(byId('simulation-stop'), findsNothing);
          expect(byId('signin-username'), findsOneWidget);
          expect(find.text('대화상자 위에도 중지'), findsNothing);
          if (stopControl == 'simulation-select') {
            expect(byId('simulation-case-000'), findsOneWidget);
            await tapId(tester, 'simulation-close');
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
