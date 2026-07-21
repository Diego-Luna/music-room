import {
  Controller,
  Post,
  Body,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Req,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiOkResponse,
  ApiCreatedResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { Throttle, SkipThrottle } from '@nestjs/throttler';
import { FastifyRequest } from 'fastify';
import {
  AuthService,
  TokenPair,
  JwtPayload,
  DeviceContext,
  SessionSummary,
} from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { SocialLoginDto } from './dto/social-login.dto';
import { LinkSocialDto } from './dto/link-social.dto';
import { VerifyEmailDto } from './dto/verify-email.dto';
import { ResendVerificationDto } from './dto/resend-verification.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { AuthTokensDto, SessionDto } from './dto/auth-response.dto';
import { MessageResponseDto } from '../common/dto/api-response.dto';
import { Public } from '../common/decorators/public.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@ApiTags('Auth')
@SkipThrottle({ default: true })
@Throttle({ auth: {} })
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  private deviceContext(req: FastifyRequest): DeviceContext {
    const header = (k: string): string | undefined => {
      const v = req.headers[k];
      return Array.isArray(v) ? v[0] : v;
    };
    // * Prefer x-device-id (stable UUID). Fall back to x-device for older
    //   clients that still sent the id in that header. The human-readable
    //   model (V.6 "Device") now lives in x-device and is for logs only.
    return {
      deviceId: header('x-device-id') ?? header('x-device'),
      userAgent: header('user-agent'),
      ip: header('x-forwarded-for') ?? req.ip,
    };
  }

  @Public()
  @Post('register')
  @ApiOperation({ summary: 'Register with email and password' })
  @ApiCreatedResponse({
    type: MessageResponseDto,
    description:
      'Account created and a verification email sent. No session is ' +
      'issued — the email must be verified before login.',
  })
  @ApiResponse({ status: 409, description: 'Email already registered' })
  async register(@Body() dto: RegisterDto): Promise<{ message: string }> {
    return this.authService.register(dto);
  }

  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Login with email and password' })
  @ApiOkResponse({
    type: AuthTokensDto,
    description: 'Login successful; returns the token pair',
  })
  @ApiResponse({ status: 401, description: 'Invalid credentials' })
  @ApiResponse({ status: 403, description: 'Email not verified' })
  async login(
    @Req() req: FastifyRequest,
    @Body() dto: LoginDto,
  ): Promise<TokenPair> {
    return this.authService.login(
      dto.email,
      dto.password,
      this.deviceContext(req),
    );
  }

  @Public()
  @Post('social')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Login or register via social provider' })
  @ApiOkResponse({
    type: AuthTokensDto,
    description: 'Social login successful; returns the token pair',
  })
  @ApiResponse({ status: 401, description: 'Invalid social token' })
  async socialLogin(
    @Req() req: FastifyRequest,
    @Body() dto: SocialLoginDto,
  ): Promise<TokenPair> {
    return this.authService.socialLogin(dto, this.deviceContext(req));
  }

  @Post('link-social')
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Link a social account to current user' })
  @ApiOkResponse({ type: MessageResponseDto })
  @ApiResponse({ status: 409, description: 'Social account already linked' })
  async linkSocial(
    @CurrentUser() user: JwtPayload,
    @Body() dto: LinkSocialDto,
  ): Promise<{ message: string }> {
    await this.authService.linkSocial(user.sub, dto);
    return { message: 'Social account linked successfully' };
  }

  @Public()
  @Post('verify-email')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Verify email address' })
  @ApiOkResponse({ type: MessageResponseDto })
  @ApiResponse({ status: 400, description: 'Invalid token' })
  async verifyEmail(@Body() dto: VerifyEmailDto): Promise<{ message: string }> {
    await this.authService.verifyEmail(dto.token);
    return { message: 'Email verified successfully' };
  }

  @Public()
  @Post('resend-verification')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Resend the email verification link' })
  @ApiOkResponse({
    type: MessageResponseDto,
    description: 'Always 200 (anti-enumeration)',
  })
  async resendVerification(
    @Body() dto: ResendVerificationDto,
  ): Promise<{ message: string }> {
    await this.authService.resendVerification(dto.email);
    return {
      message:
        'If an unverified account exists for that email, a new ' +
        'verification link has been sent.',
    };
  }

  @Public()
  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Request password reset' })
  @ApiOkResponse({
    type: MessageResponseDto,
    description: 'Reset email sent (if the account exists)',
  })
  async forgotPassword(
    @Body() dto: ForgotPasswordDto,
  ): Promise<{ message: string }> {
    await this.authService.forgotPassword(dto.email);
    return { message: 'If an account with that email exists, a reset link has been sent' };
  }

  @Public()
  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Reset password with token' })
  @ApiOkResponse({ type: MessageResponseDto })
  @ApiResponse({ status: 400, description: 'Invalid or expired token' })
  async resetPassword(
    @Body() dto: ResetPasswordDto,
  ): Promise<{ message: string }> {
    await this.authService.resetPassword(dto.token, dto.newPassword);
    return { message: 'Password reset successfully' };
  }

  @Public()
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Refresh access token' })
  @ApiOkResponse({
    type: AuthTokensDto,
    description: 'Returns a fresh token pair; the old refresh token is revoked',
  })
  @ApiResponse({ status: 401, description: 'Invalid refresh token' })
  async refresh(
    @Req() req: FastifyRequest,
    @Body() dto: RefreshTokenDto,
  ): Promise<TokenPair> {
    return this.authService.refresh(
      dto.refreshToken,
      this.deviceContext(req),
    );
  }

  @Get('sessions')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'List active sessions for the current user' })
  @ApiOkResponse({ type: SessionDto, isArray: true })
  async listSessions(
    @CurrentUser() user: JwtPayload,
  ): Promise<SessionSummary[]> {
    return this.authService.listSessions(user.sub);
  }

  @Delete('sessions/:id')
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Revoke a specific session' })
  @ApiOkResponse({ type: MessageResponseDto })
  @ApiResponse({ status: 404, description: 'Session not found' })
  async revokeSession(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ): Promise<{ message: string }> {
    await this.authService.revokeSession(user.sub, id);
    return { message: 'Session revoked' };
  }

  @Post('logout')
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Logout and blacklist tokens' })
  @ApiOkResponse({ type: MessageResponseDto })
  async logout(
    @Req() req: FastifyRequest,
    @Body() body: { refreshToken?: string },
  ): Promise<{ message: string }> {
    const authHeader = req.headers.authorization;
    const accessToken = authHeader?.replace('Bearer ', '') ?? '';
    await this.authService.logout(accessToken, body.refreshToken);
    return { message: 'Logged out successfully' };
  }
}
