/**
 * CORS allowlist (V.6). Browsers send Origin; native mobile / curl do not.
 *
 * Flutter `flutter run -d chrome` binds a **random** debug port (e.g. :55325),
 * so any http(s)://localhost|127.0.0.1:<port> is accepted. Production web
 * stays an exact list (GitHub Pages, musicroom.me) plus APP_FRONTEND_URL.
 */
const STATIC_ORIGINS = new Set([
  'https://diego-luna.github.io',
  'https://musicroom.me',
  'https://www.musicroom.me',
]);

const LOCAL_ORIGIN =
  /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;

export function isAllowedCorsOrigin(
  origin: string | undefined,
  frontendUrl = process.env.APP_FRONTEND_URL,
): boolean {
  if (!origin) return true;
  if (STATIC_ORIGINS.has(origin)) return true;
  if (LOCAL_ORIGIN.test(origin)) return true;
  if (frontendUrl) {
    const trimmed = frontendUrl.replace(/\/$/, '');
    if (origin === trimmed) return true;
  }
  return false;
}
