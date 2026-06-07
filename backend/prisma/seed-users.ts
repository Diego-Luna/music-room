/**
 * Bulk user seeder — creates N users in one shot (default 500), for load
 * testing and demos.
 *
 * Run:
 *   npm run seed:users              # 500 users
 *   SEED_USER_COUNT=1000 npm run seed:users
 *   npm run seed:users -- 250       # positional arg also works
 *
 * Created users:
 *   email       : <prefix><i>@musicroom.local   (i = 1..N)
 *   password    : Password123!                  (shared, override with SEED_USER_PASSWORD)
 *   displayName : Load User <i>
 *   emailVerified: true                         (so they can log in immediately)
 *
 * Idempotent: re-running skips emails that already exist (ON CONFLICT DO NOTHING).
 */
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
});

const COUNT = Number(process.env.SEED_USER_COUNT ?? process.argv[2] ?? 500);
const PREFIX = process.env.SEED_USER_PREFIX ?? 'loaduser';
const PASSWORD = process.env.SEED_USER_PASSWORD ?? 'Password123!';

async function main() {
  if (process.env.NODE_ENV === 'production' && process.env.SEED_FORCE !== '1') {
    console.log(
      '[seed-users] NODE_ENV=production → refusing to seed (set SEED_FORCE=1 to override)',
    );
    return;
  }

  if (!Number.isInteger(COUNT) || COUNT <= 0) {
    throw new Error(`Invalid user count: ${process.argv[2] ?? COUNT}`);
  }

  console.log(`[seed-users] hashing shared password once...`);
  // * Hash ONCE and reuse — hashing 500x with bcrypt(12) would take minutes.
  const passwordHash = await bcrypt.hash(PASSWORD, 12);

  const data = Array.from({ length: COUNT }, (_, idx) => {
    const i = idx + 1;
    return {
      email: `${PREFIX}${i}@musicroom.local`,
      passwordHash,
      displayName: `Load User ${i}`,
      emailVerified: true,
    };
  });

  console.log(`[seed-users] inserting ${COUNT} users (${PREFIX}1..${PREFIX}${COUNT})...`);
  const result = await prisma.user.createMany({
    data,
    skipDuplicates: true,
  });

  console.log(
    `[seed-users] OK — ${result.count} created (${COUNT - result.count} already existed)`,
  );
  console.log(
    `[seed-users] login with any: ${PREFIX}<1..${COUNT}>@musicroom.local / ${PASSWORD}`,
  );
}

main()
  .catch((err) => {
    console.error('[seed-users] failed', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
