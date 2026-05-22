import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export class GrantDelegationDto {
  @ApiProperty({
    description: 'User id of the friend who will control the device',
  })
  @IsString()
  @IsUUID()
  delegateUserId!: string;
}

export class PlayPlaybackDto {
  @ApiPropertyOptional({ type: [String], description: 'Spotify track URIs' })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  uris?: string[];

  @ApiPropertyOptional({ description: 'Spotify context URI (album, playlist)' })
  @IsOptional()
  @IsString()
  contextUri?: string;
}

export class VolumeDto {
  @ApiProperty({ minimum: 0, maximum: 100 })
  @IsInt()
  @Min(0)
  @Max(100)
  percent!: number;
}
