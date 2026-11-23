import { PrismaClient } from "@prisma/client";

let client: PrismaClient | undefined;

/** 내 PC의 DB를 읽는 자리. 읽기 전용 사용자로만 붙는다. 내 PC가 아니면 열지 않는다 (배포 DB를 건드리지 않는다) */
export const db = (): PrismaClient => {
  if (client) return client;
  const url = process.env.E2E_DATABASE_URL;
  if (!url) throw new Error("E2E_DATABASE_URL 이 없습니다. .env.example 을 보세요.");
  if (!["127.0.0.1", "localhost"].includes(new URL(url).hostname)) {
    throw new Error("내 PC의 DB만 볼 수 있습니다.");
  }
  client = new PrismaClient();
  return client;
};

/** 다 쓴 뒤 닫는다 (wdio.conf.ts 의 after 에서 한 번) */
export const closeDb = async () => {
  await client?.$disconnect();
  client = undefined;
};
