import { ApiProperty } from '@nestjs/swagger';

export class HealthStatusDto {
  @ApiProperty({ example: 'ok', description: 'ok | error' })
  status!: string;
  @ApiProperty({ example: 'connected', description: 'connected | disconnected' })
  db!: string;
  @ApiProperty({ example: 'connected', description: 'connected | disconnected' })
  redis!: string;
  @ApiProperty({ description: 'Process uptime in seconds' })
  uptime!: number;
}
