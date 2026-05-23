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
  ApiCreatedResponse,
  ApiOkResponse,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { FriendsService } from './friends.service';
import { RequestFriendshipDto } from './dto/friendship.dto';
import { FriendDto, FriendshipDto } from './dto/friendship-response.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/auth.service';

@ApiTags('Users')
@ApiBearerAuth()
@Controller('users/me/friends')
export class FriendsController {
  constructor(private readonly friends: FriendsService) {}

  @Get()
  @ApiOperation({ summary: 'List accepted friends' })
  @ApiOkResponse({ type: FriendDto, isArray: true })
  async list(@CurrentUser() user: JwtPayload) {
    return this.friends.listAccepted(user.sub);
  }

  @Get('incoming')
  @ApiOperation({ summary: 'List PENDING friend requests received' })
  @ApiOkResponse({ type: FriendshipDto, isArray: true })
  async incoming(@CurrentUser() user: JwtPayload) {
    return this.friends.listIncoming(user.sub);
  }

  @Get('outgoing')
  @ApiOperation({ summary: 'List PENDING friend requests sent' })
  @ApiOkResponse({ type: FriendshipDto, isArray: true })
  async outgoing(@CurrentUser() user: JwtPayload) {
    return this.friends.listOutgoing(user.sub);
  }

  @Post('request')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Send a friend request' })
  @ApiCreatedResponse({
    type: FriendshipDto,
    description: 'The created (or re-opened) friendship row',
  })
  @ApiResponse({ status: 409, description: 'Already friends or pending' })
  async request(
    @CurrentUser() user: JwtPayload,
    @Body() dto: RequestFriendshipDto,
  ) {
    return this.friends.request(user.sub, dto.userId);
  }

  @Post(':id/accept')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Accept a pending friend request' })
  @ApiOkResponse({
    type: FriendshipDto,
    description: 'The friendship, now ACCEPTED',
  })
  async accept(
    @CurrentUser() user: JwtPayload,
    @Param('id') friendshipId: string,
  ) {
    return this.friends.accept(user.sub, friendshipId);
  }

  @Post(':id/decline')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Decline a pending friend request' })
  @ApiOkResponse({
    type: FriendshipDto,
    description: 'The friendship, now DECLINED',
  })
  async decline(
    @CurrentUser() user: JwtPayload,
    @Param('id') friendshipId: string,
  ) {
    return this.friends.decline(user.sub, friendshipId);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Cancel a pending request or unfriend' })
  @ApiOkResponse({
    description:
      'For an unfriend: `{ id, removed: true }`. For a cancelled pending ' +
      'request: the friendship row now CANCELED.',
  })
  async cancel(
    @CurrentUser() user: JwtPayload,
    @Param('id') friendshipId: string,
  ) {
    return this.friends.cancel(user.sub, friendshipId);
  }
}
