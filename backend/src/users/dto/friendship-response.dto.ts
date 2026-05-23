import { ApiProperty } from '@nestjs/swagger';

export class FriendshipDto {
  @ApiProperty() id!: string;
  @ApiProperty() requesterId!: string;
  @ApiProperty() addresseeId!: string;
  @ApiProperty({
    example: 'PENDING',
    description: 'PENDING | ACCEPTED | DECLINED | CANCELED',
  })
  status!: string;
  @ApiProperty() createdAt!: Date;
  @ApiProperty({ nullable: true }) respondedAt!: Date | null;
}

/** One accepted friend, as returned by `GET /users/me/friends`. */
export class FriendDto {
  @ApiProperty() friendshipId!: string;
  @ApiProperty() friendId!: string;
  @ApiProperty({ nullable: true, description: 'When the friendship was accepted' })
  since!: Date | null;
}
