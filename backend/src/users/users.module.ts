import { Module } from '@nestjs/common';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { FriendsController } from './friends.controller';
import { FriendsService } from './friends.service';

@Module({
  controllers: [UsersController, FriendsController],
  providers: [UsersService, FriendsService],
  exports: [UsersService, FriendsService],
})
export class UsersModule {}
