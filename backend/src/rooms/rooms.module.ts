import { Module } from '@nestjs/common';
import { RoomsController } from './rooms.controller';
import { RoomsService } from './rooms.service';
import { RoomMembershipController } from './membership.controller';
import { RoomMembershipService } from './membership.service';

@Module({
  controllers: [RoomsController, RoomMembershipController],
  providers: [RoomsService, RoomMembershipService],
  exports: [RoomsService, RoomMembershipService],
})
export class RoomsModule {}
