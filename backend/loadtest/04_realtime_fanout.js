// Fan-out load test: one room, N subscribers, a single publisher
// emits events via the REST API (vote flips). Measures socket
// delivery latency across all connected clients.
//
// Requires a WebSocket endpoint on BASE_URL; we use the `ws` module.

import ws from 'k6/ws';
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter } from 'k6/metrics';

export const options = {
  scenarios: {
    subscribers: {
      executor: 'per-vu-iterations',
      vus: 100,
      iterations: 1,
      maxDuration: '60s',
    },
  },
  thresholds: {
    ws_msgs_received: ['count>2000'],
    ws_session_duration: ['p(95)<60000'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const WS_URL = __ENV.WS_URL || 'ws://localhost:3000';

const deliveryLatency = new Trend('rt_delivery_ms');
const delivered = new Counter('rt_delivered_events');

function auth() {
  const email = `rt-${__VU}-${Date.now()}@test.local`;
  http.post(
    `${BASE_URL}/auth/register`,
    JSON.stringify({
      email,
      password: 'LoadTest!123',
      displayName: `RT ${__VU}`,
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

export default function () {
  const token = auth();
  if (!token) return;

  const roomId = __ENV.ROOM_ID;
  if (!roomId) {
    console.warn('ROOM_ID env var is required');
    return;
  }

  const url = `${WS_URL}/socket.io/?EIO=4&transport=websocket&token=${token}`;
  const res = ws.connect(url, null, (socket) => {
    socket.on('open', () => {
      socket.send(
        JSON.stringify({ type: 'room:join', payload: { roomId } }),
      );
    });
    socket.on('message', (data) => {
      const now = Date.now();
      try {
        const m = JSON.parse(data);
        if (m?.payload?.at) {
          deliveryLatency.add(now - m.payload.at);
        }
        delivered.add(1);
      } catch {
        /* ignore non-JSON socket.io framing */
      }
    });
    socket.setTimeout(() => socket.close(), 45_000);
  });

  check(res, {
    'ws upgrade 101': (r) => r && r.status === 101,
  });
  sleep(1);
}
