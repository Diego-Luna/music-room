-- AlterTable
ALTER TABLE "SocialAccount"
  ADD COLUMN "accessToken" TEXT,
  ADD COLUMN "refreshToken" TEXT,
  ADD COLUMN "tokenExpiresAt" TIMESTAMP(3),
  ADD COLUMN "scope" TEXT,
  ADD COLUMN "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
