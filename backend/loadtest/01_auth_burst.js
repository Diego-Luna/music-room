import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    burst: {
      executor: 'ramping-arrival-rate',
      startRate: 5,
      timeUnit: '1s',
      preAllocatedVUs: 50,
      maxVUs: 100,
      stages: [
        { target: 20, duration: '15s' },
        { target: 50, duration: '30s' },
        { target: 0, duration: '10s' },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<500'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export default function () {
  const tag = `${__VU}-${__ITER}-${Date.now()}`;
  const email = `load-${tag}@test.local`;

  const register = http.post(
    `${BASE_URL}/auth/register`,
    JSON.stringify({
      email,
      password: 'LoadTest!123',
      displayName: `Load ${tag}`,
    }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  check(register, { 'register 201': (r) => r.status === 201 });

  const login = http.post(
    `${BASE_URL}/auth/login`,
    JSON.stringify({ email, password: 'LoadTest!123' }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  check(login, {
    'login 200': (r) => r.status === 200,
    'access token present': (r) => !!r.json('accessToken'),
  });

  sleep(0.2);
}
