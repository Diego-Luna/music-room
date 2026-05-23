import { ApiProperty } from '@nestjs/swagger';

export class MusicControlDelegationDto {
  @ApiProperty() id!: string;
  @ApiProperty({ description: 'User id of the device owner' })
  ownerId!: string;
  @ApiProperty({ description: 'X-Device header value of the delegated device' })
  deviceId!: string;
  @ApiProperty({ description: 'User id of the friend who controls the device' })
  delegateUserId!: string;
  @ApiProperty() grantedAt!: Date;
}

/** One device of the account, with its current delegation (if any). */
export class AccountDeviceDto {
  @ApiProperty() deviceId!: string;
  @ApiProperty({ nullable: true }) userAgent!: string | null;
  @ApiProperty({ nullable: true }) lastSeenAt!: Date | null;
  @ApiProperty({ type: () => MusicControlDelegationDto, nullable: true })
  delegation!: MusicControlDelegationDto | null;
}

export class RevokeResultDto {
  @ApiProperty({ example: true }) revoked!: boolean;
}

export class PlaybackOkDto {
  @ApiProperty({ example: true }) ok!: boolean;
}
