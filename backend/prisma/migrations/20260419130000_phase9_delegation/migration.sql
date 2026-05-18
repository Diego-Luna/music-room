-- AlterTable
ALTER TABLE "Room"
  ADD COLUMN "delegateUserId" TEXT,
  ADD COLUMN "delegateGrantedAt" TIMESTAMP(3);

-- AddForeignKey
ALTER TABLE "Room"
  ADD CONSTRAINT "Room_delegateUserId_fkey"
  FOREIGN KEY ("delegateUserId") REFERENCES "User"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

-- CreateIndex
CREATE INDEX "Room_delegateUserId_idx" ON "Room"("delegateUserId");
