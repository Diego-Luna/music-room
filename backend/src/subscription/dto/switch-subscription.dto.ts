import { ApiProperty } from '@nestjs/swagger';
import { IsIn } from 'class-validator';

export class SwitchSubscriptionDto {
  @ApiProperty({ enum: ['FREE', 'PREMIUM'] })
  @IsIn(['FREE', 'PREMIUM'])
  tier!: 'FREE' | 'PREMIUM';
}
