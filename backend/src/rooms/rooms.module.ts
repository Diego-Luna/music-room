import { Module } from '@nestjs/common';
import { RoomsController } from './rooms.controller';
import { RoomsService } from './rooms.service';
import { RoomMembershipController } from './membership.controller';
import { RoomMembershipService } from './membership.service';
import { TracksController } from './tracks.controller';
import { TracksService } from './tracks.service';
import { PlaylistController } from './playlist.controller';
import { PlaylistService } from './playlist.service';
import { DelegationController } from './delegation.controller';
import { DelegationService } from './delegation.service';
import { PlaybackService } from './playback.service';
import { SpotifyModule } from '../spotify/spotify.module';

@Module({
  imports: [SpotifyModule],
  controllers: [
    RoomsController,
    RoomMembershipController,
    TracksController,
    PlaylistController,
    DelegationController,
  ],
  providers: [
    RoomsService,
    RoomMembershipService,
    TracksService,
    PlaylistService,
    DelegationService,
    PlaybackService,
  ],
  exports: [
    RoomsService,
    RoomMembershipService,
    TracksService,
    PlaylistService,
    DelegationService,
    PlaybackService,
  ],
})
export class RoomsModule {}
