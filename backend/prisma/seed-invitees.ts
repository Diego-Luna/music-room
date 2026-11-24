/**
 * A few login-ready accounts to invite, then accept or decline as them.
 *
 * Does not delete existing users, friendships, or rooms. Re-running resets
 * these three passwords so the credentials below stay valid.
 *
 * Run from backend/:
 *   npm run seed:invitees
 *   make db-seed-invitees
 *
 * Accounts (emailVerified, public, searchable by display name):
 *   alice.invite@musicroom.local  Alice Invite
 *   bob.invite@musicroom.local    Bob Invite
 *   carol.invite@musicroom.local  Carol Invite
 *   password: Password123!
 */
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
});

const PASSWORD = 'Password123!';

const INVITEES = [
  { email: 'alice.invite@musicroom.local', displayName: 'Alice Invite' },
  { email: 'bob.invite@musicroom.local', displayName: 'Bob Invite' },
  { email: 'carol.invite@musicroom.local', displayName: 'Carol Invite' },
];

async function main() {
  if (process.env.NODE_ENV === 'production' && process.env.SEED_FORCE !== '1') {
    console.log(
      '[seed-invitees] NODE_ENV=production → refusing to seed (set SEED_FORCE=1 to override)',
    );
    return;
  }

  const passwordHash = await bcrypt.hash(PASSWORD, 12);

  for (const invitee of INVITEES) {
    await prisma.user.upsert({
      where: { email: invitee.email },
      update: {
        passwordHash,
        displayName: invitee.displayName,
        emailVerified: true,
        visibility: 'PUBLIC',
      },
      create: {
        email: invitee.email,
        passwordHash,
        displayName: invitee.displayName,
        emailVerified: true,
        visibility: 'PUBLIC',
      },
    });
  }

  console.log('[seed-invitees] OK — log in as any of:');
  for (const invitee of INVITEES) {
    console.log(`  ${invitee.email}  (${invitee.displayName})`);
  }
  console.log(`  password: ${PASSWORD}`);
}

main()
  .catch((err) => {
    console.error('[seed-invitees] failed', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
