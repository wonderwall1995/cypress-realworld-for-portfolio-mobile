import { step } from "../fixture/step";
import { byId } from "./screen/find";
import { tap } from "./screen/tap";
import { typeInto } from "./screen/type-into";

/**
 * 공통 코드: 내 계좌 탭에서 이체 화면을 열고 받는 사람을 고른다. 금액을 쓰는 화면(2단계)이 열리면 끝난다.
 * 받는 사람은 아이디로 찾아서 id 로 고른다 (같은 글자가 들어간 다른 사람을 고르지 않는다).
 */
export async function openTransferTo(receiver: { id: string; username: string }) {
  return step("common", "openTransferTo", async () => {
    await tap("sidenav-my-account");
    await tap("sidenav-transfer");
    await typeInto("user-list-search-input", receiver.username);
    await tap(`user-list-item-${receiver.id}`);
    await byId("transaction-create-form").waitForDisplayed();
  });
}

/**
 * 공통 코드: 이체 화면(2단계)에 금액(달러)과 메모를 쓴다. 계좌는 처음 골라진 것을 그대로 쓴다.
 * 쓰기만 한다: 버튼이 켜지는지, 안내가 나오는지는 부른 쪽이 판정한다 (거절 시험이 여기서 멈춰 판정한다).
 */
export async function fillTransfer(input: { dollars: number | string; memo: string }) {
  return step("common", "fillTransfer", async () => {
    await typeInto("transaction-create-amount-input", String(input.dollars));
    await typeInto("transaction-create-description-input", input.memo);
  });
}

/**
 * 공통 코드: "이체"를 누르고, 확인 창에 비밀번호를 쓰고, "이체"(확인)를 누른다.
 * 누르기까지만 한다: 이체가 끝났는지, 오류 문구가 나왔는지는 부른 쪽이 판정한다 (비밀번호 틀림 시험이 여기서 판정한다).
 */
export async function confirmTransfer(password: string) {
  return step("common", "confirmTransfer", async () => {
    await tap("transaction-create-submit-payment");
    await byId("transaction-confirm-dialog").waitForDisplayed();
    await typeInto("transaction-confirm-password", password);
    await tap("transaction-confirm-confirm");
  });
}

/**
 * 공통 코드: 화면으로 이체를 끝까지 한다. 받는 사람 고르기 -> 금액과 메모 -> 비밀번호 확인.
 * 서버가 이체를 받아 줘야 완료 단계(3단계)로 가므로, 완료 단계가 보이는 것으로 성공을 판정한다.
 * 끝나면 홈으로 돌아온다 (이체 화면에는 탭이 없다).
 */
export async function transfer(
  receiver: { id: string; username: string },
  input: { dollars: number; memo: string },
  password: string
) {
  return step("common", "transfer", async () => {
    await openTransferTo(receiver);
    await fillTransfer(input);
    await confirmTransfer(password);
    await byId("new-transaction-return-to-transactions").waitForDisplayed();
    await tap("new-transaction-return-to-transactions");
  });
}
