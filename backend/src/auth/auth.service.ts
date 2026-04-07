import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { JwtBlacklistService } from './jwt-blacklist.service';
import { RegisterDto } from './dto/register.dto';
import { SocialLoginDto } from './dto/social-login.dto';
import { LinkSocialDto } from './dto/link-social.dto';

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

export interface JwtPayload {
  sub: string;
  email: string;
}

interface SocialProfile {
  id: string;
  email: string;
  name: string;
  picture?: string;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private readonly BCRYPT_ROUNDS = 12;

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly jwtBlacklist: JwtBlacklistService,
  ) {}

  async register(dto: RegisterDto): Promise<TokenPair> {
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (existing) {
      throw new ConflictException('Email already registered');
    }

    const passwordHash = await bcrypt.hash(dto.password, this.BCRYPT_ROUNDS);
    const emailVerifyToken = crypto.randomUUID();

    const user = await this.prisma.user.create({
      data: {
        email: dto.email,
        passwordHash,
        displayName: dto.displayName,
        emailVerifyToken,
      },
    });

    this.logger.log(`User registered: ${user.id}`);
    return this.generateTokenPair(user.id, user.email);
  }

  async validateUser(email: string, password: string): Promise<{ id: string; email: string }> {
    const user = await this.prisma.user.findUnique({
      where: { email },
    });
    if (!user || !user.passwordHash) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const isValid = await bcrypt.compare(password, user.passwordHash);
    if (!isValid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    return { id: user.id, email: user.email };
  }

  async login(email: string, password: string): Promise<TokenPair> {
    const user = await this.validateUser(email, password);
    return this.generateTokenPair(user.id, user.email);
  }

  async socialLogin(dto: SocialLoginDto): Promise<TokenPair> {
    const profile = await this.verifySocialToken(dto.provider, dto.accessToken);

    // Check if social account already linked
    const existingSocial = await this.prisma.socialAccount.findUnique({
      where: {
        provider_providerId: {
          provider: dto.provider,
          providerId: profile.id,
        },
      },
      include: { user: true },
    });

    if (existingSocial) {
      return this.generateTokenPair(
        existingSocial.user.id,
        existingSocial.user.email,
      );
    }

    // Check if user with this email exists
    const existingUser = await this.prisma.user.findUnique({
      where: { email: profile.email },
    });

    if (existingUser) {
      // Link social account to existing user
      await this.prisma.socialAccount.create({
        data: {
          provider: dto.provider,
          providerId: profile.id,
          userId: existingUser.id,
        },
      });
      return this.generateTokenPair(existingUser.id, existingUser.email);
    }

    // Create new user with social account
    const user = await this.prisma.user.create({
      data: {
        email: profile.email,
        displayName: profile.name,
        avatarUrl: profile.picture,
        emailVerified: true,
        socialAccounts: {
          create: {
            provider: dto.provider,
            providerId: profile.id,
          },
        },
      },
    });

    this.logger.log(`User created via ${dto.provider}: ${user.id}`);
    return this.generateTokenPair(user.id, user.email);
  }

  async linkSocial(userId: string, dto: LinkSocialDto): Promise<void> {
    const profile = await this.verifySocialToken(dto.provider, dto.accessToken);

    // Check if this social account is already linked to another user
    const existing = await this.prisma.socialAccount.findUnique({
      where: {
        provider_providerId: {
          provider: dto.provider,
          providerId: profile.id,
        },
      },
    });

    if (existing) {
      throw new ConflictException(
        'This social account is already linked to another user',
      );
    }

    // Check if user already has this provider linked
    const userSocial = await this.prisma.socialAccount.findUnique({
      where: {
        provider_userId: {
          provider: dto.provider,
          userId,
        },
      },
    });

    if (userSocial) {
      throw new ConflictException(
        `A ${dto.provider} account is already linked to your profile`,
      );
    }

    await this.prisma.socialAccount.create({
      data: {
        provider: dto.provider,
        providerId: profile.id,
        userId,
      },
    });
  }

  async verifyEmail(token: string): Promise<void> {
    const user = await this.prisma.user.findFirst({
      where: { emailVerifyToken: token },
    });

    if (!user) {
      throw new BadRequestException('Invalid or expired verification token');
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        emailVerified: true,
        emailVerifyToken: null,
      },
    });
  }

  async forgotPassword(email: string): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { email },
    });

    // Always return success to prevent email enumeration
    if (!user) return;

    const resetToken = crypto.randomUUID();
    const expires = new Date(Date.now() + 3600_000); // 1 hour

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        resetPasswordToken: resetToken,
        resetPasswordExpires: expires,
      },
    });

    // In production, send email with reset link
    this.logger.log(`Password reset requested for user: ${user.id}`);
  }

  async resetPassword(token: string, newPassword: string): Promise<void> {
    const user = await this.prisma.user.findFirst({
      where: {
        resetPasswordToken: token,
        resetPasswordExpires: { gt: new Date() },
      },
    });

    if (!user) {
      throw new BadRequestException('Invalid or expired reset token');
    }

    const passwordHash = await bcrypt.hash(newPassword, this.BCRYPT_ROUNDS);

    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        passwordHash,
        resetPasswordToken: null,
        resetPasswordExpires: null,
      },
    });
  }

  async refresh(refreshToken: string): Promise<TokenPair> {
    try {
      const payload = this.jwtService.verify<JwtPayload>(refreshToken, {
        secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
      });

      const isBlacklisted = await this.jwtBlacklist.isBlacklisted(refreshToken);
      if (isBlacklisted) {
        throw new UnauthorizedException('Token has been revoked');
      }

      // Blacklist old refresh token
      const exp = (this.jwtService.decode(refreshToken) as Record<string, number>).exp;
      const ttl = exp - Math.floor(Date.now() / 1000);
      if (ttl > 0) {
        await this.jwtBlacklist.blacklist(refreshToken, ttl);
      }

      return this.generateTokenPair(payload.sub, payload.email);
    } catch (error) {
      if (error instanceof UnauthorizedException) throw error;
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  async logout(accessToken: string, refreshToken?: string): Promise<void> {
    // Blacklist access token
    const decoded = this.jwtService.decode(accessToken) as Record<string, number> | null;
    if (decoded?.exp) {
      const ttl = decoded.exp - Math.floor(Date.now() / 1000);
      if (ttl > 0) {
        await this.jwtBlacklist.blacklist(accessToken, ttl);
      }
    }

    // Blacklist refresh token if provided
    if (refreshToken) {
      try {
        const decoded = this.jwtService.decode(refreshToken) as Record<string, number> | null;
        if (decoded?.exp) {
          const ttl = decoded.exp - Math.floor(Date.now() / 1000);
          if (ttl > 0) {
            await this.jwtBlacklist.blacklist(refreshToken, ttl);
          }
        }
      } catch {
        // Ignore invalid refresh token on logout
      }
    }
  }

  private generateTokenPair(userId: string, email: string): TokenPair {
    const payload = { sub: userId, email };

    const accessToken = this.jwtService.sign(payload, {
      secret: this.configService.get<string>('JWT_SECRET'),
      expiresIn: this.configService.get<number>('JWT_EXPIRES_IN_SECONDS', 900),
    });

    const refreshToken = this.jwtService.sign(payload, {
      secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
      expiresIn: this.configService.get<number>(
        'JWT_REFRESH_EXPIRES_IN_SECONDS',
        604800,
      ),
    });

    return { accessToken, refreshToken };
  }

  async verifySocialToken(
    provider: string,
    accessToken: string,
  ): Promise<SocialProfile> {
    let url: string;
    if (provider === 'google') {
      url = 'https://www.googleapis.com/oauth2/v2/userinfo';
    } else if (provider === 'facebook') {
      url = 'https://graph.facebook.com/me?fields=id,name,email,picture';
    } else {
      throw new BadRequestException(`Unsupported provider: ${provider}`);
    }

    const response = await fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (!response.ok) {
      throw new UnauthorizedException(
        `Invalid ${provider} token`,
      );
    }

    const data = (await response.json()) as Record<string, unknown>;

    if (provider === 'google') {
      return {
        id: data.id as string,
        email: data.email as string,
        name: data.name as string,
        picture: data.picture as string | undefined,
      };
    }

    // Facebook
    return {
      id: data.id as string,
      email: data.email as string,
      name: data.name as string,
      picture: ((data.picture as Record<string, unknown>)?.data as Record<string, unknown>)?.url as string | undefined,
    };
  }
}
