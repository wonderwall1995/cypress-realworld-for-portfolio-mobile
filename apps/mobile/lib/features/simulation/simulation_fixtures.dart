import 'dart:math';

/// Port of Web repo tests/e2e/fixture/random*.ts. These are newly generated
/// demo values, not the numbered fixtures of a formal test run.
abstract final class SimulationFixtures {
  static final _random = Random.secure();
  static int integer(int min, int max) => min + _random.nextInt(max - min + 1);
  static String digits(int length) =>
      List.generate(length, (_) => '${integer(0, 9)}').join();
  static String english(int length) {
    final value = String.fromCharCodes(
      List.generate(length, (_) => integer(97, 122)),
    );
    return value[0].toUpperCase() + value.substring(1);
  }

  static String korean(int length) => String.fromCharCodes(
    List.generate(length, (_) => integer(0xac00, 0xd7a3)),
  );
  static String phone() => '010-${digits(4)}-${digits(4)}';

  static const bankNames = [
    'KP국민은행',
    '신환은행',
    '우리들은행',
    '하라은행',
    'NP농산은행',
    'IBQ기업은행',
    'SD제일은행',
    '한국씨트은행',
    '카카우뱅크',
    '케이방크',
    '토수뱅크',
    '부상은행',
    '광조은행',
    '전복은행',
    '제루은행',
    '수혁은행',
    'JPMorgan Chess',
    'Bank of North America',
    'Wells Cargo',
    'Citibunk',
    'Goldmen Sacks',
    'Morgana Stanley',
    'U.S. Banc',
    'PMC Bank',
    'Truest',
    'Capital Won',
    'TB Bank',
    'HSBD',
    'Barkleys',
    'Floyds Bank',
    'NatEast',
    'Standard Chartreuse',
  ];

  static Map<String, String> account({int? sequence}) => {
    'bankName': sequence == null
        ? bankNames[integer(0, bankNames.length - 1)]
        : '테스트 은행 ${sequence.toString().padLeft(2, '0')}',
    'accountNumber': digits(integer(9, 12)),
  };

  static Map<String, String> profile() => {
    'lastName': english(8),
    'firstName': english(8),
    'email': '${english(8).toLowerCase()}@example.com',
    'phoneNumber': phone(),
  };
}
