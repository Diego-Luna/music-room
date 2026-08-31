import { isAllowedCorsOrigin } from './cors-origin';

describe('isAllowedCorsOrigin', () => {
  it('allows missing Origin (native app, curl, health probes)', () => {
    expect(isAllowedCorsOrigin(undefined)).toBe(true);
  });

  it('allows production web hosts', () => {
    expect(isAllowedCorsOrigin('https://diego-luna.github.io')).toBe(true);
    expect(isAllowedCorsOrigin('https://musicroom.me')).toBe(true);
    expect(isAllowedCorsOrigin('https://www.musicroom.me')).toBe(true);
  });

  it('allows Flutter web debug on a random localhost port', () => {
    expect(isAllowedCorsOrigin('http://localhost:55325')).toBe(true);
    expect(isAllowedCorsOrigin('http://127.0.0.1:55325')).toBe(true);
    expect(isAllowedCorsOrigin('http://localhost:8080')).toBe(true);
  });

  it('allows APP_FRONTEND_URL when it is not localhost', () => {
    expect(
      isAllowedCorsOrigin('https://preview.example', 'https://preview.example'),
    ).toBe(true);
  });

  it('rejects unknown hosts', () => {
    expect(isAllowedCorsOrigin('https://evil.example')).toBe(false);
    expect(isAllowedCorsOrigin('http://192.168.1.10:8080')).toBe(false);
  });
});
