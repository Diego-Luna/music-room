import { Test } from '@nestjs/testing';
import { RealtimeService, roomChannel, userChannel } from './realtime.service';

describe('RealtimeService', () => {
  let service: RealtimeService;
  let emit: ReturnType<typeof vi.fn>;
  let to: ReturnType<typeof vi.fn>;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [RealtimeService],
    }).compile();
    service = module.get(RealtimeService);

    emit = vi.fn();
    to = vi.fn(() => ({ emit }));
    service.setServer({ to } as never);
  });

  it('emits to the room channel', () => {
    service.emitToRoom('room-1', 'member:joined', { userId: 'u1' });
    expect(to).toHaveBeenCalledWith(roomChannel('room-1'));
    expect(emit).toHaveBeenCalledWith('member:joined', { userId: 'u1' });
  });

  it('emits to the user channel', () => {
    service.emitToUser('u1', 'invitation:new', { roomId: 'r1' });
    expect(to).toHaveBeenCalledWith(userChannel('u1'));
    expect(emit).toHaveBeenCalledWith('invitation:new', { roomId: 'r1' });
  });

  it('drops the emit and logs a warning when the server is not ready', () => {
    const fresh = new RealtimeService();
    expect(() => fresh.emitToRoom('r', 'e', {})).not.toThrow();
    expect(() => fresh.emitToUser('u', 'e', {})).not.toThrow();
  });
});
