import 'package:cypress_realworld_for_personal_portfolio_mobile/features/simulation/simulation_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native fixtures follow the Web random fixture contract', () {
    expect(SimulationFixtures.bankNames.toSet().length, 32);
    for (var i = 0; i < 64; i++) {
      expect(SimulationFixtures.english(6), matches(r'^[A-Z][a-z]{5}$'));
      expect(SimulationFixtures.korean(3), matches(r'^[가-힣]{3}$'));
      expect(SimulationFixtures.digits(4), matches(r'^\d{4}$'));
      expect(SimulationFixtures.phone(), matches(r'^010-\d{4}-\d{4}$'));
      final account = SimulationFixtures.account();
      expect(account['bankName'], isIn(SimulationFixtures.bankNames));
      expect(account['accountNumber'], matches(r'^\d{9,12}$'));
      final profile = SimulationFixtures.profile();
      expect(profile['lastName'], matches(r'^[A-Z][a-z]{7}$'));
      expect(profile['firstName'], matches(r'^[A-Z][a-z]{7}$'));
      expect(profile['email'], matches(r'^[a-z]{8}@example\.com$'));
      expect(profile['phoneNumber'], matches(r'^010-\d{4}-\d{4}$'));
      expect(SimulationFixtures.korean(8), matches(r'^[가-힣]{8}$'));
    }
    expect(SimulationFixtures.account(sequence: 9)['bankName'], '테스트 은행 09');
  });
}
