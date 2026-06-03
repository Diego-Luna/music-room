import { ApiProperty } from '@nestjs/swagger';

export class DeezerTrackDto {
  @ApiProperty({ example: '916424', description: 'Deezer track id (providerId)' })
  providerId!: string;

  @ApiProperty({ example: 'Lose Yourself' })
  title!: string;

  @ApiProperty({ example: 'Eminem' })
  artist!: string;

  @ApiProperty({ example: 326000, description: 'Duration in milliseconds' })
  durationMs!: number;

  @ApiProperty({ nullable: true, description: 'Cover art URL' })
  artworkUrl!: string | null;

  @ApiProperty({
    nullable: true,
    description: '30-second MP3 preview URL played by the in-app player',
  })
  previewUrl!: string | null;
}
