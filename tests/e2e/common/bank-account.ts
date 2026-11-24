import type { Person } from "../api/person";
import { expectNewBankAccountWithApi } from "../api/expect-bank-account";
import { randomBankAccountInput } from "../fixture/random-bank-account";
import { step } from "../fixture/step";
import { expectHiddenOnScreen, expectTextOnScreen } from "./screen/expect-control";
import { expectScreen } from "./screen/expect-screen";
import { inside } from "./screen/find";
import { scrollTo } from "./screen/scroll-to";
import { tap } from "./screen/tap";
import { typeInto } from "./screen/type-into";

/** 공통 코드: 은행 계좌 목록을 연다. 탭을 누르면 앱이 목록을 다시 읽는다. */
export async function openBankAccounts() {
  return step("common", "openBankAccounts", async () => {
    await tap("sidenav-bankaccounts");
    await expectScreen("bankAccounts");
  });
}

/**
 * 공통 코드: 은행 계좌 하나를 만든다. 만드는 일 전체를 한다 (목록이 열려 있을 때 부른다).
 * 1) 화면의 은행 계좌 양식으로 만든다. 계좌 정보는 무작위다. 만들어지면 앱이 목록으로 돌아오므로, 양식이 사라지는 것으로 성공을 판정한다.
 * 2) API로 그 계좌가 실제로 있고 금액이 0인지 확인한다.
 * 만든 계좌의 정보(API가 준 id 포함)를 돌려준다.
 */
export async function createBankAccount(who: Person) {
  return step("common", "createBankAccount", async () => {
    const account = randomBankAccountInput();
    await tap("bankaccount-new");
    await typeInto("bankaccount-bankName-input", account.bankName);
    await typeInto("bankaccount-accountNumber-input", account.accountNumber);
    await tap("bankaccount-submit");
    await expectHiddenOnScreen("bankaccount-form");
    await expectScreen("bankAccounts");

    const found = await expectNewBankAccountWithApi(who, account);
    return { ...account, id: found.id };
  });
}

/**
 * 공통 코드: 화면에서 은행 계좌 하나를 삭제한다 (앱은 지우기 전에 확인 창이 뜬다).
 * 앱의 삭제는 지우는 것이 아니라 숨기는 것(visible을 끔)이다. 금액이 0인 계좌만 삭제할 수 있다.
 * 삭제가 되면 그 계좌가 목록에서 사라지므로, 사라지는 것으로 성공을 판정한다.
 */
export async function deleteBankAccount(accountId: string) {
  return step("common", "deleteBankAccount", async () => {
    const row = `bankaccount-list-item-${accountId}`;
    await scrollTo(`bankaccount-balance-${accountId}`);
    await inside(row, "bankaccount-delete").click();
    await tap("bankaccount-delete-confirm");
    await expectHiddenOnScreen(row);
  });
}

/**
 * 공통 코드: 은행 계좌 목록에 이 계좌가 보이고, 은행 이름과 계좌 번호(끝 4자리)가 만든 값과 같다.
 * 앱은 계좌 번호를 끝 4자리만 보인다. 전체 번호는 API 도구가 확인한다.
 */
export async function expectBankAccountOnScreen(account: {
  id: string;
  bankName: string;
  accountNumber: string;
}) {
  return step("common", "expectBankAccountOnScreen", async () => {
    // 줄이 아니라 안쪽 글자까지 민다: 화면 끝에 걸친 줄은 안쪽 글자가 화면 구조에 없다
    await scrollTo(`bankaccount-account-number-${account.id}`);
    await expectTextOnScreen(`bankaccount-list-item-${account.id}`, account.bankName);
    await expectTextOnScreen(
      `bankaccount-account-number-${account.id}`,
      `계좌 번호 ····${account.accountNumber.slice(-4)}`
    );
  });
}
