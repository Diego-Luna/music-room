import { ApiProperty } from '@nestjs/swagger';

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
  @ApiProperty() createdAt!: Date;
  @ApiProperty() updatedAt!: Date;
}

export class PublicUserProfileDto {
  @ApiProperty() id!: string;
  @ApiProperty() displayName!: string;
  @ApiProperty({ nullable: true }) avatarUrl!: string | null;
  @ApiProperty({ example: 'PUBLIC', description: 'PUBLIC | FRIENDS_ONLY | PRIVATE' })
  visibility!: string;
  @ApiProperty({ type: [String] }) musicPreferences!: string[];
}
