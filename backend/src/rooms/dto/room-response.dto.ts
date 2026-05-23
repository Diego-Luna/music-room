import { ApiProperty } from '@nestjs/swagger';

export class RoomDto {
  @ApiProperty() id!: string;
  @ApiProperty() name!: string;
  @ApiProperty({ nullable: true }) description!: string | null;
  @ApiProperty({ example: 'VOTE', description: 'VOTE | PLAYLIST' })
  kind!: string;
  @ApiProperty({ example: 'PUBLIC', description: 'PUBLIC | PRIVATE' })
  visibility!: string;
  @ApiProperty() ownerId!: string;
  @ApiProperty({ example: 'EVERYONE', description: 'EVERYONE | INVITED_ONLY' })
  editAccess!: string;
  @ApiProperty({ example: 'EVERYONE', description: 'EVERYONE | INVITED_ONLY' })
  voteAccess!: string;
  @ApiProperty({ example: 'ALWAYS', description: 'ALWAYS | SCHEDULED' })
  voteWindow!: string;
  @ApiProperty({ nullable: true }) voteStartsAt!: Date | null;
  @ApiProperty({ nullable: true }) voteEndsAt!: Date | null;
  @ApiProperty({ nullable: true }) voteLocationLat!: number | null;
  @ApiProperty({ nullable: true }) voteLocationLng!: number | null;
  @ApiProperty({ nullable: true }) voteLocationRadiusM!: number | null;
  @ApiProperty({ nullable: true }) currentTrackId!: string | null;
  @ApiProperty({ nullable: true }) currentTrackStartedAt!: Date | null;
  @ApiProperty() createdAt!: Date;
  @ApiProperty() updatedAt!: Date;
}

export class RoomMemberDto {
  @ApiProperty() id!: string;
  @ApiProperty() roomId!: string;
  @ApiProperty() userId!: string;
  @ApiProperty({ example: 'MEMBER', description: 'OWNER | ADMIN | MEMBER' })
  role!: string;
  @ApiProperty() joinedAt!: Date;
}
