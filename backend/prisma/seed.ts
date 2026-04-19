import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  if (process.env.NODE_ENV === 'production') {
    console.log('[seed] NODE_ENV=production → skipping seed');
    return;
  }

  const passwordHash = await bcrypt.hash('password123', 12);

  await prisma.user.upsert({
    where: { email: 'demo@musicroom.local' },
    update: {},
    create: {
      email: 'demo@musicroom.local',
      passwordHash,
      displayName: 'Demo User',
      emailVerified: true,
    },
  });

  console.log('[seed] OK — demo@musicroom.local / password123');
}

main()
  .catch((err) => {
    console.error('[seed] failed', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
