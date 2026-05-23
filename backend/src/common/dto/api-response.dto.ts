import { ApiProperty } from '@nestjs/swagger';

/** Generic `{ message }` body returned by action endpoints. */
export class MessageResponseDto {
  @ApiProperty({ example: 'Operation successful' })
  message!: string;
}
