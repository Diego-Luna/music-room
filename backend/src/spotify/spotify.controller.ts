import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Query,
} from '@nestjs/common';
import { IsString, Length } from 'class-validator';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiQuery,
  ApiTags,
} from '@nestjs/swagger';
import { SpotifyService } from './spotify.service';
import {
  SpotifyConnectionDto,
  SpotifyDisconnectedDto,
} from './dto/spotify-response.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/auth.service';

class SpotifyCallbackDto {
  @IsString()
  @Length(1, 1024)
  code!: string;

  @IsString()
  @Length(1, 256)
  state!: string;
}

@ApiTags('Spotify')
@ApiBearerAuth()
@Controller('auth/spotify')
export class SpotifyController {
  constructor(private readonly spotify: SpotifyService) {}

  @Get('authorize-url')
  @ApiOperation({ summary: 'Generate a Spotify authorize URL + state' })
  @ApiOkResponse({
    description: 'The Spotify authorize URL and the CSRF `state` to echo back',
  })
  authorizeUrl() {
    return this.spotify.buildAuthorizeUrl();
  }

  @Post('callback')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Exchange a Spotify authorization code' })
  @ApiOkResponse({ type: SpotifyConnectionDto })
  async callback(
    @CurrentUser() user: JwtPayload,
    @Body() dto: SpotifyCallbackDto,
  ) {
    const tokens = await this.spotify.exchangeCode(user.sub, dto.code);
    return { connected: true, expiresAt: tokens.expiresAt };
  }

  @Get('status')
  @ApiOperation({ summary: 'Return whether Spotify is connected' })
  @ApiOkResponse({
    description: 'Spotify connection status for the current user',
  })
  status(@CurrentUser() user: JwtPayload) {
    return this.spotify.getStatus(user.sub);
  }

  @Delete()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Disconnect Spotify for the current user' })
  @ApiOkResponse({ type: SpotifyDisconnectedDto })
  async disconnect(@CurrentUser() user: JwtPayload) {
    await this.spotify.disconnect(user.sub);
    return { disconnected: true };
  }

  @Get('search')
  @ApiOperation({ summary: 'Search Spotify tracks (requires connection)' })
  @ApiQuery({ name: 'q', required: true })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiOkResponse({
    description: 'Track search results as returned by the Spotify Web API',
  })
  async search(
    @CurrentUser() user: JwtPayload,
    @Query('q') q: string,
    @Query('limit') limit?: string,
  ) {
    const n = limit ? Math.max(1, Math.min(50, parseInt(limit, 10) || 10)) : 10;
    return this.spotify.search(user.sub, q, n);
  }
}
