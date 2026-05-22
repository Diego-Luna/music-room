import http from 'k6/http';
import { check, sleep } from 'k6';

// V.2.2 Music Control Delegation — exercises the grant/list/revoke hot
// path. Each VU registers an owner + a friend, befriends them (delegation
// is friendship-gated), then repeatedly delegates and revokes devices.
// Playback endpoints are intentionally out of scope here: they proxy to
// the real Spotify API, which load-test users have no token for.
export const options = {
  scenarios: {
    delegators: {
      executor: 'ramping-vus',
      startVUs: 5,
      stages: [
        { target: 40, duration: '30s' },
        { target: 40, duration: '60s' },
        { target: 0, duration: '10s' },
      ],
      gracefulRampDown: '10s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<800'],
    'checks{tag:delegation}': ['rate>0.98'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

function jsonHeaders(token) {
  return {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
}

function authHeaders(token) {
  return { Authorization: `Bearer ${token}` };
}

function registerAndLogin(role) {
  const tag = `${__VU}-${__ITER}-${Date.now()}-${role}`;
  const email = `deleg-${tag}@test.local`;
  http.post(
    `${BASE_URL}/auth/register`,
    JSON.stringify({
      email,
      password: 'LoadTest!123',
      displayName: `Deleg ${tag}`,
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

function getUserId(token) {
  const me = http.get(`${BASE_URL}/users/me`, { headers: authHeaders(token) });
  return me.json('id');
}

// Delegation is friendship-gated: the pair must be ACCEPTED friends first.
function befriend(ownerToken, friendId, friendToken) {
  const req = http.post(
    `${BASE_URL}/users/me/friends/request`,
    JSON.stringify({ userId: friendId }),
    { headers: jsonHeaders(ownerToken) },
  );
  const friendshipId = req.json('id');
  if (!friendshipId) return false;
  const accept = http.post(
    `${BASE_URL}/users/me/friends/${friendshipId}/accept`,
    null,
    { headers: authHeaders(friendToken) },
  );
  return accept.status === 200;
}

export default function () {
  const ownerToken = registerAndLogin('owner');
  const friendToken = registerAndLogin('friend');
  if (!ownerToken || !friendToken) return;

  const friendId = getUserId(friendToken);
  if (!friendId) return;

  if (!befriend(ownerToken, friendId, friendToken)) return;

  for (let i = 0; i < 8; i++) {
    const deviceId = `device-${__VU}-${i}`;

    const grant = http.put(
      `${BASE_URL}/users/me/devices/${deviceId}/delegate`,
      JSON.stringify({ delegateUserId: friendId }),
      { headers: jsonHeaders(ownerToken) },
    );
    check(grant, { 'grant 200': (r) => r.status === 200 }, {
      tag: 'delegation',
    });

    const mine = http.get(`${BASE_URL}/users/me/delegations`, {
      headers: authHeaders(ownerToken),
    });
    check(mine, { 'list mine 200': (r) => r.status === 200 }, {
      tag: 'delegation',
    });

    const controlled = http.get(`${BASE_URL}/users/me/controlled-devices`, {
      headers: authHeaders(friendToken),
    });
    check(controlled, { 'list controlled 200': (r) => r.status === 200 }, {
      tag: 'delegation',
    });

    const revoke = http.del(
      `${BASE_URL}/users/me/devices/${deviceId}/delegate`,
      null,
      { headers: authHeaders(ownerToken) },
    );
    check(revoke, { 'revoke 200': (r) => r.status === 200 }, {
      tag: 'delegation',
    });

    sleep(0.05);
  }

  const devices = http.get(`${BASE_URL}/users/me/devices`, {
    headers: authHeaders(ownerToken),
  });
  check(devices, { 'devices 200': (r) => r.status === 200 });
}
