import { IsArray, IsInt, IsOptional, IsString, IsUUID, Max, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class GrantDelegationDto {
  @ApiProperty({ description: 'User id to make DJ' })
  @IsUUID()
  userId!: string;
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
