-- CreateEnum
CREATE TYPE "VoteAccess" AS ENUM ('EVERYONE', 'INVITED_ONLY');

-- AlterTable
ALTER TABLE "Room" ADD COLUMN "voteAccess" "VoteAccess" NOT NULL DEFAULT 'EVERYONE';
