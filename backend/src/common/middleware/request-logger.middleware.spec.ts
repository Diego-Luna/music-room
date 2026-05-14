import { RequestLoggerMiddleware } from './request-logger.middleware';
import { EventEmitter } from 'events';

describe('RequestLoggerMiddleware', () => {
  let middleware: RequestLoggerMiddleware;

  beforeEach(() => {
    middleware = new RequestLoggerMiddleware();
  });

  it('should be defined', () => {
    expect(middleware).toBeDefined();
  });

  it('should call next()', () => {
    const req = {
      method: 'GET',
      url: '/test',
      headers: {},
      socket: { remoteAddress: '127.0.0.1' },
    };
    const res = new EventEmitter();
    (res as Record<string, unknown>).statusCode = 200;
    const next = vi.fn();

    middleware.use(req as never, res as never, next);

    expect(next).toHaveBeenCalledOnce();
  });

  it('should log on response finish with platform headers', () => {
    const req = {
      method: 'POST',
      url: '/api/test',
      headers: {
        'x-platform': 'ios',
        'x-device': 'iPhone 15',
        'x-app-version': '1.0.0',
        'user-agent': 'MusicRoom/1.0',
      },
      socket: { remoteAddress: '10.0.0.1' },
    };
    const res = new EventEmitter();
    (res as Record<string, unknown>).statusCode = 201;
    const next = vi.fn();

    middleware.use(req as never, res as never, next);
    res.emit('finish');

    const logData = (res as Record<string, unknown>).__logData as Record<
      string,
      unknown
    >;
    expect(logData).toBeDefined();
    expect(logData.method).toBe('POST');
    expect(logData.path).toBe('/api/test');
    expect(logData.statusCode).toBe(201);
    expect(logData.platform).toBe('ios');
    expect(logData.device).toBe('iPhone 15');
    expect(logData.appVersion).toBe('1.0.0');
    expect(logData.duration).toBeGreaterThanOrEqual(0);
  });

  it('should log without platform headers', () => {
    const req = {
      method: 'GET',
      url: '/health',
      headers: {},
      socket: { remoteAddress: '127.0.0.1' },
    };
    const res = new EventEmitter();
    (res as Record<string, unknown>).statusCode = 200;
    const next = vi.fn();

    middleware.use(req as never, res as never, next);
    res.emit('finish');

    const logData = (res as Record<string, unknown>).__logData as Record<
      string,
      unknown
    >;
    expect(logData).toBeDefined();
    expect(logData.platform).toBeUndefined();
    expect(logData.device).toBeUndefined();
    expect(logData.appVersion).toBeUndefined();
  });

  it('should use x-forwarded-for for IP when present', () => {
    const req = {
      method: 'GET',
      url: '/',
      headers: { 'x-forwarded-for': '192.168.1.1' },
      socket: { remoteAddress: '127.0.0.1' },
    };
    const res = new EventEmitter();
    (res as Record<string, unknown>).statusCode = 200;
    const next = vi.fn();

    middleware.use(req as never, res as never, next);
    res.emit('finish');

    const logData = (res as Record<string, unknown>).__logData as Record<
      string,
      unknown
    >;
    expect(logData.ip).toBe('192.168.1.1');
  });

  it('should fall back to UNKNOWN/"/" when method and url are missing', () => {
    const req = {
      headers: {},
      socket: { remoteAddress: '127.0.0.1' },
    };
    const res = new EventEmitter();
    (res as Record<string, unknown>).statusCode = 500;
    const next = vi.fn();

    middleware.use(req as never, res as never, next);
    res.emit('finish');

    const logData = (res as Record<string, unknown>).__logData as Record<
      string,
      unknown
    >;
    expect(logData.method).toBe('UNKNOWN');
    expect(logData.path).toBe('/');
  });

  it('should take the first entry when a header is an array', () => {
    const req = {
      method: 'GET',
      url: '/multi',
      headers: {
        'x-forwarded-for': ['10.0.0.1', '10.0.0.2'],
        'x-platform': ['android', 'ios'],
      },
      socket: { remoteAddress: '127.0.0.1' },
    };
    const res = new EventEmitter();
    (res as Record<string, unknown>).statusCode = 200;
    const next = vi.fn();

    middleware.use(req as never, res as never, next);
    res.emit('finish');

    const logData = (res as Record<string, unknown>).__logData as Record<
      string,
      unknown
    >;
    expect(logData.ip).toBe('10.0.0.1');
    expect(logData.platform).toBe('android');
  });
});
