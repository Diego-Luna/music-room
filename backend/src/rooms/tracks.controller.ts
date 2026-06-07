import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { TracksService } from './tracks.service';
import { AddTrackDto, VoteTrackDto } from './dto/track.dto';
import { TrackDto } from './dto/track-response.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/auth.service';

@ApiTags('Rooms')
@ApiBearerAuth()
@Controller('rooms/:id/tracks')
export class TracksController {
  constructor(private readonly tracks: TracksService) {}

  @Get()
  @ApiOperation({ summary: 'List tracks for a VOTE room, ranked by score' })
  @ApiOkResponse({ type: TrackDto, isArray: true })
  async list(
    @CurrentUser() user: JwtPayload,
    @Param('id') roomId: string,
  ) {
    return this.tracks.listRanked(roomId, user.sub);
  }

  @Post()
  @ApiOperation({ summary: 'Add a track suggestion to the queue' })
  @ApiCreatedResponse({ type: TrackDto, description: 'The added track' })
  @ApiResponse({ status: 409, description: 'Track already in the queue' })
  async add(
    @CurrentUser() user: JwtPayload,
    @Param('id') roomId: string,
    @Body() dto: AddTrackDto,
  ) {
    return this.tracks.addTrack(roomId, user.sub, dto);
  }

  @Post(':trackId/vote')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Vote on a track (+1 / -1 / 0 to clear)' })
  @ApiOkResponse({
    type: TrackDto,
    description: 'The track with its updated score',
  })
  @ApiResponse({ status: 403, description: 'Voting closed or out of range' })
  async vote(
    @CurrentUser() user: JwtPayload,
    @Param('id') roomId: string,
    @Param('trackId') trackId: string,
    @Body() dto: VoteTrackDto,
  ) {
    return this.tracks.vote(roomId, trackId, user.sub, dto);
  }
}
