import { step } from "../fixture/step";
import { expectDisabledOnScreen, expectTextInsideOnScreen } from "./screen/expect-control";
import { byId } from "./screen/find";
import { tap } from "./screen/tap";
import { typeInto } from "./screen/type-into";

/**
 * 공통 코드: 거래 하나의 상세 화면을 연다. 그 거래의 상세가 보이면 끝난다.
 * 앱에는 주소가 없으므로, 홈의 "내 거래"에서 찾아 누른다 (남의 거래가 섞이지 않는다).
 */
export async function openTransactionDetail(transactionId: string) {
  return step("common", "openTransactionDetail", async () => {
    await tap("sidenav-home");
    await tap("nav-personal-tab");
    await tap(`transaction-item-${transactionId}`);
    await byId("transaction-detail-header").waitForDisplayed();
    await byId(`transaction-like-button-${transactionId}`).waitForDisplayed();
  });
}

/**
 * 공통 코드: 상세 화면에서 좋아요를 누른다.
 * 좋아요가 저장되면 앱이 버튼을 끄므로, 버튼이 꺼지는 것으로 동작이 됐는지 확인한다. 개수는 부른 쪽이 판정한다.
 */
export async function likeTransaction(transactionId: string) {
  return step("common", "likeTransaction", async () => {
    await tap(`transaction-like-button-${transactionId}`);
    await expectDisabledOnScreen(`transaction-like-button-${transactionId}`);
  });
}

/**
 * 공통 코드: 상세 화면에서 댓글을 쓰고 보내기 버튼을 누른다.
 * 등록된 댓글이 목록에 보이는 것으로 동작이 됐는지 확인한다. 개수와 쓴 사람은 부른 쪽이 판정한다.
 */
export async function writeComment(transactionId: string, text: string) {
  return step("common", "writeComment", async () => {
    await typeInto(`transaction-comment-input-${transactionId}`, text);
    await tap(`transaction-comment-submit-${transactionId}`);
    await expectTextInsideOnScreen("comments-list", text);
  });
}
