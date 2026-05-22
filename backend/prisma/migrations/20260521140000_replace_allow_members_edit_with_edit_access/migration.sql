-- CreateEnum
CREATE TYPE "EditAccess" AS ENUM ('EVERYONE', 'INVITED_ONLY');

-- AlterTable
ALTER TABLE "Room" ADD COLUMN "editAccess" "EditAccess" NOT NULL DEFAULT 'EVERYONE';

-- Carry over the old boolean: allowMembersEdit=false meant "restricted edit".
UPDATE "Room" SET "editAccess" = 'INVITED_ONLY' WHERE "allowMembersEdit" = false;

-- DropColumn
ALTER TABLE "Room" DROP COLUMN "allowMembersEdit";
