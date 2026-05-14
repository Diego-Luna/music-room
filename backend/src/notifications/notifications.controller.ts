import {
  Body,
  Controller,
  Delete,
  HttpCode,
  HttpStatus,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PushService } from './push.service';
import {
  RegisterTokenBody,
  UnregisterTokenBody,
} from './dto/register-token.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/auth.service';

@ApiTags('Notifications')
@ApiBearerAuth()
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly push: PushService) {}

  @Post('register')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Register a device token for push notifications' })
  async register(
    @CurrentUser() user: JwtPayload,
    @Body() dto: RegisterTokenBody,
  ) {
    const record = await this.push.register(user.sub, {
      token: dto.token,
      platform: dto.platform,
    });
    return { id: record.id, registered: true };
  }

  @Delete('register')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Unregister a device token' })
  async unregister(
    @CurrentUser() user: JwtPayload,
    @Body() dto: UnregisterTokenBody,
  ) {
    await this.push.unregister(user.sub, dto.token);
    return { unregistered: true };
  }
}
