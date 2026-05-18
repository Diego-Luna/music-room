import { ExecutionContext } from '@nestjs/common';
import { currentUserFactory } from './current-user.decorator';
import { JwtPayload } from '../../auth/auth.service';

describe('currentUserFactory', () => {
  const user: JwtPayload = { sub: 'user-1', email: 'user@example.com' };

  const makeCtx = (req: unknown): ExecutionContext =>
    ({
      switchToHttp: () => ({
        getRequest: () => req,
      }),
    }) as unknown as ExecutionContext;

  it('returns the full JwtPayload when no key is provided', () => {
    const ctx = makeCtx({ user });
    expect(currentUserFactory(undefined, ctx)).toEqual(user);
  });

  it('returns a specific field when a key is provided', () => {
    const ctx = makeCtx({ user });
    expect(currentUserFactory('sub', ctx)).toBe('user-1');
    expect(currentUserFactory('email', ctx)).toBe('user@example.com');
  });
});
