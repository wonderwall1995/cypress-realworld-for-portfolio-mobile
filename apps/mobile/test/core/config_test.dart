import 'package:cypress_realworld_for_personal_portfolio_mobile/core/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromEnvironment fails loudly when API_BASE_URL is not set', () {
    // The test run passes no --dart-define, so the value is empty.
    expect(AppConfig.fromEnvironment, throwsStateError);
  });

  group('validateApiBaseUrl', () {
    test('an empty address is refused', () {
      expect(validateApiBaseUrl('', isRelease: false), contains('API_BASE_URL is not set'));
      expect(validateApiBaseUrl('', isRelease: true), contains('API_BASE_URL is not set'));
    });

    test('a debug build accepts http and https', () {
      expect(validateApiBaseUrl('http://10.0.2.2:7201/api', isRelease: false), isNull);
      expect(validateApiBaseUrl('https://demo.example.test/api', isRelease: false), isNull);
    });

    test('a release build accepts only https', () {
      expect(validateApiBaseUrl('https://demo.example.test/api', isRelease: true), isNull);
      final problem = validateApiBaseUrl('http://10.0.2.2:7201/api', isRelease: true);
      expect(problem, contains('https'));
      expect(problem, contains('plain text'));
    });

    test('a scheme that is neither http nor https is refused', () {
      expect(validateApiBaseUrl('ftp://host/api', isRelease: false), contains('http:// or https://'));
    });

    test('text that is not an address is refused', () {
      expect(validateApiBaseUrl('not an address', isRelease: false), contains('not a valid address'));
      expect(validateApiBaseUrl('https://', isRelease: false), contains('not a valid address'));
    });
  });

  test('keeps the address it is given', () {
    const config = AppConfig(apiBaseUrl: 'http://api.test/api');
    expect(config.apiBaseUrl, 'http://api.test/api');
  });
}
