import 'package:cypress_realworld_for_personal_portfolio_mobile/core/person_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the family name comes first, then the given name', () {
    expect(koreanFullName(firstName: '길동', lastName: '홍'), '홍 길동');
    expect(koreanFullName(firstName: 'Ada', lastName: 'Kim'), 'Kim Ada');
  });

  test('a missing part leaves no extra space', () {
    expect(koreanFullName(firstName: 'Ada', lastName: null), 'Ada');
    expect(koreanFullName(firstName: null, lastName: 'Kim'), 'Kim');
    expect(koreanFullName(firstName: '', lastName: ''), '');
    expect(koreanFullName(), '');
  });
}
