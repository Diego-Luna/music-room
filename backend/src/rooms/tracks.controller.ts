import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { TracksService } from './tracks.service';
import { AddTrackDto, VoteTrackDto } from './dto/track.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/auth.service';

@ApiTags('Rooms')
@ApiBearerAuth()
@Controller('rooms/:id/tracks')
export class TracksController {
  constructor(private readonly tracks: TracksService) {}

  @Get()
  @ApiOperation({ summary: 'List tracks for a VOTE room, ranked by score' })
  async list(
    @CurrentUser() user: JwtPayload,
    @Param('id') roomId: string,
  ) {
    return this.tracks.listRanked(roomId, user.sub);
  }

  @Post()
  @ApiOperation({ summary: 'Add a track suggestion to the queue' })
  @ApiResponse({ status: 201, description: 'Track added' })
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
  @ApiResponse({ status: 200, description: 'Vote recorded' })
  @ApiResponse({ status: 403, description: 'Voting closed or out of range' })
  async vote(
    @CurrentUser() user: JwtPayload,
    @Param('id') roomId: string,
    @Param('trackId') trackId: string,
    @Body() dto: VoteTrackDto,
  ) {
    return this.tracks.vote(roomId, trackId, user.sub, dto);
  }

  @Delete(':trackId')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Remove a track (author, owner or admin)' })
  async remove(
    @CurrentUser() user: JwtPayload,
    @Param('id') roomId: string,
    @Param('trackId') trackId: string,
  ) {
    await this.tracks.removeTrack(roomId, trackId, user.sub);
    return { message: 'Track removed' };
  }
}
