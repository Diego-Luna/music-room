import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Put,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { SubscriptionService } from './subscription.service';
import { SwitchSubscriptionDto } from './dto/switch-subscription.dto';
import {
  SubscriptionDto,
  SubscriptionPlanDto,
} from './dto/subscription-response.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/auth.service';

@ApiTags('Subscription')
@ApiBearerAuth()
@Controller('subscription')
export class SubscriptionController {
  constructor(private readonly subscription: SubscriptionService) {}

  @Get('plans')
  @ApiOperation({ summary: 'List the available subscription offers' })
  @ApiOkResponse({ type: SubscriptionPlanDto, isArray: true })
  getPlans() {
    return this.subscription.getPlans();
  }

  @Get('me')
  @ApiOperation({ summary: 'Get my current subscription' })
  @ApiOkResponse({ type: SubscriptionDto })
  getMine(@CurrentUser() user: JwtPayload) {
    return this.subscription.getMine(user.sub);
  }

  @Put('me')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Switch between the free and premium offers' })
  @ApiOkResponse({ type: SubscriptionDto })
  switchMine(
    @CurrentUser() user: JwtPayload,
    @Body() dto: SwitchSubscriptionDto,
  ) {
    return this.subscription.switchTo(user.sub, dto.tier);
  }
}
