import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import { MailService } from './mail.service';

vi.mock('nodemailer', () => ({
  createTransport: vi.fn(),
}));

describe('MailService', () => {
  let service: MailService;
  let sendMail: ReturnType<typeof vi.fn>;
  let configService: Partial<ConfigService>;

  beforeEach(async () => {
    sendMail = vi.fn().mockResolvedValue({ messageId: 'msg-1' });
    (nodemailer.createTransport as ReturnType<typeof vi.fn>).mockReturnValue({
      sendMail,
      verify: vi.fn().mockResolvedValue(true),
    });

    configService = {
      get: vi.fn((key: string, defaultValue?: unknown) => {
        const map: Record<string, unknown> = {
          SMTP_HOST: 'localhost',
          SMTP_PORT: 1025,
          SMTP_USER: '',
          SMTP_PASSWORD: '',
          SMTP_SECURE: false,
          SMTP_FROM: 'Music Room <no-reply@musicroom.local>',
          APP_FRONTEND_URL: 'http://localhost:8080',
        };
        return map[key] ?? defaultValue;
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MailService,
        { provide: ConfigService, useValue: configService },
      ],
    }).compile();

    service = module.get<MailService>(MailService);
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should create transporter from config on construction', () => {
    expect(nodemailer.createTransport).toHaveBeenCalledWith(
      expect.objectContaining({
        host: 'localhost',
        port: 1025,
        secure: false,
      }),
    );
  });

  describe('sendVerificationEmail', () => {
    it('should send verification email with proper subject and link', async () => {
      await service.sendVerificationEmail('user@example.com', 'verify-token-abc');

      expect(sendMail).toHaveBeenCalledTimes(1);
      const call = sendMail.mock.calls[0][0];
      expect(call.to).toBe('user@example.com');
      expect(call.from).toBe('Music Room <no-reply@musicroom.local>');
      expect(call.subject).toMatch(/verify/i);
      expect(call.html).toContain('verify-token-abc');
      expect(call.html).toContain('http://localhost:8080');
    });
  });

  describe('sendPasswordResetEmail', () => {
    it('should send reset email with proper subject and link', async () => {
      await service.sendPasswordResetEmail('user@example.com', 'reset-token-xyz');

      expect(sendMail).toHaveBeenCalledTimes(1);
      const call = sendMail.mock.calls[0][0];
      expect(call.to).toBe('user@example.com');
      expect(call.subject).toMatch(/reset|password/i);
      expect(call.html).toContain('reset-token-xyz');
    });
  });

  describe('isHealthy', () => {
    it('should return true when transporter verifies', async () => {
      const ok = await service.isHealthy();
      expect(ok).toBe(true);
    });

    it('should return false when transporter fails', async () => {
      const verify = vi.fn().mockRejectedValue(new Error('boom'));
      (nodemailer.createTransport as ReturnType<typeof vi.fn>).mockReturnValue({
        sendMail,
        verify,
      });

      const module: TestingModule = await Test.createTestingModule({
        providers: [
          MailService,
          { provide: ConfigService, useValue: configService },
        ],
      }).compile();
      const svc = module.get<MailService>(MailService);

      const ok = await svc.isHealthy();
      expect(ok).toBe(false);
    });
  });

  describe('error handling', () => {
    it('should throw if sendMail rejects', async () => {
      sendMail.mockRejectedValueOnce(new Error('SMTP down'));
      await expect(
        service.sendVerificationEmail('user@example.com', 'token'),
      ).rejects.toThrow('SMTP down');
    });
  });
});
