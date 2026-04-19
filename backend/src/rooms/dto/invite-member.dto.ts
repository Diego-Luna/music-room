import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsOptional, IsUUID } from 'class-validator';

export enum MemberRole {
  ADMIN = 'ADMIN',
  MEMBER = 'MEMBER',
}

export class InviteMemberDto {
  @ApiProperty({ description: 'User id to invite' })
  @IsUUID()
  userId!: string;

  @ApiPropertyOptional({ enum: MemberRole, default: MemberRole.MEMBER })
  @IsOptional()
  @IsEnum(MemberRole)
  role?: MemberRole;
}

export class UpdateMemberRoleDto {
  @ApiProperty({ enum: MemberRole })
  @IsEnum(MemberRole)
  role!: MemberRole;
}
