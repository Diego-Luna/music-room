import { ApiProperty } from '@nestjs/swagger';

export class RegisterTokenResultDto {
  @ApiProperty({ description: 'Id of the stored device-token row' })
  id!: string;
  @ApiProperty({ example: true }) registered!: boolean;
}

export class UnregisterTokenResultDto {
  @ApiProperty({ example: true }) unregistered!: boolean;
}
