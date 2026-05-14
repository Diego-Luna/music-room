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
import { RoomsService } from './rooms.service';
import { CreateRoomDto } from './dto/create-room.dto';
import { UpdateRoomDto } from './dto/update-room.dto';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/auth.service';

@ApiTags('Rooms')
@ApiBearerAuth()
@Controller('rooms')
export class RoomsController {
  constructor(private readonly rooms: RoomsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a room (caller becomes owner)' })
  @ApiResponse({ status: 201, description: 'Room created' })
  async create(@CurrentUser() user: JwtPayload, @Body() dto: CreateRoomDto) {
    return this.rooms.create(user.sub, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List rooms visible to the caller' })
  async list(@CurrentUser() user: JwtPayload) {
    return this.rooms.list(user.sub);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get one room (404 if not visible)' })
  async findOne(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.rooms.findOne(id, user.sub);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update a room (owner / admin)' })
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
  async remove(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    await this.rooms.remove(id, user.sub);
    return { message: 'Room deleted' };
  }
}
