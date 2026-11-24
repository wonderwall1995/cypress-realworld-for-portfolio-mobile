/** 화면의 금액 글자: 소수점 없는 달러 ($1,234). 서버는 센트로 준다 */
export const moneyText = (cents: number) =>
  (cents / 100).toLocaleString("en-US", {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  });
