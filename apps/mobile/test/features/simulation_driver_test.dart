import 'package:cypress_realworld_for_personal_portfolio_mobile/core/test_id.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/simulation/simulation_driver.dart';
import 'package:cypress_realworld_for_personal_portfolio_mobile/features/simulation/simulation_run.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> finish(WidgetTester tester, Future<void> work) async {
  var done = false;
  Object? error;
  work.then(
    (_) => done = true,
    onError: (Object e) {
      error = e;
      done = true;
    },
  );
  for (var i = 0; i < 300 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(done, isTrue, reason: 'simulation action should settle');
  if (error != null) throw error!;
}

void main() {
  testWidgets('release driver uses actual gestures and formatted form edits', (
    tester,
  ) async {
    final run = SimulationRun();
    addTearDown(run.dispose);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    late BuildContext root;
    var changed = '';
    var pressed = 0;
    var automationPointers = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              root = context;
              return Listener(
                onPointerDown: (event) {
                  if (event.device == SimulationDriver.pointerDevice) {
                    automationPointers++;
                  }
                },
                child: Column(
                  children: [
                    TestId(
                      'field',
                      child: TextFormField(
                        controller: controller,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) => changed = value,
                      ),
                    ),
                    TestId(
                      'button',
                      child: FilledButton(
                        onPressed: () => pressed++,
                        child: const Text('Run'),
                      ),
                    ),
                    const Offstage(
                      child: TestId('hidden', child: Text('Hidden')),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    final driver = SimulationDriver(() => root, run);
    await finish(tester, driver.enter('field', '12ab34'));
    expect(controller.text, '1234');
    expect(changed, '1234');
    await finish(tester, driver.tap('button'));
    expect(pressed, 1);
    expect(automationPointers, 1);
    expect(driver.find('hidden'), isNull);
  });
}
