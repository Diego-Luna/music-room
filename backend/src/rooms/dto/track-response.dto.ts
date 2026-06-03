import { ApiProperty } from '@nestjs/swagger';

export class TrackDto {
  @ApiProperty() id!: string;
  @ApiProperty() roomId!: string;
  @ApiProperty({ example: 'deezer' }) provider!: string;
  @ApiProperty() providerId!: string;
  @ApiProperty() title!: string;
  @ApiProperty() artist!: string;
  @ApiProperty() durationMs!: number;
  @ApiProperty({ nullable: true }) artworkUrl!: string | null;
  @ApiProperty({ nullable: true, description: '30s preview MP3 URL' })
  previewUrl!: string | null;
  @ApiProperty() addedById!: string;
  @ApiProperty() addedAt!: Date;
  @ApiProperty({ nullable: true }) playedAt!: Date | null;
  @ApiProperty({ description: 'Net vote score (VOTE rooms)' })
  score!: number;
  @ApiProperty({
    nullable: true,
    description: 'Fractional index for ordering (PLAYLIST rooms)',
  })
  position!: string | null;
}
