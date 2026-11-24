import { randomDigits, randomEnglish, randomKorean } from "./random";

/** 가입에 쓰는 무작위 값 한 벌 */
export interface RandomUser {
  lastName: string;
  firstName: string;
  username: string;
  phoneNumber: string;
  password: string;
}

/**
 * Fixture 코드: 가입에 쓰는 무작위 값 한 벌을 만든다.
 * - 성과 이름: 영어 6글자 (첫 글자는 대문자)
 * - 아이디: 한글 3글자
 * - 전화번호: 010-숫자4자리-숫자4자리
 * - 비밀번호: 숫자 4자리
 */
export const randomUser = (): RandomUser => ({
  lastName: randomEnglish(6),
  firstName: randomEnglish(6),
  username: randomKorean(3),
  phoneNumber: `010-${randomDigits(4)}-${randomDigits(4)}`,
  password: randomDigits(4),
});
