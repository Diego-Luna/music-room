-- CreateEnum
CREATE TYPE "RoomKind" AS ENUM ('VOTE', 'PLAYLIST', 'DELEGATE');

-- CreateEnum
CREATE TYPE "RoomVisibility" AS ENUM ('PUBLIC', 'PRIVATE');

-- CreateEnum
CREATE TYPE "LicenseTier" AS ENUM ('FREE', 'PREMIUM');

-- CreateEnum
CREATE TYPE "VoteWindow" AS ENUM ('ALWAYS', 'SCHEDULED');

-- CreateEnum
CREATE TYPE "MemberRole" AS ENUM ('OWNER', 'ADMIN', 'MEMBER');

-- CreateEnum
CREATE TYPE "InvitationStatus" AS ENUM ('PENDING', 'ACCEPTED', 'DECLINED', 'REVOKED', 'EXPIRED');

-- CreateTable
CREATE TABLE "Room" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "kind" "RoomKind" NOT NULL,
    "visibility" "RoomVisibility" NOT NULL DEFAULT 'PUBLIC',
    "licenseTier" "LicenseTier" NOT NULL DEFAULT 'FREE',
    "ownerId" TEXT NOT NULL,
    "allowMembersEdit" BOOLEAN NOT NULL DEFAULT true,
    "voteWindow" "VoteWindow" NOT NULL DEFAULT 'ALWAYS',
    "voteStartsAt" TIMESTAMP(3),
    "voteEndsAt" TIMESTAMP(3),
    "voteLocationLat" DOUBLE PRECISION,
    "voteLocationLng" DOUBLE PRECISION,
    "voteLocationRadiusM" INTEGER,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Room_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RoomMember" (
    "id" TEXT NOT NULL,
    "roomId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "role" "MemberRole" NOT NULL DEFAULT 'MEMBER',
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RoomMember_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RoomInvitation" (
    "id" TEXT NOT NULL,
    "roomId" TEXT NOT NULL,
    "inviterId" TEXT NOT NULL,
    "inviteeId" TEXT NOT NULL,
    "status" "InvitationStatus" NOT NULL DEFAULT 'PENDING',
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "respondedAt" TIMESTAMP(3),

    CONSTRAINT "RoomInvitation_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Room_ownerId_idx" ON "Room"("ownerId");

-- CreateIndex
CREATE INDEX "Room_visibility_idx" ON "Room"("visibility");

-- CreateIndex
CREATE INDEX "Room_kind_idx" ON "Room"("kind");

-- CreateIndex
CREATE INDEX "RoomMember_userId_idx" ON "RoomMember"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "RoomMember_roomId_userId_key" ON "RoomMember"("roomId", "userId");

-- CreateIndex
CREATE INDEX "RoomInvitation_inviteeId_idx" ON "RoomInvitation"("inviteeId");

-- CreateIndex
CREATE INDEX "RoomInvitation_expiresAt_idx" ON "RoomInvitation"("expiresAt");

-- CreateIndex
CREATE UNIQUE INDEX "RoomInvitation_roomId_inviteeId_status_key" ON "RoomInvitation"("roomId", "inviteeId", "status");

-- AddForeignKey
ALTER TABLE "Room" ADD CONSTRAINT "Room_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RoomMember" ADD CONSTRAINT "RoomMember_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "Room"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RoomMember" ADD CONSTRAINT "RoomMember_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RoomInvitation" ADD CONSTRAINT "RoomInvitation_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "Room"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RoomInvitation" ADD CONSTRAINT "RoomInvitation_inviterId_fkey" FOREIGN KEY ("inviterId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RoomInvitation" ADD CONSTRAINT "RoomInvitation_inviteeId_fkey" FOREIGN KEY ("inviteeId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
