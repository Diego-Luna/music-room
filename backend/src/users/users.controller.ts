import { Body, Controller, Get, Param, Patch, Query } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import {
  PaginatedUsers,
  PublicUserProfile,
  UserProfile,
  UsersService,
} from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { SearchUsersDto } from './dto/search-users.dto';
import {
  UserProfileDto,
  PublicUserProfileDto,
  PaginatedUsersDto,
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
    summary: 'Search users by displayName, or list all visible users',
    description:
      'Case-insensitive substring match on displayName when `q` is given; ' +
      'omit `q` to browse all visible users. Paginated via limit/offset. ' +
      'Excludes the caller and PRIVATE profiles. Returns identity fields only.',
  })
  @ApiOkResponse({ type: PaginatedUsersDto })
  async search(
    @CurrentUser() user: JwtPayload,
    @Query() dto: SearchUsersDto,
  ): Promise<PaginatedUsers> {
    return this.users.searchByName(user.sub, dto.q, dto.limit, dto.offset);
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
