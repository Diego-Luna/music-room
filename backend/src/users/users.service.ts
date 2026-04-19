import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateUserDto, Visibility } from './dto/update-user.dto';

export interface UserProfile {
  id: string;
  email: string;
  displayName: string;
  avatarUrl: string | null;
  emailVerified: boolean;
  visibility: Visibility;
  musicPreferences: string[];
  createdAt: Date;
  updatedAt: Date;
}

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async findOne(userId: string): Promise<UserProfile> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return this.scrub(user);
  }

  async update(userId: string, dto: UpdateUserDto): Promise<UserProfile> {
    const data: Record<string, unknown> = {};
    if (dto.displayName !== undefined) data.displayName = dto.displayName;
    if (dto.avatarUrl !== undefined) data.avatarUrl = dto.avatarUrl;
    if (dto.visibility !== undefined) data.visibility = dto.visibility;
    if (dto.musicPreferences !== undefined) {
      data.musicPreferences = dto.musicPreferences;
    }

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data,
    });
    return this.scrub(updated);
  }

  private scrub(user: Record<string, unknown>): UserProfile {
    return {
      id: user.id as string,
      email: user.email as string,
      displayName: user.displayName as string,
      avatarUrl: (user.avatarUrl as string | null) ?? null,
      emailVerified: user.emailVerified as boolean,
      visibility: user.visibility as Visibility,
      musicPreferences: (user.musicPreferences as string[]) ?? [],
      createdAt: user.createdAt as Date,
      updatedAt: user.updatedAt as Date,
    };
  }
}
