import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient({
	adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
});

// * Clear existing data to avoid conflicts on re-run
async function clearData() {
	await prisma.trackVote.deleteMany();
	await prisma.track.deleteMany();
	await prisma.roomMember.deleteMany();
	await prisma.room.deleteMany();
	await prisma.user.deleteMany();
}

// * Create mock users
async function seedUsers(passwordHash: string) {
	const demoUser = await prisma.user.create({
		data: {
			email: 'demo@musicroom.local',
			passwordHash,
			displayName: 'Demo User',
			emailVerified: true,
			subscriptionTier: 'PREMIUM',
		},
	});

	const friend1 = await prisma.user.create({
		data: {
			email: 'friend1@musicroom.local',
			passwordHash,
			displayName: 'Alice Smith',
			emailVerified: true,
		},
	});

	const friend2 = await prisma.user.create({
		data: {
			email: 'friend2@musicroom.local',
			passwordHash,
			displayName: 'Bob Jones',
			emailVerified: true,
		},
	});

	const diegoPasswordHash = await bcrypt.hash('Diego1@#', 12);
	const diegoUser = await prisma.user.create({
		data: {
			email: 'diego@42.fr',
			passwordHash: diegoPasswordHash,
			displayName: 'Diego Luna',
			emailVerified: true,
			subscriptionTier: 'PREMIUM',
		},
	});

	return { demoUser, friend1, friend2, diegoUser };
}

// * Create VOTE room and add initial tracks/votes
async function seedVoteRoom(ownerId: string, f1Id: string, f2Id: string, diegoId: string) {
	const voteRoom = await prisma.room.create({
		data: {
			name: 'Chill House Lounge',
			description: 'Vote for your favorite electronic music tracks!',
			kind: 'VOTE',
			visibility: 'PUBLIC',
			ownerId,
		},
	});

	await prisma.roomMember.createMany({
		data: [
			{ roomId: voteRoom.id, userId: ownerId, role: 'OWNER' },
			{ roomId: voteRoom.id, userId: f1Id, role: 'MEMBER' },
			{ roomId: voteRoom.id, userId: f2Id, role: 'MEMBER' },
			{ roomId: voteRoom.id, userId: diegoId, role: 'ADMIN' },
		],
	});

	const t1 = await prisma.track.create({
		data: {
			roomId: voteRoom.id,
			provider: 'spotify',
			providerId: '4PTG3Z6ehGkBF3zIqYQGSy',
			title: 'Strobe',
			artist: 'deadmau5',
			durationMs: 637000,
			artworkUrl: 'https://i.scdn.co/image/ab67616d0000b273b06e90141f274cb67a57a627',
			addedById: ownerId,
			score: 5,
		},
	});

	const t2 = await prisma.track.create({
		data: {
			roomId: voteRoom.id,
			provider: 'spotify',
			providerId: '0V3w5wRnccghw7GA45h6Wc',
			title: "Ghosts 'n' Stuff",
			artist: 'deadmau5',
			durationMs: 328000,
			artworkUrl: 'https://i.scdn.co/image/ab67616d0000b273b06e90141f274cb67a57a627',
			addedById: f1Id,
			score: 3,
		},
	});

	await prisma.track.create({
		data: {
			roomId: voteRoom.id,
			provider: 'spotify',
			providerId: '2TpxZ7JUBn3uw46aR7qd6V',
			title: 'The Veldt',
			artist: 'deadmau5',
			durationMs: 505000,
			artworkUrl: 'https://i.scdn.co/image/ab67616d0000b273b06e90141f274cb67a57a627',
			addedById: f2Id,
			score: 0,
		},
	});

	await prisma.trackVote.createMany({
		data: [
			{ roomId: voteRoom.id, trackId: t1.id, userId: ownerId, value: 1 },
			{ roomId: voteRoom.id, trackId: t1.id, userId: f1Id, value: 1 },
			{ roomId: voteRoom.id, trackId: t1.id, userId: f2Id, value: 1 },
			{ roomId: voteRoom.id, trackId: t2.id, userId: ownerId, value: 1 },
			{ roomId: voteRoom.id, trackId: t2.id, userId: f1Id, value: 1 },
		],
	});
}

// * Create PLAYLIST room and add tracks with position
async function seedPlaylistRoom(ownerId: string, f1Id: string, diegoId: string) {
	const playlistRoom = await prisma.room.create({
		data: {
			name: 'Summer Vibes 2026',
			description: 'Collaborative summer playlist.',
			kind: 'PLAYLIST',
			visibility: 'PUBLIC',
			ownerId,
		},
	});

	await prisma.roomMember.createMany({
		data: [
			{ roomId: playlistRoom.id, userId: ownerId, role: 'OWNER' },
			{ roomId: playlistRoom.id, userId: f1Id, role: 'MEMBER' },
			{ roomId: playlistRoom.id, userId: diegoId, role: 'ADMIN' },
		],
	});

	await prisma.track.createMany({
		data: [
			{
				roomId: playlistRoom.id,
				provider: 'spotify',
				providerId: '2a1oYHQ2wHU76Yk5m266T4',
				title: 'One More Time',
				artist: 'Daft Punk',
				durationMs: 320000,
				artworkUrl: 'https://i.scdn.co/image/ab67616d0000b273c52a0a2df3d8544f8f4a13f7',
				addedById: ownerId,
				position: 'a0',
			},
			{
				roomId: playlistRoom.id,
				provider: 'spotify',
				providerId: '49tMk8B2K546F385q0d606',
				title: 'Instant Crush',
				artist: 'Daft Punk',
				durationMs: 337000,
				artworkUrl: 'https://i.scdn.co/image/ab67616d0000b273c52a0a2df3d8544f8f4a13f7',
				addedById: f1Id,
				position: 'a1',
			},
			{
				roomId: playlistRoom.id,
				provider: 'spotify',
				providerId: '7ouMYWpwJ422jRcDASZB7P',
				title: 'Get Lucky',
				artist: 'Daft Punk',
				durationMs: 249000,
				artworkUrl: 'https://i.scdn.co/image/ab67616d0000b273c52a0a2df3d8544f8f4a13f7',
				addedById: ownerId,
				position: 'a2',
			},
		],
	});
}

async function main() {
	if (process.env.NODE_ENV === 'production') {
		console.log('[seed] NODE_ENV=production → skipping seed');
		return;
	}

	console.log('[seed] starting database seed...');
	await clearData();

	const passwordHash = await bcrypt.hash('password123', 12);
	const { demoUser, friend1, friend2, diegoUser } = await seedUsers(passwordHash);

	await seedVoteRoom(demoUser.id, friend1.id, friend2.id, diegoUser.id);
	await seedPlaylistRoom(demoUser.id, friend1.id, diegoUser.id);

	console.log('[seed] OK — demo@musicroom.local / password123');
}

main()
	.catch((err) => {
		console.error('[seed] failed', err);
		process.exit(1);
	})
	.finally(async () => {
		await prisma.$disconnect();
	});
