import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsUUID } from 'class-validator';

export class RequestFriendshipDto {
  @ApiProperty({ description: 'User id to send a friend request to' })
  @IsString()
  @IsUUID()
  userId!: string;
}
