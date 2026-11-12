import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';

/// Types into the text field inside a test id (a plain TextField, not a form field).
Future<void> enterIn(WidgetTester tester, String id, String text) =>
    tester.enterText(find.descendant(of: byId(id), matching: find.byType(TextField)), text);

/// The last step of a payment: type the password and press the button.
Future<void> confirmTransfer(WidgetTester tester, {String password = 'pw-1234'}) async {
  await enterIn(tester, 'transfer-confirm-password-input', password);
  await tester.pump(); // the button turns on when something is typed
  await tapId(tester, 'transfer-confirm-submit');
}

/// Press 이체 on the form, then go through the password step with the right password.
Future<void> payNow(WidgetTester tester) async {
  await tapId(tester, 'transaction-create-submit-payment');
  await confirmTransfer(tester);
}

bool isRadioEnabled(WidgetTester tester, String id) =>
    tester.widget<RadioListTile<String>>(find.descendant(of: byId(id), matching: find.byType(RadioListTile<String>))).enabled ?? true;
