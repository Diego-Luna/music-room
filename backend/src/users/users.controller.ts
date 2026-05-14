import { Body, Controller, Get, Param, Patch } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import {
  PublicUserProfile,
  UserProfile,
  UsersService,
} from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/auth.service';

@ApiTags('Users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Get current user profile' })
  @ApiResponse({ status: 200, description: 'Current user profile' })
  async me(@CurrentUser() user: JwtPayload): Promise<UserProfile> {
    return this.users.findOne(user.sub);
  }

  @Patch('me')
  @ApiOperation({ summary: 'Update current user profile' })
  @ApiResponse({ status: 200, description: 'Profile updated' })
  async updateMe(
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateUserDto,
  ): Promise<UserProfile> {
    return this.users.update(user.sub, dto);
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Get another user public profile (respects visibility)',
  })
  @ApiResponse({ status: 200, description: 'Public profile' })
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
