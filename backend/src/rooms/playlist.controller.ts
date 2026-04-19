import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { PlaylistService } from './playlist.service';
import {
  AddPlaylistItemDto,
  MovePlaylistItemDto,
} from './dto/playlist.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/auth.service';

@ApiTags('Rooms')
@ApiBearerAuth()
@Controller('rooms/:id/playlist')
export class PlaylistController {
  constructor(private readonly playlist: PlaylistService) {}

  @Get()
  @ApiOperation({ summary: 'List playlist items in order' })
  async list(
    @CurrentUser() user: JwtPayload,
    @Param('id') roomId: string,
  ) {
    return this.playlist.listOrdered(roomId, user.sub);
  }

  @Post()
  @ApiOperation({ summary: 'Add a track to the playlist' })
  @ApiResponse({ status: 201, description: 'Item added' })
  @ApiResponse({ status: 409, description: 'Item already in the playlist' })
  async add(
    @CurrentUser() user: JwtPayload,
    @Param('id') roomId: string,
    @Body() dto: AddPlaylistItemDto,
  ) {
    return this.playlist.addItem(roomId, user.sub, dto);
  }

  @Patch(':trackId/move')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reorder an item via fractional indices' })
  async move(
    @CurrentUser() user: JwtPayload,
    @Param('id') roomId: string,
    @Param('trackId') trackId: string,
    @Body() dto: MovePlaylistItemDto,
  ) {
    return this.playlist.moveItem(roomId, trackId, user.sub, dto);
  }

  @Delete(':trackId')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Remove an item (author, owner or admin)' })
  async remove(
    @CurrentUser() user: JwtPayload,
    @Param('id') roomId: string,
    @Param('trackId') trackId: string,
  ) {
    await this.playlist.removeItem(roomId, trackId, user.sub);
    return { message: 'Playlist item removed' };
  }
}
