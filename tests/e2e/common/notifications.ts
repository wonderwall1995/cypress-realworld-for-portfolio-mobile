import { step } from "../fixture/step";
import { expectHiddenOnScreen } from "./screen/expect-control";
import { byId } from "./screen/find";
import { tap } from "./screen/tap";

/** 공통 코드: 알림 탭을 눌러 알림 화면을 연다. 누르면 앱이 알림을 다시 읽는다. 목록이 보이면 끝난다. */
export async function openNotifications() {
  return step("common", "openNotifications", async () => {
    await tap("sidenav-notifications");
    await byId("notifications-list").waitForDisplayed();
  });
}

/** 공통 코드: 알림 하나의 "확인"을 누른다. 그 알림의 "확인"이 사라지면 끝난다 (알림은 남는다). */
export async function confirmNotification(notificationId: string) {
  return step("common", "confirmNotification", async () => {
    await tap(`notification-mark-read-${notificationId}`);
    await expectHiddenOnScreen(`notification-mark-read-${notificationId}`);
  });
}
