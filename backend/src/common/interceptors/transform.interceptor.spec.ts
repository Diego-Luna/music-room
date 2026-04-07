import { TransformInterceptor } from './transform.interceptor';
import { of, firstValueFrom } from 'rxjs';

describe('TransformInterceptor', () => {
  let interceptor: TransformInterceptor<unknown>;

  beforeEach(() => {
    interceptor = new TransformInterceptor();
  });

  it('should be defined', () => {
    expect(interceptor).toBeDefined();
  });

  it('should wrap response in { data, meta } envelope', async () => {
    const mockContext = {} as never;
    const mockHandler = {
      handle: () => of({ id: 1, name: 'test' }),
    };

    const result = await firstValueFrom(
      interceptor.intercept(mockContext, mockHandler as never),
    );

    expect(result).toHaveProperty('data');
    expect(result).toHaveProperty('meta');
    expect(result.data).toEqual({ id: 1, name: 'test' });
    expect(result.meta.timestamp).toBeDefined();
  });

  it('should handle null data', async () => {
    const mockContext = {} as never;
    const mockHandler = { handle: () => of(null) };

    const result = await firstValueFrom(
      interceptor.intercept(mockContext, mockHandler as never),
    );

    expect(result.data).toBeNull();
    expect(result.meta.timestamp).toBeDefined();
  });
});
