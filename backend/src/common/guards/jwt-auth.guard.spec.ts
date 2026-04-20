import { Reflector } from '@nestjs/core';
import { ExecutionContext } from '@nestjs/common';
import { JwtAuthGuard } from './jwt-auth.guard';

describe('JwtAuthGuard', () => {
  let guard: JwtAuthGuard;
  let reflector: Partial<Reflector>;

  beforeEach(() => {
    reflector = {
      getAllAndOverride: vi.fn(),
    };
    guard = new JwtAuthGuard(reflector as Reflector);
  });

  it('should be defined', () => {
    expect(guard).toBeDefined();
  });

  it('should return true for public routes', () => {
    (reflector.getAllAndOverride as ReturnType<typeof vi.fn>).mockReturnValue(true);

    const context = {
      getHandler: vi.fn(),
      getClass: vi.fn(),
    } as unknown as ExecutionContext;

    expect(guard.canActivate(context)).toBe(true);
  });

  it('should delegate to parent guard for non-public routes', () => {
    (reflector.getAllAndOverride as ReturnType<typeof vi.fn>).mockReturnValue(false);

    const context = {
      getHandler: vi.fn(),
      getClass: vi.fn(),
      switchToHttp: vi.fn().mockReturnValue({
        getRequest: vi.fn().mockReturnValue({ headers: {} }),
        getResponse: vi.fn().mockReturnValue({}),
      }),
      getType: vi.fn().mockReturnValue('http'),
      getArgs: vi.fn().mockReturnValue([]),
    } as unknown as ExecutionContext;

    // super.canActivate returns a promise that will reject without a valid JWT
    // We just verify it's called (not returning true directly like public routes)
    const result = guard.canActivate(context);
    expect(result).not.toBe(true);

    // Catch the expected rejection from passport (no token provided)
    if (result instanceof Promise) {
      result.catch(() => {});
    }
  });
});
