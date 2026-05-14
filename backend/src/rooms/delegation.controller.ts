import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Put,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { DelegationService } from './delegation.service';
import { PlaybackService } from './playback.service';
import {
  GrantDelegationDto,
  PlayPlaybackDto,
  VolumeDto,
} from './dto/delegation.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/auth.service';

@ApiTags('Rooms')
@ApiBearerAuth()
@Controller('rooms/:id')
export class DelegationController {
  constructor(
    private readonly delegation: DelegationService,
    private readonly playback: PlaybackService,
  ) {}

  @Post('delegate')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Grant DJ control (owner only)' })
  async grant(
    @CurrentUser() user: JwtPayload,
    @Param('id') roomId: string,
    @Body() dto: GrantDelegationDto,
  ) {
    return this.delegation.grant(roomId, user.sub, dto.userId);
  }

  @Delete('delegate')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Revoke DJ control (owner or current delegate)' })
  async revoke(
    @CurrentUser() user: JwtPayload,
    @Param('id') roomId: string,
  ) {
    return this.delegation.revoke(roomId, user.sub);
  }

  @Get('delegate')
  @ApiOperation({ summary: 'Get the current DJ for the room' })
  async current(
    @CurrentUser() user: JwtPayload,
    @Param('id') roomId: string,
  ) {
    return this.delegation.getCurrent(roomId, user.sub);
  }

  @Post('playback/play')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Start or resume playback on the DJ device' })
  async play(
    @CurrentUser() user: JwtPayload,
    @Param('id') roomId: string,
    @Body() dto: PlayPlaybackDto,
  ) {
    return this.playback.play(roomId, user.sub, dto);
  }

  @Post('playback/pause')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Pause playback on the DJ device' })
  async pause(
    @CurrentUser() user: JwtPayload,
    @Param('id') roomId: string,
  ) {
    return this.playback.pause(roomId, user.sub);
  }

  @Post('playback/next')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Skip to the next track' })
  async next(
    @CurrentUser() user: JwtPayload,
    @Param('id') roomId: string,
  ) {
    return this.playback.next(roomId, user.sub);
  }

  @Post('playback/previous')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Skip to the previous track' })
  async previous(
    @CurrentUser() user: JwtPayload,
    @Param('id') roomId: string,
  ) {
    return this.playback.previous(roomId, user.sub);
  }

  @Put('playback/volume')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Set device volume (0-100)' })
  async volume(
    @CurrentUser() user: JwtPayload,
    @Param('id') roomId: string,
    @Body() dto: VolumeDto,
  ) {
    return this.playback.setVolume(roomId, user.sub, dto.percent);
  }
}
