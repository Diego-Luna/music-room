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
  ApiCreatedResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { RoomsService } from './rooms.service';
import { CreateRoomDto } from './dto/create-room.dto';
import { UpdateRoomDto } from './dto/update-room.dto';
import { RoomDto } from './dto/room-response.dto';
import { MessageResponseDto } from '../common/dto/api-response.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/auth.service';

@ApiTags('Rooms')
@ApiBearerAuth()
@Controller('rooms')
export class RoomsController {
  constructor(private readonly rooms: RoomsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a room (caller becomes owner)' })
  @ApiCreatedResponse({ type: RoomDto, description: 'The created room' })
  async create(@CurrentUser() user: JwtPayload, @Body() dto: CreateRoomDto) {
    return this.rooms.create(user.sub, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List rooms visible to the caller' })
  @ApiOkResponse({ type: RoomDto, isArray: true })
  async list(@CurrentUser() user: JwtPayload) {
    return this.rooms.list(user.sub);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get one room (404 if not visible)' })
  @ApiOkResponse({ type: RoomDto })
  async findOne(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.rooms.findOne(id, user.sub);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update a room (owner / admin)' })
  @ApiOkResponse({ type: RoomDto, description: 'The updated room' })
  async update(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() dto: UpdateRoomDto,
  ) {
    return this.rooms.update(id, user.sub, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Delete a room (owner only)' })
  @ApiOkResponse({ type: MessageResponseDto })
  async remove(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    await this.rooms.remove(id, user.sub);
    return { message: 'Room deleted' };
  }
}
