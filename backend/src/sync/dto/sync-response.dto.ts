import { ApiProperty } from '@nestjs/swagger';
import { UserProfileDto } from '../../users/dto/user-response.dto';
import { RoomDto } from '../../rooms/dto/room-response.dto';
import { RoomInvitationDto } from '../../rooms/dto/invitation-response.dto';
import { FriendshipDto } from '../../users/dto/friendship-response.dto';

// VI.4 — offline-mode snapshot. The mobile client fetches this on
// reconnect to refresh its local cache after replaying offline mutations.
export class SnapshotDto {
  @ApiProperty({
    example: '2026-05-23T12:34:56.789Z',
    description: 'Server timestamp when the snapshot was taken',
  })
  serverTime!: string;

  @ApiProperty({ type: UserProfileDto })
  me!: UserProfileDto;

  @ApiProperty({ type: [RoomDto], description: 'Rooms the user owns or has joined' })
  rooms!: RoomDto[];

  @ApiProperty({
    type: [RoomInvitationDto],
    description: 'Pending room invitations received by the user',
  })
  invitations!: RoomInvitationDto[];

  @ApiProperty({
    type: [FriendshipDto],
    description: 'PENDING and ACCEPTED friendships involving the user',
  })
  friendships!: FriendshipDto[];
}
