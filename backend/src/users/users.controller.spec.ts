import { Test, TestingModule } from '@nestjs/testing';
import { UsersController } from './users.controller';
import { UsersService, UserProfile } from './users.service';
import { Visibility } from './dto/update-user.dto';

describe('UsersController', () => {
  let controller: UsersController;
  let service: Partial<UsersService>;

  const profile: UserProfile = {
    id: 'user-1',
    email: 'u@example.com',
    displayName: 'U',
    avatarUrl: null,
    emailVerified: true,
    visibility: Visibility.PUBLIC,
    musicPreferences: ['pop'],
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-02'),
  };

  beforeEach(async () => {
    service = {
      findOne: vi.fn().mockResolvedValue(profile),
      update: vi.fn().mockResolvedValue(profile),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [UsersController],
      providers: [{ provide: UsersService, useValue: service }],
    }).compile();

    controller = module.get<UsersController>(UsersController);
  });

  it('GET /users/me returns the caller profile', async () => {
    const res = await controller.me({ sub: 'user-1', email: 'u@example.com' });
    expect(res).toEqual(profile);
    expect(service.findOne).toHaveBeenCalledWith('user-1');
  });

  it('PATCH /users/me updates the caller profile', async () => {
    const res = await controller.updateMe(
      { sub: 'user-1', email: 'u@example.com' },
      { displayName: 'New Name' },
    );
    expect(res).toEqual(profile);
    expect(service.update).toHaveBeenCalledWith('user-1', {
      displayName: 'New Name',
    });
  });
});
