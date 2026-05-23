import { ApiProperty } from '@nestjs/swagger';

export class SpotifyConnectionDto {
  @ApiProperty({ example: true }) connected!: boolean;
  @ApiProperty({ nullable: true, description: 'Access-token expiry' })
  expiresAt!: Date | null;
}

export class SpotifyDisconnectedDto {
  @ApiProperty({ example: true }) disconnected!: boolean;
}
