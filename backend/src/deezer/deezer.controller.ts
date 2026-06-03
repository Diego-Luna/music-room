import { Controller, Get, Query } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiQuery,
  ApiTags,
} from '@nestjs/swagger';
import { DeezerService } from './deezer.service';
import { DeezerTrackDto } from './dto/deezer-response.dto';

@ApiTags('Search')
@ApiBearerAuth()
@Controller('search')
export class DeezerController {
  constructor(private readonly deezer: DeezerService) {}

  @Get()
  @ApiOperation({ summary: 'Search tracks (Deezer)' })
  @ApiQuery({ name: 'q', required: true })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiOkResponse({ type: [DeezerTrackDto] })
  search(@Query('q') q: string, @Query('limit') limit?: string) {
    const n = limit ? Math.max(1, Math.min(50, parseInt(limit, 10) || 10)) : 10;
    return this.deezer.search(q, n);
  }
}
