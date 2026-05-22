import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Put,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { DelegationService } from './delegation.service';
import { GrantDelegationDto } from './dto/delegation.dto';
import {
  AccountDeviceDto,
  MusicControlDelegationDto,
  RevokeResultDto,
} from './dto/delegation-response.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/auth.service';

@ApiTags('Delegation')
@ApiBearerAuth()
@Controller('users/me')
export class DelegationController {
  constructor(private readonly delegation: DelegationService) {}

  @Get('devices')
  @ApiOperation({ summary: 'List the devices attached to my account' })
  @ApiOkResponse({
    type: AccountDeviceDto,
    isArray: true,
    description: 'Account devices, each with its current delegation or null',
  })
  listDevices(@CurrentUser() user: JwtPayload) {
    return this.delegation.listMyDevices(user.sub);
  }

  @Get('delegations')
  @ApiOperation({ summary: 'List devices I have delegated to friends' })
  @ApiOkResponse({ type: MusicControlDelegationDto, isArray: true })
  listMine(@CurrentUser() user: JwtPayload) {
    return this.delegation.listMyDelegations(user.sub);
  }

  @Get('controlled-devices')
  @ApiOperation({ summary: "List friends' devices I can control" })
  @ApiOkResponse({ type: MusicControlDelegationDto, isArray: true })
  listControlled(@CurrentUser() user: JwtPayload) {
    return this.delegation.listControlledDevices(user.sub);
  }

  @Get('devices/:deviceId/delegate')
  @ApiOperation({ summary: 'Get the current delegate for one of my devices' })
  @ApiOkResponse({
    type: MusicControlDelegationDto,
    description: 'The delegation for the device, or null if not delegated',
  })
  getCurrent(
    @CurrentUser() user: JwtPayload,
    @Param('deviceId') deviceId: string,
  ) {
    return this.delegation.getCurrent(user.sub, deviceId);
  }

  @Put('devices/:deviceId/delegate')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Grant a friend control of one of my devices' })
  @ApiOkResponse({
    type: MusicControlDelegationDto,
    description: 'The created/updated delegation',
  })
  @ApiResponse({ status: 403, description: 'Delegate is not a friend' })
  @ApiResponse({ status: 404, description: 'Delegate user not found' })
  grant(
    @CurrentUser() user: JwtPayload,
    @Param('deviceId') deviceId: string,
    @Body() dto: GrantDelegationDto,
  ) {
    return this.delegation.grant(user.sub, deviceId, dto.delegateUserId);
  }

  @Delete('devices/:deviceId/delegate')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Revoke control of one of my devices' })
  @ApiOkResponse({ type: RevokeResultDto })
  @ApiResponse({ status: 404, description: 'No delegation for this device' })
  revoke(
    @CurrentUser() user: JwtPayload,
    @Param('deviceId') deviceId: string,
  ) {
    return this.delegation.revoke(user.sub, deviceId);
  }
}
