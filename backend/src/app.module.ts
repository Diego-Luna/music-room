import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { LoggerModule } from 'nestjs-pino';
import { PrismaModule } from './prisma/prisma.module';
import { RedisModule } from './redis/redis.module';
import { HealthModule } from './health/health.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { RoomsModule } from './rooms/rooms.module';
import { MailModule } from './mail/mail.module';
import { RequestLoggerMiddleware } from './common/middleware/request-logger.middleware';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { envValidationSchema } from './config/env.validation';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validationSchema: envValidationSchema,
      validationOptions: {
        abortEarly: true,
      },
    }),
    LoggerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => {
        const env = config.get<string>('NODE_ENV', 'development');
        return {
          pinoHttp: {
            level:
              config.get<string>('LOG_LEVEL') ??
              (env === 'production' ? 'info' : 'debug'),
            autoLogging: false,
            transport:
              env === 'development'
                ? { target: 'pino-pretty', options: { singleLine: true } }
                : undefined,
            redact: {
              paths: [
                'req.headers.authorization',
                'req.headers.cookie',
                'req.headers["x-refresh-token"]',
                'req.body.password',
                'req.body.newPassword',
                'req.body.currentPassword',
                'req.body.refreshToken',
                'req.body.accessToken',
                'req.body.token',
                'res.headers["set-cookie"]',
              ],
              censor: '[REDACTED]',
            },
          },
        };
      },
    }),
    ThrottlerModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => [
        {
          name: 'default',
          ttl: config.get<number>('THROTTLE_TTL', 60000),
          limit: config.get<number>('THROTTLE_LIMIT', 100),
        },
        {
          name: 'auth',
          ttl: config.get<number>('AUTH_THROTTLE_TTL', 60000),
          limit: config.get<number>('AUTH_THROTTLE_LIMIT', 10),
        },
      ],
    }),
    PrismaModule,
    RedisModule,
    MailModule,
    AuthModule,
    UsersModule,
    RoomsModule,
    HealthModule,
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(RequestLoggerMiddleware).forRoutes('*');
  }
}
