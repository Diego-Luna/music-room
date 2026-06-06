import { Body, Controller, Get, Param, Patch, Query } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import {
  PublicUserProfile,
  UserProfile,
  UserSearchResult,
  UsersService,
} from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { SearchUsersDto } from './dto/search-users.dto';
import {
  UserProfileDto,
  PublicUserProfileDto,
  UserSearchResultDto,
} from './dto/user-response.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/auth.service';

@ApiTags('Users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Get current user profile' })
  @ApiOkResponse({
    type: UserProfileDto,
    description: 'The full private profile of the authenticated user',
  })
  async me(@CurrentUser() user: JwtPayload): Promise<UserProfile> {
    return this.users.findOne(user.sub);
  }

  @Patch('me')
  @ApiOperation({ summary: 'Update current user profile' })
  @ApiOkResponse({
    type: UserProfileDto,
    description: 'The updated profile',
  })
  async updateMe(
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateUserDto,
  ): Promise<UserProfile> {
    return this.users.update(user.sub, dto);
  }

  @Get('search')
  @ApiOperation({
    summary: 'Search users by displayName (to send friend requests)',
    description:
      'Case-insensitive substring match on displayName. Excludes the caller ' +
      'and PRIVATE profiles. Returns identity fields only.',
  })
  @ApiOkResponse({ type: UserSearchResultDto, isArray: true })
  async search(
    @CurrentUser() user: JwtPayload,
    @Query() dto: SearchUsersDto,
  ): Promise<UserSearchResult[]> {
    return this.users.searchByName(user.sub, dto.q, dto.limit);
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Get another user public profile (respects visibility)',
  })
  @ApiOkResponse({
    type: PublicUserProfileDto,
    description: 'The visibility-filtered public profile',
  })
  @ApiResponse({
    status: 404,
    description: 'User not found or not visible to caller',
  })
  async findOne(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ): Promise<PublicUserProfile> {
    return this.users.findOnePublic(user.sub, id);
  }
}
