import http from 'k6/http';
import { check, sleep } from 'k6';
import { SharedArray } from 'k6/data';

export const options = {
  scenarios: {
    editors: {
      executor: 'constant-vus',
      vus: 20,
      duration: '45s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.02'],
    http_req_duration: ['p(95)<700'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

const setup = new SharedArray('setup', () => {
  return [{ ts: Date.now() }];
});

function auth() {
  const email = `playlist-${__VU}-${__ITER}-${Date.now()}@test.local`;
  http.post(
    `${BASE_URL}/auth/register`,
    JSON.stringify({
      email,
      password: 'LoadTest!123',
      displayName: `Editor ${__VU}`,
    }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  const login = http.post(
    `${BASE_URL}/auth/login`,
    JSON.stringify({ email, password: 'LoadTest!123' }),
    { headers: { 'Content-Type': 'application/json' } },
  );
  return login.json('accessToken');
}

function h(token) {
  return {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
}

export default function () {
  const token = auth();
  if (!token) return;

  const create = http.post(
    `${BASE_URL}/rooms`,
    JSON.stringify({
      name: `playlist-${__VU}-${setup[0].ts}`,
      kind: 'PLAYLIST',
      visibility: 'PUBLIC',
      allowMembersEdit: true,
    }),
    { headers: h(token) },
  );
  const roomId = create.json('id');
  if (!roomId) return;

  const trackIds = [];
  for (let i = 0; i < 8; i++) {
    const added = http.post(
      `${BASE_URL}/rooms/${roomId}/playlist`,
      JSON.stringify({
        providerId: `p-${__VU}-${i}-${Date.now()}`,
        title: `Song ${i}`,
        artist: `Artist ${__VU}`,
        durationMs: 200_000,
      }),
      { headers: h(token) },
    );
    check(added, { 'playlist add 201': (r) => r.status === 201 });
    const id = added.json('id');
    if (id) trackIds.push(id);
  }

  for (let i = 0; i < trackIds.length - 1; i++) {
    const move = http.patch(
      `${BASE_URL}/rooms/${roomId}/playlist/${trackIds[i]}/move`,
      JSON.stringify({ afterTrackId: trackIds[trackIds.length - 1] }),
      { headers: h(token) },
    );
    check(move, { 'move 200': (r) => r.status === 200 });
    sleep(0.02);
  }

  const list = http.get(`${BASE_URL}/rooms/${roomId}/playlist`, {
    headers: h(token),
  });
  check(list, { 'list 200': (r) => r.status === 200 });
}
