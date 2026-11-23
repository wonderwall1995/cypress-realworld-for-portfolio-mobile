import 'package:cypress_realworld_for_personal_portfolio_mobile/features/auth/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the box moves the screen only when it is not in view, and again for another reason', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    String? message;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Column(
                  children: [
                    const SizedBox(height: 100),
                    if (message != null) FormErrorBanner(id: 'box', message: message!),
                    const SizedBox(height: 3000),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    Future<void> say(String? text) async {
      update(() => message = text);
      await tester.pumpAndSettle();
    }

    await say('one');
    expect(scroll.offset, 0); // in view already

    scroll.jumpTo(1000);
    await tester.pump();
    await say('two');
    expect(scroll.offset, 100);

    scroll.jumpTo(1000);
    await tester.pump();
    await say('two'); // nothing new to say: the user may be typing
    expect(scroll.offset, 1000);
  });
}
