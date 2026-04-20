import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { FastifyRequest } from 'fastify';
import { JwtPayload } from '../../auth/auth.service';

export const CurrentUser = createParamDecorator(
  (data: keyof JwtPayload | undefined, ctx: ExecutionContext): JwtPayload | string => {
    const request = ctx.switchToHttp().getRequest<FastifyRequest>();
    const user = (request as unknown as Record<string, unknown>).user as JwtPayload;
    return data ? user[data] : user;
  },
);
