import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEnum,
  IsOptional,
  IsString,
  IsUrl,
  MaxLength,
  MinLength,
  IsArray,
  ArrayMaxSize,
} from 'class-validator';

export enum Visibility {
  PUBLIC = 'PUBLIC',
  FRIENDS_ONLY = 'FRIENDS_ONLY',
  PRIVATE = 'PRIVATE',
}

export class UpdateUserDto {
  @ApiPropertyOptional({ example: 'Alice' })
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  displayName?: string;

  @ApiPropertyOptional({ example: 'https://cdn.example.com/a.png' })
  @IsOptional()
  @IsUrl()
  avatarUrl?: string;

  @ApiPropertyOptional({ enum: Visibility })
  @IsOptional()
  @IsEnum(Visibility)
  visibility?: Visibility;

  @ApiPropertyOptional({ type: [String], example: ['rock', 'jazz'] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @IsString({ each: true })
  musicPreferences?: string[];

  // V.1 — the three audience-scoped profile texts required by the subject:
  // "public informations", "informations only available to their friends",
  // "their private informations".
  @ApiPropertyOptional({ example: 'Hi, I love live concerts!' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  publicInfo?: string;

  @ApiPropertyOptional({ example: 'My phone: 06...' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  friendsInfo?: string;

  @ApiPropertyOptional({ example: 'Private notes only I can see' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  privateInfo?: string;
}
