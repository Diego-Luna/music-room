import { Module } from '@nestjs/common';
import { RoomsController } from './rooms.controller';
import { RoomsService } from './rooms.service';
import { RoomMembershipController } from './membership.controller';
import { RoomMembershipService } from './membership.service';
import { TracksController } from './tracks.controller';
import { TracksService } from './tracks.service';
import { PlaylistController } from './playlist.controller';
import { PlaylistService } from './playlist.service';
import { InvitationsController } from './invitations.controller';
import { QueueProgressionService } from './queue-progression.service';
import { SubscriptionModule } from '../subscription/subscription.module';

@Module({
  imports: [SubscriptionModule],
  controllers: [
    RoomsController,
    RoomMembershipController,
    TracksController,
    PlaylistController,
    InvitationsController,
  ],
  providers: [
    RoomsService,
    RoomMembershipService,
    TracksService,
    PlaylistService,
    QueueProgressionService,
  ],
  exports: [
    RoomsService,
    RoomMembershipService,
    TracksService,
    PlaylistService,
  ],
})
export class RoomsModule {}
