import {
  Body,
  Controller,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Put,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { DelegationPlaybackService } from './delegation-playback.service';
import { PlayPlaybackDto, VolumeDto } from './dto/delegation.dto';
import { PlaybackOkDto } from './dto/delegation-response.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/auth.service';

const OK_RESPONSE = {
  status: 200,
  type: PlaybackOkDto,
  description: "`{ ok: true }` once the command is relayed to the owner's player.",
};
const FORBIDDEN_RESPONSE = {
  status: 403,
  description: 'Caller is neither the owner nor the delegate of the device.',
};
const NOT_FOUND_RESPONSE = {
  status: 404,
  description: 'Delegation not found.',
};

@ApiTags('Delegation')
@ApiBearerAuth()
@Controller('delegations/:delegationId/playback')
export class DelegationPlaybackController {
  constructor(private readonly playback: DelegationPlaybackService) {}

  @Post('play')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Start or resume playback on a delegated device' })
  @ApiResponse(OK_RESPONSE)
  @ApiResponse(FORBIDDEN_RESPONSE)
  @ApiResponse(NOT_FOUND_RESPONSE)
  play(
    @CurrentUser() user: JwtPayload,
    @Param('delegationId') delegationId: string,
    @Body() dto: PlayPlaybackDto,
  ) {
    return this.playback.play(delegationId, user.sub, dto);
  }

  @Post('pause')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Pause playback on a delegated device' })
  @ApiResponse(OK_RESPONSE)
  @ApiResponse(FORBIDDEN_RESPONSE)
  @ApiResponse(NOT_FOUND_RESPONSE)
  pause(
    @CurrentUser() user: JwtPayload,
    @Param('delegationId') delegationId: string,
  ) {
    return this.playback.pause(delegationId, user.sub);
  }

  @Post('next')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Skip to the next track on a delegated device' })
  @ApiResponse(OK_RESPONSE)
  @ApiResponse(FORBIDDEN_RESPONSE)
  @ApiResponse(NOT_FOUND_RESPONSE)
  next(
    @CurrentUser() user: JwtPayload,
    @Param('delegationId') delegationId: string,
  ) {
    return this.playback.next(delegationId, user.sub);
  }

  @Post('previous')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Skip to the previous track on a delegated device' })
  @ApiResponse(OK_RESPONSE)
  @ApiResponse(FORBIDDEN_RESPONSE)
  @ApiResponse(NOT_FOUND_RESPONSE)
  previous(
    @CurrentUser() user: JwtPayload,
    @Param('delegationId') delegationId: string,
  ) {
    return this.playback.previous(delegationId, user.sub);
  }

  @Put('volume')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Set the volume on a delegated device (0-100)' })
  @ApiResponse(OK_RESPONSE)
  @ApiResponse(FORBIDDEN_RESPONSE)
  @ApiResponse(NOT_FOUND_RESPONSE)
  volume(
    @CurrentUser() user: JwtPayload,
    @Param('delegationId') delegationId: string,
    @Body() dto: VolumeDto,
  ) {
    return this.playback.setVolume(delegationId, user.sub, dto.percent);
  }
}
