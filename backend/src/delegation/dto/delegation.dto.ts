import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsOptional, IsString, IsUUID, Max, Min } from 'class-validator';

export class GrantDelegationDto {
  @ApiProperty({
    description: 'User id of the friend who will control the device',
  })
  @IsString()
  @IsUUID()
  delegateUserId!: string;
}

export class PlayPlaybackDto {
  @ApiPropertyOptional({
    description: 'Track id to start playing (optional: omit to resume)',
  })
  @IsOptional()
  @IsString()
  trackId?: string;
}

export class VolumeDto {
  @ApiProperty({ minimum: 0, maximum: 100 })
  @IsInt()
  @Min(0)
  @Max(100)
  percent!: number;
}
