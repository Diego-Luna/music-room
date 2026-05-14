-- AlterTable
ALTER TABLE "Track" ADD COLUMN "position" TEXT;

-- CreateIndex
CREATE INDEX "Track_roomId_position_idx" ON "Track"("roomId", "position");
