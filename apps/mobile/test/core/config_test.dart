import 'package:cypress_realworld_for_personal_portfolio_mobile/core/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromEnvironment fails loudly when API_BASE_URL is not set', () {
    // The test run passes no --dart-define, so the value is empty.
    expect(AppConfig.fromEnvironment, throwsStateError);
  });

  test('keeps the address it is given', () {
    const config = AppConfig(apiBaseUrl: 'http://api.test/api');
    expect(config.apiBaseUrl, 'http://api.test/api');
  });
}
