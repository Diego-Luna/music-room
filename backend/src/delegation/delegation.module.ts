import { Module } from '@nestjs/common';
import { DelegationController } from './delegation.controller';
import { DelegationService } from './delegation.service';
import { DelegationPlaybackController } from './delegation-playback.controller';
import { DelegationPlaybackService } from './delegation-playback.service';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [UsersModule],
  controllers: [DelegationController, DelegationPlaybackController],
  providers: [DelegationService, DelegationPlaybackService],
  exports: [DelegationService],
})
export class DelegationModule {}
