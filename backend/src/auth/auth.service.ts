import {
  Injectable,
  ConflictException,
  UnauthorizedException,
  BadRequestException,
  ForbiddenException,
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
  jti?: string;
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

// Production default = 12 (cost factor recommended for 2024+). The
// override env var exists for load tests only: 12 rounds caps register
// throughput at ~5/s/core, which limits the *measure* of everything else.
// Setting BCRYPT_ROUNDS_OVERRIDE=4 in measure.sh removes that ceiling.
// The variable is never set in .env; in prod it falls back to 12.
const BCRYPT_ROUNDS = parseInt(
  process.env.BCRYPT_ROUNDS_OVERRIDE ?? '12',
  10,
);
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
  ) { }

  // ── Registration ───────────────────────────────────────────────
  async register(dto: RegisterDto): Promise<{ message: string }> {
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

    this.logger.log(`User registered (pending verification): ${user.id}`);
    // No session is issued: the subject demands a mail validation — the
    // account cannot be used until the email is verified (see login()).
    return {
      message:
        'Account created. Check your email to verify it before logging in.',
    };
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
  ): Promise<{ id: string; email: string; emailVerified: boolean }> {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user || !user.passwordHash) {
      throw new UnauthorizedException('Invalid credentials');
    }
    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('Invalid credentials');
    }
    return {
      id: user.id,
      email: user.email,
      emailVerified: user.emailVerified,
    };
  }

  async login(
    email: string,
    password: string,
    ctx?: DeviceContext,
  ): Promise<TokenPair> {
    const user = await this.validateUser(email, password);
    // V.1: the application must demand a mail validation — an email/password
    // account cannot log in until its address is verified. The override
    // (AUTH_ALLOW_UNVERIFIED=true) exists for load tests only; in prod the
    // variable is unset and the gate is enforced normally.
    if (!user.emailVerified) {
      const allowUnverified =
        this.configService.get<string>('AUTH_ALLOW_UNVERIFIED') === 'true';
      if (!allowUnverified) {
        throw new ForbiddenException(
          'Email not verified. Check your inbox to verify your account.',
        );
      }
    }
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

  // Re-sends the verification email. Anti-enumeration: always succeeds
  // silently, whether or not the address maps to an unverified account.
  async resendVerification(email: string): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (user && !user.emailVerified) {
      await this.issueEmailVerification(user.id, user.email);
    }
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
    const payload = { sub: userId, email, jti: crypto.randomUUID() };

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
      if (accessToken.startsWith('eyJ')) {
        return this.verifyFacebookJwt(accessToken);
      }
      await this.verifyFacebookApp(accessToken);
      url = 'https://graph.facebook.com/me?fields=id,name,email,picture';
    } else {
      throw new BadRequestException(`Unsupported provider: ${provider}`);
    }

    const response = await fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (!response.ok) {
      const errorBody = typeof response.text === 'function' ? await response.text().catch(() => 'unknown') : 'unknown';
      this.logger.error(`Social token verification failed for ${provider}. URL: ${url}, Status: ${response.status}, Response: ${errorBody}`);
      throw new UnauthorizedException(`Invalid ${provider} token`);
    }

    const data = (await response.json()) as Record<string, unknown>;

    const profile: SocialProfile =
      provider === 'google'
        ? {
          id: data.id as string,
          email: data.email as string,
          name: data.name as string,
          picture: data.picture as string | undefined,
        }
        : {
          id: data.id as string,
          email: data.email as string,
          name: data.name as string,
          picture: (
            (data.picture as Record<string, unknown>)?.data as
            | Record<string, unknown>
            | undefined
          )?.url as string | undefined,
        };

    // A provider may withhold the email (a Facebook account without one, or
    // the email permission denied). We cannot create an account without it —
    // email is the unique account key.
    if (!profile.id || !profile.email) {
      this.logger.error(`Social provider ${provider} did not return ID or email. Data: ${JSON.stringify(data)}`);
      throw new BadRequestException(
        `The ${provider} account did not provide an email address`,
      );
    }
    return profile;
  }

  private async verifyGoogleAudience(accessToken: string): Promise<void> {
    const expectedAud = this.configService.get<string>('GOOGLE_CLIENT_ID');
    if (!expectedAud) return; // dev mode without real Google app — skip

    const response = await fetch(
      `https://oauth2.googleapis.com/tokeninfo?access_token=${encodeURIComponent(accessToken)}`,
    );
    if (!response.ok) {
      const errorBody = typeof response.text === 'function' ? await response.text().catch(() => 'unknown') : 'unknown';
      this.logger.error(`Google tokeninfo verification failed. Status: ${response.status}, Response: ${errorBody}`);
      throw new UnauthorizedException('Invalid google token');
    }
    const info = (await response.json()) as Record<string, unknown>;
    if (info.aud !== expectedAud) {
      this.logger.error(`Google token audience mismatch. Expected: ${expectedAud}, Got: ${info.aud}`);
      throw new UnauthorizedException('Google token audience mismatch');
    }
  }

  // Mirror of verifyGoogleAudience for Facebook: confirms the user token was
  // issued for OUR Facebook app, not another one — a token from any other
  // Facebook app would otherwise pass /me and let an attacker impersonate.
  private async verifyFacebookApp(accessToken: string): Promise<void> {
    const appId = this.configService.get<string>('FACEBOOK_APP_ID');
    const appSecret = this.configService.get<string>('FACEBOOK_APP_SECRET');
    if (!appId || !appSecret) return; // dev mode without a real Facebook app

    this.logger.debug(`verifyFacebookApp token prefix: ${accessToken.substring(0, 15)}... (length: ${accessToken.length})`);
    const appToken = `${appId}|${appSecret}`;
    const url = `https://graph.facebook.com/debug_token?input_token=${encodeURIComponent(accessToken)}&access_token=${encodeURIComponent(appToken)}`;
    const response = await fetch(url);
    if (!response.ok) {
      const errorBody = typeof response.text === 'function' ? await response.text().catch(() => 'unknown') : 'unknown';
      this.logger.error(`Facebook debug_token API call failed. Status: ${response.status}, Response: ${errorBody}`);
      throw new UnauthorizedException('Invalid facebook token');
    }
    const body = (await response.json()) as {
      data?: { app_id?: string; is_valid?: boolean; error?: any };
    };
    if (body.data?.is_valid !== true || body.data?.app_id !== appId) {
      this.logger.error(`Facebook token validation failed. isValid: ${body.data?.is_valid}, app_id: ${body.data?.app_id}, expected: ${appId}, Error detail: ${JSON.stringify(body.data?.error)}`);
      throw new UnauthorizedException(
        'Facebook token was not issued for this app',
      );
    }
  }

  private async verifyFacebookJwt(token: string): Promise<SocialProfile> {
    const appId = this.configService.get<string>('FACEBOOK_APP_ID');
    if (!appId) {
      throw new UnauthorizedException('Facebook App ID not configured');
    }

    const parts = token.split('.');
    if (parts.length !== 3) {
      throw new UnauthorizedException('Invalid JWT format');
    }

    const [headerB64, payloadB64, signatureB64] = parts;

    let header: { kid?: string; alg?: string };
    try {
      header = JSON.parse(Buffer.from(headerB64, 'base64url').toString('utf8'));
    } catch {
      throw new UnauthorizedException('Failed to parse JWT header');
    }

    if (!header.kid) {
      throw new UnauthorizedException('JWT header is missing key ID (kid)');
    }

    let payload: {
      sub?: string;
      email?: string;
      name?: string;
      picture?: string | { data?: { url?: string } };
      aud?: string;
      iss?: string;
      exp?: number;
    };
    try {
      payload = JSON.parse(Buffer.from(payloadB64, 'base64url').toString('utf8'));
    } catch {
      throw new UnauthorizedException('Failed to parse JWT payload');
    }

    if (payload.aud !== appId) {
      this.logger.error(`Facebook JWT audience mismatch. Expected: ${appId}, Got: ${payload.aud}`);
      throw new UnauthorizedException('Facebook JWT audience mismatch');
    }

    const iss = payload.iss;
    const allowedIssuers = ['https://www.facebook.com', 'https://limited.facebook.com', 'www.facebook.com', 'limited.facebook.com'];
    if (!iss || !allowedIssuers.some(allowed => iss.includes(allowed))) {
      this.logger.error(`Facebook JWT issuer mismatch. Got: ${iss}`);
      throw new UnauthorizedException('Facebook JWT issuer mismatch');
    }

    if (payload.exp && payload.exp * 1000 < Date.now()) {
      throw new UnauthorizedException('Facebook JWT expired');
    }

    try {
      const keysResponse = await fetch('https://limited.facebook.com/.well-known/oauth/openid/keys/');
      if (!keysResponse.ok) {
        throw new Error(`Failed to fetch Facebook keys: ${keysResponse.statusText}`);
      }
      const keys = (await keysResponse.json()) as Record<string, string>;
      const publicKey = keys[header.kid];
      if (!publicKey) {
        throw new UnauthorizedException(`Facebook public key for kid "${header.kid}" not found`);
      }

      const verifier = crypto.createVerify('SHA256');
      verifier.update(`${headerB64}.${payloadB64}`);
      const isSignatureValid = verifier.verify(publicKey, signatureB64, 'base64url');

      if (!isSignatureValid) {
        throw new UnauthorizedException('Invalid Facebook JWT signature');
      }
    } catch (err) {
      const errMsg = err instanceof Error ? err.message : String(err);
      this.logger.error(`Facebook JWT signature verification failed: ${errMsg}`);
      throw new UnauthorizedException('Invalid Facebook token signature');
    }

    let pictureUrl: string | undefined;
    if (typeof payload.picture === 'string') {
      pictureUrl = payload.picture;
    } else if (payload.picture && typeof payload.picture === 'object') {
      pictureUrl = payload.picture.data?.url;
    }

    return {
      id: payload.sub ?? '',
      email: payload.email ?? '',
      name: payload.name ?? '',
      picture: pictureUrl,
    };
  }
}
