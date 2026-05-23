-- AlterTable
ALTER TABLE "Room" ADD COLUMN "currentTrackStartedAt" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "MusicControlDelegation" (
    "id" TEXT NOT NULL,
    "ownerId" TEXT NOT NULL,
    "deviceId" TEXT NOT NULL,
    "delegateUserId" TEXT NOT NULL,
    "grantedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MusicControlDelegation_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "MusicControlDelegation_delegateUserId_idx" ON "MusicControlDelegation"("delegateUserId");

-- CreateIndex
CREATE UNIQUE INDEX "MusicControlDelegation_ownerId_deviceId_key" ON "MusicControlDelegation"("ownerId", "deviceId");

-- AddForeignKey
ALTER TABLE "MusicControlDelegation" ADD CONSTRAINT "MusicControlDelegation_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MusicControlDelegation" ADD CONSTRAINT "MusicControlDelegation_delegateUserId_fkey" FOREIGN KEY ("delegateUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
