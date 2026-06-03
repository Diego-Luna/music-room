-- Provider switch: Spotify → Deezer.
-- New tracks default to the "deezer" provider and carry a 30s preview MP3 URL
-- (Deezer `preview`), which the in-app player uses for playback.

-- AlterTable
ALTER TABLE "Track" ALTER COLUMN "provider" SET DEFAULT 'deezer';
ALTER TABLE "Track" ADD COLUMN "previewUrl" TEXT;
