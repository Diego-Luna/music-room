import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class UserProfileDto {
  @ApiProperty() id!: string;
  @ApiProperty() email!: string;
  @ApiProperty() displayName!: string;
  @ApiProperty({ nullable: true }) avatarUrl!: string | null;
  @ApiProperty() emailVerified!: boolean;
  @ApiProperty({ example: 'PUBLIC', description: 'PUBLIC | FRIENDS_ONLY | PRIVATE' })
  visibility!: string;
  @ApiProperty({ example: 'FREE', description: 'FREE | PREMIUM' })
  subscriptionTier!: string;
  @ApiProperty({ type: [String] }) musicPreferences!: string[];
  @ApiProperty({ nullable: true }) publicInfo!: string | null;
  @ApiProperty({ nullable: true }) friendsInfo!: string | null;
  @ApiProperty({ nullable: true }) privateInfo!: string | null;
  @ApiProperty() createdAt!: Date;
  @ApiProperty() updatedAt!: Date;
}

export class UserSearchResultDto {
  @ApiProperty() id!: string;
  @ApiProperty() displayName!: string;
  @ApiProperty({ nullable: true }) avatarUrl!: string | null;
  @ApiProperty({ example: 'PUBLIC', description: 'PUBLIC | FRIENDS_ONLY' })
  visibility!: string;
}

export class PaginatedUsersDto {
  @ApiProperty({ type: [UserSearchResultDto] })
  items!: UserSearchResultDto[];
  @ApiProperty({ description: 'Total users matching the filter' })
  total!: number;
  @ApiProperty() limit!: number;
  @ApiProperty() offset!: number;
}

export class PublicUserProfileDto {
  @ApiProperty() id!: string;
  @ApiProperty() displayName!: string;
  @ApiProperty({ nullable: true }) avatarUrl!: string | null;
  @ApiProperty({ example: 'PUBLIC', description: 'PUBLIC | FRIENDS_ONLY | PRIVATE' })
  visibility!: string;
  @ApiProperty({ type: [String] }) musicPreferences!: string[];
  @ApiProperty({ nullable: true }) publicInfo!: string | null;
  @ApiPropertyOptional({
    nullable: true,
    description: 'Present only when the caller is a friend (or self)',
  })
  friendsInfo?: string | null;
  @ApiPropertyOptional({
    nullable: true,
    description: 'Present only when the caller is the profile owner',
  })
  privateInfo?: string | null;
}
