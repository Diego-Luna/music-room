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
}
