import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEnum,
  IsInt,
  IsISO8601,
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export enum RoomKind {
  VOTE = 'VOTE',
  PLAYLIST = 'PLAYLIST',
}

export enum RoomVisibility {
  PUBLIC = 'PUBLIC',
  PRIVATE = 'PRIVATE',
}

export enum VoteWindow {
  ALWAYS = 'ALWAYS',
  SCHEDULED = 'SCHEDULED',
}

export enum EditAccess {
  EVERYONE = 'EVERYONE',
  INVITED_ONLY = 'INVITED_ONLY',
}

export enum VoteAccess {
  EVERYONE = 'EVERYONE',
  INVITED_ONLY = 'INVITED_ONLY',
}

export class CreateRoomDto {
  @ApiProperty({ example: 'Chill Beats' })
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  name!: string;

  @ApiPropertyOptional({ example: 'Lofi and jazz for the afternoon' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @ApiProperty({ enum: RoomKind })
  @IsEnum(RoomKind)
  kind!: RoomKind;

  @ApiPropertyOptional({ enum: RoomVisibility, default: RoomVisibility.PUBLIC })
  @IsOptional()
  @IsEnum(RoomVisibility)
  visibility?: RoomVisibility;

  @ApiPropertyOptional({
    enum: EditAccess,
    default: EditAccess.EVERYONE,
    description: 'Who may edit the playlist (PLAYLIST rooms)',
  })
  @IsOptional()
  @IsEnum(EditAccess)
  editAccess?: EditAccess;

  @ApiPropertyOptional({
    enum: VoteAccess,
    default: VoteAccess.EVERYONE,
    description: 'Who may suggest/vote (VOTE rooms)',
  })
  @IsOptional()
  @IsEnum(VoteAccess)
  voteAccess?: VoteAccess;

  @ApiPropertyOptional({ enum: VoteWindow, default: VoteWindow.ALWAYS })
  @IsOptional()
  @IsEnum(VoteWindow)
  voteWindow?: VoteWindow;

  @ApiPropertyOptional({ description: 'ISO8601 start of voting window (SCHEDULED)' })
  @IsOptional()
  @IsISO8601()
  voteStartsAt?: string;

  @ApiPropertyOptional({ description: 'ISO8601 end of voting window (SCHEDULED)' })
  @IsOptional()
  @IsISO8601()
  voteEndsAt?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsLatitude()
  voteLocationLat?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsLongitude()
  voteLocationLng?: number;

  @ApiPropertyOptional({ description: 'Radius in meters for geo-gated voting' })
  @IsOptional()
  @IsInt()
  @Min(10)
  voteLocationRadiusM?: number;
}
