import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy, StrategyOptionsWithRequest } from 'passport-jwt';
import { JwtBlacklistService } from '../jwt-blacklist.service';
import { JwtPayload } from '../auth.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    configService: ConfigService,
    private readonly jwtBlacklist: JwtBlacklistService,
  ) {
    const opts: StrategyOptionsWithRequest = {
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('JWT_SECRET')!,
      passReqToCallback: true,
    };
    super(opts);
  }

  async validate(
    req: unknown,
    payload: JwtPayload,
  ): Promise<JwtPayload> {
    const token = ExtractJwt.fromAuthHeaderAsBearerToken()(req as never);
    if (token) {
      const isBlacklisted = await this.jwtBlacklist.isBlacklisted(token);
      if (isBlacklisted) {
        throw new UnauthorizedException('Token has been revoked');
      }
    }

    return { sub: payload.sub, email: payload.email };
  }
}
