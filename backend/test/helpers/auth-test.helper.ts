import { JwtService } from '@nestjs/jwt';

const JWT_SECRET = 'test-secret';
const JWT_REFRESH_SECRET = 'test-refresh-secret';

export function createTestJwtService(): JwtService {
  return new JwtService({ secret: JWT_SECRET });
}

export function generateTestTokens(userId: string, email: string) {
  const jwtService = createTestJwtService();
  const payload = { sub: userId, email };

  return {
    accessToken: jwtService.sign(payload, {
      secret: JWT_SECRET,
      expiresIn: 900,
    }),
    refreshToken: jwtService.sign(payload, {
      secret: JWT_REFRESH_SECRET,
      expiresIn: 604800,
    }),
  };
}

export const TEST_JWT_SECRET = JWT_SECRET;
export const TEST_JWT_REFRESH_SECRET = JWT_REFRESH_SECRET;
