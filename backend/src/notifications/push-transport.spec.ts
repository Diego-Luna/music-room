import { LogPushTransport, PushEnvelope } from './push-transport';

describe('LogPushTransport', () => {
  it('logs the envelope and resolves { ok: true }', async () => {
    const transport = new LogPushTransport();
    const envelope: PushEnvelope = {
      token: 'abcdefghij1234567890',
      platform: 'IOS',
      title: 'Hello',
      body: 'World',
    };
    const res = await transport.send(envelope);
    expect(res).toEqual({ ok: true });
  });
});
