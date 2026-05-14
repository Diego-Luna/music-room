import {
  IsInt,
  IsOptional,
  IsString,
  IsUrl,
  IsUUID,
  Length,
  Max,
  Min,
  ValidateIf,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class AddPlaylistItemDto {
  @ApiPropertyOptional({ default: 'spotify' })
  @IsOptional()
  @IsString()
  @Length(1, 32)
  provider?: string;

  @ApiProperty()
  @IsString()
  @Length(1, 128)
  providerId!: string;

  @ApiProperty()
  @IsString()
  @Length(1, 255)
  title!: string;

  @ApiProperty()
  @IsString()
  @Length(1, 255)
  artist!: string;

  @ApiProperty()
  @IsInt()
  @Min(1)
  @Max(24 * 60 * 60 * 1000)
  durationMs!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUrl()
  artworkUrl?: string;

  @ApiPropertyOptional({ description: 'Place after this track (UUID)' })
  @IsOptional()
  @IsUUID()
  afterTrackId?: string;

  @ApiPropertyOptional({ description: 'Place before this track (UUID)' })
  @IsOptional()
  @IsUUID()
  beforeTrackId?: string;
}

export class MovePlaylistItemDto {
  @ApiPropertyOptional({ description: 'Place after this track (UUID)' })
  @IsOptional()
  @IsUUID()
  @ValidateIf((o: MovePlaylistItemDto) => !o.beforeTrackId)
  afterTrackId?: string;

  @ApiPropertyOptional({ description: 'Place before this track (UUID)' })
  @IsOptional()
  @IsUUID()
  beforeTrackId?: string;
}
