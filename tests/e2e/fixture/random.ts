/**
 * Fixture 코드: 무작위 값의 기본 도구. 화면도 API도 다루지 않고 값만 만든다.
 * 다른 fixture 코드와 테스트가 이 도구로 무작위 값을 만든다.
 */

/** min 이상 max 이하의 무작위 정수 */
export const random = (min: number, max: number) =>
  Math.floor(Math.random() * (max - min + 1)) + min;

/** 영어 소문자 난수 (첫 글자는 대문자) */
export const randomEnglish = (length: number) => {
  const letters = Array.from({ length }, () => String.fromCharCode(97 + random(0, 25))).join("");
  return letters[0].toUpperCase() + letters.slice(1);
};

/** 한글 난수: 가(U+AC00)부터 힣(U+D7A3)까지의 글자 */
export const randomKorean = (length: number) =>
  Array.from({ length }, () => String.fromCharCode(random(0xac00, 0xd7a3))).join("");

/** 숫자 난수 n자리 (앞자리가 0이어도 n자리) */
export const randomDigits = (length: number) => Array.from({ length }, () => random(0, 9)).join("");
