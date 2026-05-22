import {
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
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { RoomMembershipService } from './membership.service';
import {
  RoomInvitationDto,
  AcceptInvitationResultDto,
} from './dto/invitation-response.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/auth.service';

@ApiTags('Rooms')
@ApiBearerAuth()
@Controller('users/me/invitations')
export class InvitationsController {
  constructor(private readonly membership: RoomMembershipService) {}

  @Get()
  @ApiOperation({ summary: 'List my pending room invitations (received)' })
  @ApiOkResponse({
    type: RoomInvitationDto,
    isArray: true,
    description: 'Pending invitations received, with room + inviter projections',
  })
  async list(@CurrentUser() user: JwtPayload) {
    return this.membership.listMyInvitations(user.sub);
  }

  @Get('sent')
  @ApiOperation({ summary: 'List my pending room invitations (sent)' })
  @ApiOkResponse({
    type: RoomInvitationDto,
    isArray: true,
    description: 'Pending invitations sent, with room + invitee projections',
  })
  async listSent(@CurrentUser() user: JwtPayload) {
    return this.membership.listSentInvitations(user.sub);
  }

  @Post(':id/accept')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Accept a room invitation (joins the room)' })
  @ApiOkResponse({ type: AcceptInvitationResultDto })
  async accept(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.membership.acceptInvitation(user.sub, id);
  }

  @Post(':id/decline')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Decline a pending room invitation' })
  @ApiOkResponse({
    type: RoomInvitationDto,
    description: 'The invitation, now DECLINED',
  })
  async decline(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.membership.declineInvitation(user.sub, id);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Revoke a pending invitation (inviter or room admin)',
  })
  @ApiOkResponse({
    type: RoomInvitationDto,
    description: 'The invitation, now REVOKED',
  })
  async revoke(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.membership.revokeInvitation(user.sub, id);
  }
}
