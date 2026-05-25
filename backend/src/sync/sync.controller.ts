import { Controller, Get } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { SyncService } from './sync.service';
import { SnapshotDto } from './dto/sync-response.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/auth.service';

@ApiTags('Sync')
@ApiBearerAuth()
@Controller('sync')
export class SyncController {
  constructor(private readonly sync: SyncService) {}

  @Get()
  @ApiOperation({
    summary:
      'Full snapshot of the user-relevant data for offline mode (VI.4)',
    description:
      "Returns the authenticated user's profile, accessible rooms, " +
      'pending invitations and friendships in one call. The mobile ' +
      'client uses this on reconnect to refresh its local cache after ' +
      'replaying queued offline mutations.',
  })
  @ApiOkResponse({ type: SnapshotDto })
  snapshot(@CurrentUser() user: JwtPayload) {
    return this.sync.snapshot(user.sub);
  }
}
