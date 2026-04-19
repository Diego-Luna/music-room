-- AlterTable
ALTER TABLE "Room" ADD COLUMN     "currentTrackId" TEXT;

-- CreateTable
CREATE TABLE "Track" (
    "id" TEXT NOT NULL,
    "roomId" TEXT NOT NULL,
    "provider" TEXT NOT NULL DEFAULT 'spotify',
    "providerId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "artist" TEXT NOT NULL,
    "durationMs" INTEGER NOT NULL,
    "artworkUrl" TEXT,
    "addedById" TEXT NOT NULL,
    "addedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "playedAt" TIMESTAMP(3),
    "score" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "Track_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrackVote" (
    "id" TEXT NOT NULL,
    "roomId" TEXT NOT NULL,
    "trackId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "value" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TrackVote_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Track_roomId_score_idx" ON "Track"("roomId", "score");

-- CreateIndex
CREATE UNIQUE INDEX "Track_roomId_provider_providerId_key" ON "Track"("roomId", "provider", "providerId");

-- CreateIndex
CREATE INDEX "TrackVote_roomId_trackId_idx" ON "TrackVote"("roomId", "trackId");

-- CreateIndex
CREATE UNIQUE INDEX "TrackVote_trackId_userId_key" ON "TrackVote"("trackId", "userId");

-- CreateIndex
CREATE UNIQUE INDEX "Room_currentTrackId_key" ON "Room"("currentTrackId");

-- AddForeignKey
ALTER TABLE "Room" ADD CONSTRAINT "Room_currentTrackId_fkey" FOREIGN KEY ("currentTrackId") REFERENCES "Track"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Track" ADD CONSTRAINT "Track_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "Room"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrackVote" ADD CONSTRAINT "TrackVote_trackId_fkey" FOREIGN KEY ("trackId") REFERENCES "Track"("id") ON DELETE CASCADE ON UPDATE CASCADE;
