import { envValidationSchema } from './env.validation';

describe('envValidationSchema', () => {
  const validBase = {
    DATABASE_URL: 'postgresql://user:pass@localhost:5432/db',
    JWT_SECRET: 'a'.repeat(32),
    JWT_REFRESH_SECRET: 'b'.repeat(32),
  };

  it('accepts a minimal valid env and applies defaults', () => {
    const { value, error } = envValidationSchema.validate(validBase);

    expect(error).toBeUndefined();
    expect(value.NODE_ENV).toBe('development');
    expect(value.PORT).toBe(3000);
    expect(value.REDIS_HOST).toBe('localhost');
    expect(value.REDIS_PORT).toBe(6379);
    expect(value.JWT_EXPIRES_IN_SECONDS).toBe(900);
    expect(value.JWT_REFRESH_EXPIRES_IN_SECONDS).toBe(604800);
    expect(value.THROTTLE_TTL).toBe(60000);
    expect(value.THROTTLE_LIMIT).toBe(100);
    expect(value.AUTH_THROTTLE_TTL).toBe(60000);
    expect(value.AUTH_THROTTLE_LIMIT).toBe(10);
    expect(value.APP_BASE_URL).toBe('http://localhost:3000');
    expect(value.APP_FRONTEND_URL).toBe('http://localhost:8080');
    expect(value.SMTP_HOST).toBe('localhost');
    expect(value.SMTP_PORT).toBe(1025);
    expect(value.SMTP_FROM).toContain('musicroom.local');
    expect(value.SMTP_SECURE).toBe(false);
  });

  it('rejects when DATABASE_URL is missing', () => {
    const { error } = envValidationSchema.validate({
      JWT_SECRET: 'a'.repeat(32),
      JWT_REFRESH_SECRET: 'b'.repeat(32),
    });

    expect(error).toBeDefined();
    expect(error?.message).toMatch(/DATABASE_URL/);
  });

  it('rejects when JWT_SECRET is missing', () => {
    const { error } = envValidationSchema.validate({
      DATABASE_URL: 'postgresql://localhost/db',
      JWT_REFRESH_SECRET: 'b'.repeat(32),
    });

    expect(error).toBeDefined();
    expect(error?.message).toMatch(/JWT_SECRET/);
  });

  it('rejects when JWT_REFRESH_SECRET is missing', () => {
    const { error } = envValidationSchema.validate({
      DATABASE_URL: 'postgresql://localhost/db',
      JWT_SECRET: 'a'.repeat(32),
    });

    expect(error).toBeDefined();
    expect(error?.message).toMatch(/JWT_REFRESH_SECRET/);
  });

  it('rejects an invalid NODE_ENV value', () => {
    const { error } = envValidationSchema.validate({
      ...validBase,
      NODE_ENV: 'staging',
    });

    expect(error).toBeDefined();
    expect(error?.message).toMatch(/NODE_ENV/);
  });

  it('rejects a non-URI APP_BASE_URL', () => {
    const { error } = envValidationSchema.validate({
      ...validBase,
      APP_BASE_URL: 'not-a-url',
    });

    expect(error).toBeDefined();
    expect(error?.message).toMatch(/APP_BASE_URL/);
  });

  it('allows empty social provider credentials', () => {
    const { error, value } = envValidationSchema.validate({
      ...validBase,
      GOOGLE_CLIENT_ID: '',
      GOOGLE_CLIENT_SECRET: '',
      FACEBOOK_APP_ID: '',
      FACEBOOK_APP_SECRET: '',
    });

    expect(error).toBeUndefined();
    expect(value.GOOGLE_CLIENT_ID).toBe('');
    expect(value.FACEBOOK_APP_ID).toBe('');
  });

  it('coerces numeric strings for ports and ttls', () => {
    const { error, value } = envValidationSchema.validate({
      ...validBase,
      PORT: '4000',
      REDIS_PORT: '6380',
      AUTH_THROTTLE_LIMIT: '5',
    });

    expect(error).toBeUndefined();
    expect(value.PORT).toBe(4000);
    expect(value.REDIS_PORT).toBe(6380);
    expect(value.AUTH_THROTTLE_LIMIT).toBe(5);
  });
});
