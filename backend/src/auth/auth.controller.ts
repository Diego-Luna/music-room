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
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
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
    return {
      deviceId: header('x-device'),
      userAgent: header('user-agent'),
      ip: header('x-forwarded-for') ?? req.ip,
    };
  }

  @Public()
  @Post('register')
  @ApiOperation({ summary: 'Register with email and password' })
  @ApiResponse({ status: 201, description: 'User registered successfully' })
  @ApiResponse({ status: 409, description: 'Email already registered' })
  async register(
    @Req() req: FastifyRequest,
    @Body() dto: RegisterDto,
  ): Promise<TokenPair> {
    return this.authService.register(dto, this.deviceContext(req));
  }

  @Public()
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Login with email and password' })
  @ApiResponse({ status: 200, description: 'Login successful' })
  @ApiResponse({ status: 401, description: 'Invalid credentials' })
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
  @ApiResponse({ status: 200, description: 'Social login successful' })
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
  @ApiResponse({ status: 200, description: 'Social account linked' })
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
  @ApiResponse({ status: 200, description: 'Email verified' })
  @ApiResponse({ status: 400, description: 'Invalid token' })
  async verifyEmail(@Body() dto: VerifyEmailDto): Promise<{ message: string }> {
    await this.authService.verifyEmail(dto.token);
    return { message: 'Email verified successfully' };
  }

  @Public()
  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Request password reset' })
  @ApiResponse({ status: 200, description: 'Reset email sent (if account exists)' })
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
  @ApiResponse({ status: 200, description: 'Password reset successful' })
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
  @ApiResponse({ status: 200, description: 'Tokens refreshed' })
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
  @ApiResponse({ status: 200, description: 'List of active sessions' })
  async listSessions(
    @CurrentUser() user: JwtPayload,
  ): Promise<SessionSummary[]> {
    return this.authService.listSessions(user.sub);
  }

  @Delete('sessions/:id')
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Revoke a specific session' })
  @ApiResponse({ status: 200, description: 'Session revoked' })
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
  @ApiResponse({ status: 200, description: 'Logged out' })
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
