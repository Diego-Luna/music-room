import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class SearchUsersDto {
  @ApiProperty({
    example: 'ali',
    description: 'Case-insensitive substring matched against displayName',
  })
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  q!: string;

  @ApiPropertyOptional({
    example: 20,
    description: 'Max results to return (1-50, default 20)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;
}
