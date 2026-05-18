/*
  Warnings:

  - You are about to drop the column `licenseTier` on the `Room` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "Room" DROP COLUMN "licenseTier";

-- DropEnum
DROP TYPE "LicenseTier";
