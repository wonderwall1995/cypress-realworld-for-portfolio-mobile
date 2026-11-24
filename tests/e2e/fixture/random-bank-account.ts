import { random, randomDigits } from "./random";

// 실제 은행 이름을 조금씩 바꾼 가상의 은행 32곳: 한국풍 16곳 + 영미권풍 16곳. 계좌를 만들 때마다 이 중 하나를 무작위로 고른다
// (한 줄에 8곳씩 표처럼 읽히도록 Prettier가 줄을 바꾸지 않게 한다)
// prettier-ignore
const BANK_NAMES = [
  // 한국풍
  "KP국민은행", "신환은행", "우리들은행", "하라은행", "NP농산은행", "IBQ기업은행", "SD제일은행", "한국씨트은행",
  "카카우뱅크", "케이방크", "토수뱅크", "부상은행", "광조은행", "전복은행", "제루은행", "수혁은행",
  // 영미권풍
  "JPMorgan Chess", "Bank of North America", "Wells Cargo", "Citibunk", "Goldmen Sacks", "Morgana Stanley", "U.S. Banc", "PMC Bank",
  "Truest", "Capital Won", "TB Bank", "HSBD", "Barkleys", "Floyds Bank", "NatEast", "Standard Chartreuse",
];

/**
 * Fixture 코드: 무작위 은행 계좌 정보를 만든다.
 * - 은행 이름: 위 가상의 은행 32곳 중 하나를 무작위로 고른다 (1~32번 중 무작위).
 * - 계좌 번호: 무작위 숫자이고, 자리 수도 9~12자리 중에서 무작위로 정한다(앱은 9~12자리 숫자를 받는다).
 */
export function randomBankAccountInput() {
  const bankName = BANK_NAMES[random(0, BANK_NAMES.length - 1)];
  const accountNumber = randomDigits(random(9, 12));
  return { bankName, accountNumber };
}
