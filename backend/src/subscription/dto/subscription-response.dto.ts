import { ApiProperty } from '@nestjs/swagger';

export class SubscriptionPlanDto {
  @ApiProperty({ example: 'PREMIUM', description: 'FREE | PREMIUM' })
  tier!: string;

  @ApiProperty({ example: 'Premium' })
  label!: string;

  @ApiProperty({
    example: '9.99',
    description: 'Display price; "0" for the free plan',
  })
  price!: string;

  @ApiProperty({ type: [String] })
  features!: string[];
}

export class SubscriptionDto {
  @ApiProperty({ example: 'FREE', description: 'FREE | PREMIUM' })
  tier!: string;
}
