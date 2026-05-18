import { IsEnum, IsString, Length } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export enum DevicePlatformDto {
  IOS = 'IOS',
  ANDROID = 'ANDROID',
  WEB = 'WEB',
}

export class RegisterTokenBody {
  @ApiProperty()
  @IsString()
  @Length(8, 512)
  token!: string;

  @ApiProperty({ enum: DevicePlatformDto })
  @IsEnum(DevicePlatformDto)
  platform!: DevicePlatformDto;
}

export class UnregisterTokenBody {
  @ApiProperty()
  @IsString()
  @Length(8, 512)
  token!: string;
}
