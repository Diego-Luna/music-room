import {
  IsInt,
  IsLatitude,
  IsLongitude,
  IsOptional,
  IsString,
  IsUrl,
  Length,
  Max,
  Min,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class AddTrackDto {
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

  @ApiProperty({ description: 'Duration in milliseconds' })
  @IsInt()
  @Min(1)
  @Max(24 * 60 * 60 * 1000)
  durationMs!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsUrl()
  artworkUrl?: string;
}

export class VoteTrackDto {
  @ApiProperty({ description: '+1 to boost, -1 to demote, 0 to clear' })
  @IsInt()
  @Min(-1)
  @Max(1)
  value!: number;

  @ApiPropertyOptional({ description: 'Latitude for geo-gated rooms' })
  @IsOptional()
  @IsLatitude()
  lat?: number;

  @ApiPropertyOptional({ description: 'Longitude for geo-gated rooms' })
  @IsOptional()
  @IsLongitude()
  lng?: number;
}
