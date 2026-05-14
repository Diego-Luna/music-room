import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    voters: {
      executor: 'ramping-vus',
      startVUs: 5,
      stages: [
        { target: 50, duration: '30s' },
        { target: 50, duration: '60s' },
        { target: 0, duration: '10s' },
      ],
      gracefulRampDown: '10s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<600'],
    'checks{tag:vote}': ['rate>0.98'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

function registerAndLogin() {
  const tag = `${__VU}-${__ITER}-${Date.now()}`;
  const email = `voter-${tag}@test.local`;
  const body = JSON.stringify({
    email,
    password: 'LoadTest!123',
    displayName: `Voter ${tag}`,
  });
  http.post(`${BASE_URL}/auth/register`, body, {
    headers: { 'Content-Type': 'application/json' },
  });
  const login = http.post(
    `${BASE_URL}/auth/login`,
    JSON.stringify({ email, password: 'LoadTest!123' }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  return login.json('accessToken');
}

function createVoteRoom(token) {
  const res = http.post(
    `${BASE_URL}/rooms`,
    JSON.stringify({
      name: `load-vote-${__VU}`,
      kind: 'VOTE',
      visibility: 'PUBLIC',
    }),
    {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    },
  );
  return res.json('id');
}

function addTrack(token, roomId, i) {
  return http.post(
    `${BASE_URL}/rooms/${roomId}/tracks`,
    JSON.stringify({
      providerId: `load-${__VU}-${i}-${Date.now()}`,
      title: `Load Song ${i}`,
      artist: `Load Artist ${__VU}`,
      durationMs: 120_000 + i * 1000,
    }),
    {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    },
  );
}

export default function () {
  const token = registerAndLogin();
  if (!token) return;
  const roomId = createVoteRoom(token);
  if (!roomId) return;

  for (let i = 0; i < 10; i++) {
    const added = addTrack(token, roomId, i);
    check(added, { 'add 201': (r) => r.status === 201 }, { tag: 'add' });
    const trackId = added.json('id');
    if (!trackId) continue;

    const v1 = http.post(
      `${BASE_URL}/rooms/${roomId}/tracks/${trackId}/vote`,
      JSON.stringify({ value: 1 }),
      {
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      },
    );
    check(v1, { 'vote 200': (r) => r.status === 200 }, { tag: 'vote' });

    const v2 = http.post(
      `${BASE_URL}/rooms/${roomId}/tracks/${trackId}/vote`,
      JSON.stringify({ value: -1 }),
      {
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      },
    );
    check(v2, { 'flip 200': (r) => r.status === 200 }, { tag: 'vote' });

    sleep(0.05);
  }

  const list = http.get(`${BASE_URL}/rooms/${roomId}/tracks`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  check(list, { 'list 200': (r) => r.status === 200 });
}
