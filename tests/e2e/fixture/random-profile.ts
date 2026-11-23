import { randomDigits, randomEnglish } from "./random";

/** 설정 화면에서 고칠 수 있는 정보. 이메일과 전화번호는 비울 수 있다(빈 글자) */
export interface Profile {
  lastName: string;
  firstName: string;
  email: string;
  phoneNumber: string;
}

/** Fixture 코드: 바꿔 쓸 무작위 정보 한 벌을 만든다 (이름은 영문 8글자씩). */
export const randomProfile = (): Profile => ({
  lastName: randomEnglish(8),
  firstName: randomEnglish(8),
  email: `${randomEnglish(8).toLowerCase()}@example.com`,
  phoneNumber: `010-${randomDigits(4)}-${randomDigits(4)}`,
});
