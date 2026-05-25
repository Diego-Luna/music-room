// Fan-out load test: 100 socket subscribers in one room receive
// `track:voted` events emitted by a single publisher (vote flips via
// REST API). Measures broadcast reach under concurrent subscribers.
//
// Speaks Engine.io v4 + Socket.io v5 protocol manually over raw WS
// (k6 has no Socket.io client built-in). One VU acts as the publisher
// (VU 1), the rest as subscribers.

import ws from 'k6/ws';
import http from 'k6/http';
import { sleep } from 'k6';
import { Counter } from 'k6/metrics';

export const options = {
  scenarios: {
    fanout: {
      executor: 'per-vu-iterations',
      vus: 100,
      iterations: 1,
      maxDuration: '90s',
    },
  },
  thresholds: {
    rt_delivered_events: ['count>2000'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const WS_URL = __ENV.WS_URL || 'ws://localhost:3000';

const delivered = new Counter('rt_delivered_events');

const JSON_HEADERS = { 'Content-Type': 'application/json' };
function authed(token) {
  return {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };
}

function registerAndLogin(email, displayName) {
  http.post(
    `${BASE_URL}/auth/register`,
    JSON.stringify({ email, password: 'LoadTest!123', displayName }),
    { headers: JSON_HEADERS },
  );
  const res = http.post(
    `${BASE_URL}/auth/login`,
    JSON.stringify({ email, password: 'LoadTest!123' }),
    { headers: JSON_HEADERS },
  );
  return res.json('accessToken');
}

// Setup runs ONCE before any VU iteration. Creates the shared room +
// track that all VUs will use. Return value is passed to default().
export function setup() {
  const email = `rt-owner-${Date.now()}@test.local`;
  const token = registerAndLogin(email, 'RT Owner');

  const room = http
    .post(
      `${BASE_URL}/rooms`,
      JSON.stringify({ name: 'Realtime Fanout', kind: 'VOTE' }),
      { headers: authed(token) },
    )
    .json();
  const track = http
    .post(
      `${BASE_URL}/rooms/${room.id}/tracks`,
      JSON.stringify({
        providerId: 'rt-fanout-1',
        title: 'Fanout',
        artist: 'Test',
        durationMs: 200000,
      }),
      { headers: authed(token) },
    )
    .json();

  return { roomId: room.id, trackId: track.id, ownerToken: token };
}

export default function (setupData) {
  if (__VU === 1) {
    publisher(setupData);
  } else {
    subscriber(setupData);
  }
}

// VU 1 — flips votes (+1 / -1) every 100 ms for 30 s, generating
// ~300 broadcast events on the room.
function publisher(d) {
  sleep(3); // let subscribers connect first
  const headers = authed(d.ownerToken);
  const start = Date.now();
  let value = 1;
  while (Date.now() - start < 30_000) {
    http.post(
      `${BASE_URL}/rooms/${d.roomId}/tracks/${d.trackId}/vote`,
      JSON.stringify({ value }),
      { headers },
    );
    value = value === 1 ? -1 : 1;
    sleep(0.1);
  }
}

// VUs 2..100 — subscribe via Socket.io and count incoming events.
function subscriber(d) {
  const email = `rt-sub-${__VU}-${Date.now()}@test.local`;
  const token = registerAndLogin(email, `RT ${__VU}`);
  if (!token) return;

  ws.connect(
    `${WS_URL}/socket.io/?EIO=4&transport=websocket`,
    null,
    (socket) => {
      let connected = false;

      socket.on('message', (msg) => {
        if (typeof msg !== 'string' || msg.length === 0) return;

        // Engine.io OPEN ("0{...}") → send Socket.io CONNECT (40) with auth.
        if (msg.charAt(0) === '0') {
          socket.send(`40${JSON.stringify({ token })}`);
          return;
        }
        // Engine.io PING → PONG
        if (msg === '2') {
          socket.send('3');
          return;
        }
        // Socket.io CONNECT ACK ("40{sid}") → send room:join
        if (msg.startsWith('40') && !connected) {
          connected = true;
          socket.send(
            `42${JSON.stringify(['room:join', { roomId: d.roomId }])}`,
          );
          return;
        }
        // Socket.io EVENT ("42[event,payload]") → count
        if (msg.startsWith('42')) {
          delivered.add(1);
        }
      });

      socket.setTimeout(() => socket.close(), 35_000);
    },
  );

  sleep(1);
}
