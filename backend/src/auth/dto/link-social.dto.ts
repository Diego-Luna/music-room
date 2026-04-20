import { ApiProperty } from '@nestjs/swagger';
import { IsString, IsIn } from 'class-validator';

export class LinkSocialDto {
  @ApiProperty({ enum: ['google', 'facebook'] })
  @IsString()
  @IsIn(['google', 'facebook'])
  provider: 'google' | 'facebook';

  @ApiProperty({ description: 'OAuth access token from the provider' })
  @IsString()
  accessToken: string;
}
