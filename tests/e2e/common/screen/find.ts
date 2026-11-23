import { $ } from "@wdio/globals";

// 바닥 도구: 식별자로 찾는다. 앱이 Appium에 보이는 모양의 함정(plan.md)을 common/screen/ 에서만 다룬다.

/** 식별자(웹의 data-testid 와 같은 이름)로 찾는다 */
export const byId = (id: string) => $(`android=new UiSelector().resourceId("${id}")`);

/** 어떤 줄(outer) 안에서 찾는다. 같은 식별자가 여러 번 나오는 것(bankaccount-delete 등)에 쓴다 */
export const inside = (outer: string, id: string) =>
  $(`//*[@resource-id="${outer}"]//*[@resource-id="${id}"]`);

/** 입력 칸. 식별자가 칸 자신에 있기도 하고(로그인), 그 안에 있기도 하다(날짜) */
export const inputOf = (id: string) =>
  $(
    `//android.widget.EditText[@resource-id="${id}"] | //*[@resource-id="${id}"]//android.widget.EditText`
  );

/** 진짜 버튼. 식별자는 바깥에 있고, 켜짐과 꺼짐은 이름 없는 안쪽 버튼에만 있다 */
export const buttonOf = (id: string) =>
  $(
    `//android.widget.Button[@resource-id="${id}"] | //*[@resource-id="${id}"]//android.widget.Button`
  );
