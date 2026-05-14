import { Global, Module } from '@nestjs/common';
import { NotificationsController } from './notifications.controller';
import { PushService } from './push.service';
import { LogPushTransport, PushTransport } from './push-transport';

@Global()
@Module({
  controllers: [NotificationsController],
  providers: [
    PushService,
    { provide: PushTransport, useClass: LogPushTransport },
  ],
  exports: [PushService],
})
export class NotificationsModule {}
