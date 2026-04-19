import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  BadRequestException,
  NotFoundException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import * as crypto from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { JwtBlacklistService } from './jwt-blacklist.service';
import { MailService } from '../mail/mail.service';
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

export interface DeviceContext {
  deviceId?: string;
  userAgent?: string;
  ip?: string;
}

export interface SessionSummary {
  id: string;
  deviceId: string | null;
  userAgent: string | null;
  ip: string | null;
  expiresAt: Date;
  createdAt: Date;
}

interface SocialProfile {
  id: string;
  email: string;
  name: string;
  picture?: string;
}

const BCRYPT_ROUNDS = 12;
const EMAIL_VERIFY_TTL_MS = 24 * 60 * 60 * 1000; // 24h
const PASSWORD_RESET_TTL_MS = 60 * 60 * 1000; // 1h

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly jwtBlacklist: JwtBlacklistService,
    private readonly mail: MailService,
  ) {}

  // ── Registration ───────────────────────────────────────────────
  async register(dto: RegisterDto, ctx?: DeviceContext): Promise<TokenPair> {
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (existing) {
      throw new ConflictException('Email already registered');
    }

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_ROUNDS);

    const user = await this.prisma.user.create({
      data: {
        email: dto.email,
        passwordHash,
        displayName: dto.displayName,
      },
    });

    await this.issueEmailVerification(user.id, user.email);

    this.logger.log(`User registered: ${user.id}`);
    return this.issueTokenPair(user.id, user.email, ctx);
  }

  private async issueEmailVerification(userId: string, email: string) {
    const rawToken = this.generateRawToken();
    await this.prisma.emailVerification.create({
      data: {
        userId,
        tokenHash: this.hashToken(rawToken),
        expiresAt: new Date(Date.now() + EMAIL_VERIFY_TTL_MS),
      },
    });
    await this.mail.sendVerificationEmail(email, rawToken);
  }

  // ── Login ──────────────────────────────────────────────────────
  async validateUser(
    email: string,
    password: string,
  ): Promise<{ id: string; email: string }> {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user || !user.passwordHash) {
      throw new UnauthorizedException('Invalid credentials');
    }
    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('Invalid credentials');
    }
    return { id: user.id, email: user.email };
  }

  async login(
    email: string,
    password: string,
    ctx?: DeviceContext,
  ): Promise<TokenPair> {
    const user = await this.validateUser(email, password);
    return this.issueTokenPair(user.id, user.email, ctx);
  }

  // ── Social ─────────────────────────────────────────────────────
  async socialLogin(
    dto: SocialLoginDto,
    ctx?: DeviceContext,
  ): Promise<TokenPair> {
    const profile = await this.verifySocialToken(dto.provider, dto.accessToken);

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
      return this.issueTokenPair(
        existingSocial.user.id,
        existingSocial.user.email,
        ctx,
      );
    }

    const existingUser = await this.prisma.user.findUnique({
      where: { email: profile.email },
    });
    if (existingUser) {
      await this.prisma.socialAccount.create({
        data: {
          provider: dto.provider,
          providerId: profile.id,
          userId: existingUser.id,
        },
      });
      return this.issueTokenPair(existingUser.id, existingUser.email, ctx);
    }

    const user = await this.prisma.user.create({
      data: {
        email: profile.email,
        displayName: profile.name,
        avatarUrl: profile.picture,
        emailVerified: true,
        socialAccounts: {
          create: { provider: dto.provider, providerId: profile.id },
        },
      },
    });
    this.logger.log(`User created via ${dto.provider}: ${user.id}`);
    return this.issueTokenPair(user.id, user.email, ctx);
  }

  async linkSocial(userId: string, dto: LinkSocialDto): Promise<void> {
    const profile = await this.verifySocialToken(dto.provider, dto.accessToken);

    const alreadyLinked = await this.prisma.socialAccount.findUnique({
      where: {
        provider_providerId: {
          provider: dto.provider,
          providerId: profile.id,
        },
      },
    });
    if (alreadyLinked) {
      throw new ConflictException(
        'This social account is already linked to another user',
      );
    }

    const sameProviderForUser = await this.prisma.socialAccount.findUnique({
      where: {
        provider_userId: { provider: dto.provider, userId },
      },
    });
    if (sameProviderForUser) {
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

  // ── Email verification ─────────────────────────────────────────
  async verifyEmail(rawToken: string): Promise<void> {
    const tokenHash = this.hashToken(rawToken);
    const record = await this.prisma.emailVerification.findFirst({
      where: { tokenHash },
    });

    if (!record) {
      throw new BadRequestException('Invalid verification token');
    }
    if (record.consumedAt) {
      throw new BadRequestException('Verification token already used');
    }
    if (record.expiresAt.getTime() < Date.now()) {
      throw new BadRequestException('Verification token expired');
    }

    await this.prisma.emailVerification.update({
      where: { id: record.id },
      data: { consumedAt: new Date() },
    });
    await this.prisma.user.update({
      where: { id: record.userId },
      data: { emailVerified: true },
    });
  }

  // ── Forgot / reset password ────────────────────────────────────
  async forgotPassword(email: string): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) return; // anti-enumeration

    const rawToken = this.generateRawToken();
    await this.prisma.passwordReset.create({
      data: {
        userId: user.id,
        tokenHash: this.hashToken(rawToken),
        expiresAt: new Date(Date.now() + PASSWORD_RESET_TTL_MS),
      },
    });
    await this.mail.sendPasswordResetEmail(user.email, rawToken);
    this.logger.log(`Password reset issued for user ${user.id}`);
  }

  async resetPassword(rawToken: string, newPassword: string): Promise<void> {
    const tokenHash = this.hashToken(rawToken);
    const record = await this.prisma.passwordReset.findFirst({
      where: { tokenHash },
    });

    if (!record) {
      throw new BadRequestException('Invalid reset token');
    }
    if (record.consumedAt) {
      throw new BadRequestException('Reset token already used');
    }
    if (record.expiresAt.getTime() < Date.now()) {
      throw new BadRequestException('Reset token expired');
    }

    const passwordHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);

    await this.prisma.user.update({
      where: { id: record.userId },
      data: { passwordHash },
    });
    await this.prisma.passwordReset.update({
      where: { id: record.id },
      data: { consumedAt: new Date() },
    });
    // Revoke all active refresh tokens — password change forces re-login
    await this.prisma.refreshToken.updateMany({
      where: { userId: record.userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  // ── Refresh / logout ───────────────────────────────────────────
  async refresh(refreshToken: string, ctx?: DeviceContext): Promise<TokenPair> {
    let payload: JwtPayload;
    try {
      payload = this.jwtService.verify<JwtPayload>(refreshToken, {
        secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const tokenHash = this.hashToken(refreshToken);
    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
    });

    if (!stored) {
      throw new UnauthorizedException('Refresh token not recognized');
    }

    if (stored.revokedAt) {
      // Revoked token reuse → strong theft signal: revoke whole user family
      await this.prisma.refreshToken.updateMany({
        where: { userId: stored.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      this.logger.warn(
        `Refresh-token reuse detected for user ${stored.userId} — all sessions revoked`,
      );
      throw new UnauthorizedException('Refresh token revoked');
    }

    if (stored.expiresAt.getTime() < Date.now()) {
      throw new UnauthorizedException('Refresh token expired');
    }

    // Issue a new pair, then mark the old one revoked + replaced
    const newPair = await this.issueTokenPair(payload.sub, payload.email, ctx);
    await this.prisma.refreshToken.update({
      where: { id: stored.id },
      data: {
        revokedAt: new Date(),
        replacedBy: this.hashToken(newPair.refreshToken),
      },
    });
    return newPair;
  }

  async logout(accessToken: string, refreshToken?: string): Promise<void> {
    // Blacklist short-lived access JWT
    const decodedAccess = this.jwtService.decode(accessToken) as Record<
      string,
      number
    > | null;
    if (decodedAccess?.exp) {
      const ttl = decodedAccess.exp - Math.floor(Date.now() / 1000);
      if (ttl > 0) {
        await this.jwtBlacklist.blacklist(accessToken, ttl);
      }
    }

    // Revoke refresh row (DB is source of truth)
    if (refreshToken) {
      const tokenHash = this.hashToken(refreshToken);
      const stored = await this.prisma.refreshToken.findUnique({
        where: { tokenHash },
      });
      if (stored && !stored.revokedAt) {
        await this.prisma.refreshToken.update({
          where: { id: stored.id },
          data: { revokedAt: new Date() },
        });
      }
    }
  }

  // ── Sessions ───────────────────────────────────────────────────
  async listSessions(userId: string): Promise<SessionSummary[]> {
    const rows = await this.prisma.refreshToken.findMany({
      where: {
        userId,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        deviceId: true,
        userAgent: true,
        ip: true,
        expiresAt: true,
        createdAt: true,
      },
    });
    return rows as SessionSummary[];
  }

  async revokeSession(userId: string, sessionId: string): Promise<void> {
    const session = await this.prisma.refreshToken.findUnique({
      where: { id: sessionId },
    });
    if (!session || session.userId !== userId) {
      throw new NotFoundException('Session not found');
    }
    if (session.revokedAt) return;
    await this.prisma.refreshToken.update({
      where: { id: sessionId },
      data: { revokedAt: new Date() },
    });
  }

  // ── Helpers ────────────────────────────────────────────────────
  private async issueTokenPair(
    userId: string,
    email: string,
    ctx?: DeviceContext,
  ): Promise<TokenPair> {
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

    const ttlSeconds = this.configService.get<number>(
      'JWT_REFRESH_EXPIRES_IN_SECONDS',
      604800,
    );

    await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash: this.hashToken(refreshToken),
        deviceId: ctx?.deviceId ?? null,
        userAgent: ctx?.userAgent ?? null,
        ip: ctx?.ip ?? null,
        expiresAt: new Date(Date.now() + ttlSeconds * 1000),
      },
    });

    return { accessToken, refreshToken };
  }

  private generateRawToken(): string {
    return crypto.randomBytes(32).toString('hex');
  }

  private hashToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  async verifySocialToken(
    provider: string,
    accessToken: string,
  ): Promise<SocialProfile> {
    let url: string;
    if (provider === 'google') {
      await this.verifyGoogleAudience(accessToken);
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
      throw new UnauthorizedException(`Invalid ${provider} token`);
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
      picture: ((data.picture as Record<string, unknown>)?.data as Record<
        string,
        unknown
      >)?.url as string | undefined,
    };
  }

  private async verifyGoogleAudience(accessToken: string): Promise<void> {
    const expectedAud = this.configService.get<string>('GOOGLE_CLIENT_ID');
    if (!expectedAud) return; // dev mode without real Google app — skip

    const response = await fetch(
      `https://oauth2.googleapis.com/tokeninfo?access_token=${encodeURIComponent(accessToken)}`,
    );
    if (!response.ok) {
      throw new UnauthorizedException('Invalid google token');
    }
    const info = (await response.json()) as Record<string, unknown>;
    if (info.aud !== expectedAud) {
      throw new UnauthorizedException('Google token audience mismatch');
    }
  }
}
