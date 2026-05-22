import { ApiProperty } from '@nestjs/swagger';

export class RoomInvitationDto {
  @ApiProperty() id!: string;
  @ApiProperty() roomId!: string;
  @ApiProperty() inviterId!: string;
  @ApiProperty() inviteeId!: string;
  @ApiProperty({
    example: 'PENDING',
    description: 'PENDING | ACCEPTED | DECLINED | REVOKED | EXPIRED',
  })
  status!: string;
  @ApiProperty() expiresAt!: Date;
  @ApiProperty() createdAt!: Date;
  @ApiProperty({ nullable: true }) respondedAt!: Date | null;
}

/** Result of accepting an invitation — the caller has joined the room. */
export class AcceptInvitationResultDto {
  @ApiProperty({ example: 'Joined' }) message!: string;
  @ApiProperty() roomId!: string;
}
