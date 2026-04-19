import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private readonly transporter: nodemailer.Transporter;
  private readonly from: string;
  private readonly frontendUrl: string;

  constructor(private readonly configService: ConfigService) {
    const host = this.configService.get<string>('SMTP_HOST', 'localhost');
    const port = this.configService.get<number>('SMTP_PORT', 1025);
    const user = this.configService.get<string>('SMTP_USER', '');
    const pass = this.configService.get<string>('SMTP_PASSWORD', '');
    const secure = this.configService.get<boolean>('SMTP_SECURE', false);

    this.from = this.configService.get<string>(
      'SMTP_FROM',
      'Music Room <no-reply@musicroom.local>',
    );
    this.frontendUrl = this.configService.get<string>(
      'APP_FRONTEND_URL',
      'http://localhost:8080',
    );

    this.transporter = nodemailer.createTransport({
      host,
      port,
      secure,
      auth: user || pass ? { user, pass } : undefined,
    });
  }

  async sendVerificationEmail(to: string, token: string): Promise<void> {
    const link = `${this.frontendUrl}/auth/verify-email?token=${encodeURIComponent(token)}`;
    await this.transporter.sendMail({
      from: this.from,
      to,
      subject: 'Verify your Music Room email',
      html: `
        <p>Welcome to Music Room.</p>
        <p>Click the link below to verify your email address:</p>
        <p><a href="${link}">${link}</a></p>
        <p>If you did not create an account, ignore this message.</p>
      `,
      text: `Verify your email: ${link}`,
    });
    this.logger.log(`Verification email queued for ${to}`);
  }

  async sendPasswordResetEmail(to: string, token: string): Promise<void> {
    const link = `${this.frontendUrl}/auth/reset-password?token=${encodeURIComponent(token)}`;
    await this.transporter.sendMail({
      from: this.from,
      to,
      subject: 'Reset your Music Room password',
      html: `
        <p>You requested a password reset.</p>
        <p>Click the link below to choose a new password (valid 1 hour):</p>
        <p><a href="${link}">${link}</a></p>
        <p>If you did not request this, ignore this message.</p>
      `,
      text: `Reset your password: ${link}`,
    });
    this.logger.log(`Password reset email queued for ${to}`);
  }

  async isHealthy(): Promise<boolean> {
    try {
      await this.transporter.verify();
      return true;
    } catch {
      return false;
    }
  }
}
