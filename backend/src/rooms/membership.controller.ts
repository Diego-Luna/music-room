import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { RoomMembershipService } from './membership.service';
import {
  InviteMemberDto,
  UpdateMemberRoleDto,
} from './dto/invite-member.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/auth.service';

@ApiTags('Rooms')
@ApiBearerAuth()
@Controller('rooms/:id')
export class RoomMembershipController {
  constructor(private readonly membership: RoomMembershipService) {}

  @Get('members')
  @ApiOperation({ summary: 'List members of a room' })
  async list(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.membership.listMembers(id, user.sub);
  }

  @Post('join')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Join a room (PUBLIC) or accept invitation (PRIVATE)' })
  async join(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    await this.membership.join(id, user.sub);
    return { message: 'Joined' };
  }

  @Post('leave')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Leave a room' })
  async leave(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    await this.membership.leave(id, user.sub);
    return { message: 'Left' };
  }

  @Post('invitations')
  @ApiOperation({ summary: 'Invite a user (owner/admin)' })
  @ApiResponse({ status: 201, description: 'Invitation created' })
  async invite(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() dto: InviteMemberDto,
  ) {
    return this.membership.invite(id, user.sub, dto);
  }

  @Patch('members/:userId/role')
  @ApiOperation({ summary: 'Change a member role (owner only)' })
  async updateRole(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Param('userId') targetUserId: string,
    @Body() dto: UpdateMemberRoleDto,
  ) {
    return this.membership.updateRole(id, user.sub, targetUserId, dto);
  }

  @Delete('members/:userId')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Remove a member (owner/admin)' })
  async removeMember(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Param('userId') targetUserId: string,
  ) {
    await this.membership.removeMember(id, user.sub, targetUserId);
    return { message: 'Member removed' };
  }
}
