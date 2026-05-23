-- DropForeignKey
ALTER TABLE "Room" DROP CONSTRAINT "Room_delegateUserId_fkey";

-- DropIndex
DROP INDEX "Room_delegateUserId_idx";

-- AlterEnum
BEGIN;
CREATE TYPE "RoomKind_new" AS ENUM ('VOTE', 'PLAYLIST');
ALTER TABLE "Room" ALTER COLUMN "kind" TYPE "RoomKind_new" USING ("kind"::text::"RoomKind_new");
ALTER TYPE "RoomKind" RENAME TO "RoomKind_old";
ALTER TYPE "RoomKind_new" RENAME TO "RoomKind";
DROP TYPE "RoomKind_old";
COMMIT;

-- AlterTable
ALTER TABLE "Room" DROP COLUMN "delegateUserId",
DROP COLUMN "delegateGrantedAt";
