import 'dart:async';

import 'package:cypress_realworld_for_personal_portfolio_mobile/features/simulation/simulation_run.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a touch pause blocks the next step until explicit resume', () async {
    final run = SimulationRun();
    addTearDown(run.dispose);
    final entered = Completer<void>();
    final request = Completer<void>();
    var next = false;
    final task = run.start('sample', () async {
      entered.complete();
      await request.future;
      await run.checkpoint();
      next = true;
    });
    await entered.future;
    run.pause();
    request.complete();
    await Future<void>.delayed(Duration.zero);
    expect(next, isFalse);
    expect(run.phase, SimulationPhase.paused);
    run.resume();
    await task;
    expect(next, isTrue);
    expect(run.phase, SimulationPhase.completed);
  });

  test(
    'stop joins an in-flight request and cancels following actions',
    () async {
      final run = SimulationRun();
      addTearDown(run.dispose);
      final request = Completer<void>();
      var next = false;
      var joined = false;
      final task = run.start('sample', () async {
        await request.future;
        await run.checkpoint();
        next = true;
      });
      final stopping = run.cancel().then((_) => joined = true);
      await Future<void>.delayed(Duration.zero);
      expect(joined, isFalse);
      request.complete();
      await stopping;
      await task;
      expect(next, isFalse);
      expect(run.phase, SimulationPhase.stopping);
    },
  );

  test('stop wakes a paused run without executing the next action', () async {
    final run = SimulationRun();
    addTearDown(run.dispose);
    final gate = Completer<void>();
    var next = false;
    final task = run.start('sample', () async {
      await gate.future;
      await run.checkpoint();
      next = true;
    });
    run.pause();
    gate.complete();
    await Future<void>.delayed(Duration.zero);
    await run.cancel();
    await task;
    expect(next, isFalse);
  });

  test('errors remain visible and do not report completion', () async {
    final run = SimulationRun();
    addTearDown(run.dispose);
    await run.start('sample', () async => throw StateError('private payload'));
    expect(run.phase, SimulationPhase.failed);
    expect(run.message, isNot(contains('private payload')));
  });
}
