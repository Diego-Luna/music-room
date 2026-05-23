import { ApiProperty } from '@nestjs/swagger';

export class AuthTokensDto {
  @ApiProperty({ description: 'Short-lived JWT access token' })
  accessToken!: string;

  @ApiProperty({ description: 'Long-lived refresh token (rotated on use)' })
  refreshToken!: string;
}

export class SessionDto {
  @ApiProperty() id!: string;
  @ApiProperty({ nullable: true, example: 'iPhone 15' })
  deviceId!: string | null;
  @ApiProperty({ nullable: true }) userAgent!: string | null;
  @ApiProperty({ nullable: true }) ip!: string | null;
  @ApiProperty() expiresAt!: Date;
  @ApiProperty() createdAt!: Date;
}
