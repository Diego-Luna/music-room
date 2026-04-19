import * as Joi from 'joi';

export const envValidationSchema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'production', 'test')
    .default('development'),
  PORT: Joi.number().default(3000),

  LOG_LEVEL: Joi.string()
    .valid('fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent')
    .optional(),

  DATABASE_URL: Joi.string().required(),

  REDIS_HOST: Joi.string().default('localhost'),
  REDIS_PORT: Joi.number().default(6379),

  JWT_SECRET: Joi.string().required(),
  JWT_EXPIRES_IN_SECONDS: Joi.number().default(900),
  JWT_REFRESH_SECRET: Joi.string().required(),
  JWT_REFRESH_EXPIRES_IN_SECONDS: Joi.number().default(604800),

  GOOGLE_CLIENT_ID: Joi.string().optional().allow(''),
  GOOGLE_CLIENT_SECRET: Joi.string().optional().allow(''),

  FACEBOOK_APP_ID: Joi.string().optional().allow(''),
  FACEBOOK_APP_SECRET: Joi.string().optional().allow(''),

  SPOTIFY_CLIENT_ID: Joi.string().optional().allow(''),
  SPOTIFY_CLIENT_SECRET: Joi.string().optional().allow(''),
  SPOTIFY_REDIRECT_URI: Joi.string()
    .uri()
    .default('http://localhost:3000/auth/spotify/callback'),

  THROTTLE_TTL: Joi.number().default(60000),
  THROTTLE_LIMIT: Joi.number().default(100),

  AUTH_THROTTLE_TTL: Joi.number().default(60000),
  AUTH_THROTTLE_LIMIT: Joi.number().default(10),

  APP_BASE_URL: Joi.string().uri().default('http://localhost:3000'),
  APP_FRONTEND_URL: Joi.string().uri().default('http://localhost:8080'),

  SMTP_HOST: Joi.string().default('localhost'),
  SMTP_PORT: Joi.number().default(1025),
  SMTP_USER: Joi.string().optional().allow(''),
  SMTP_PASSWORD: Joi.string().optional().allow(''),
  SMTP_FROM: Joi.string().default('Music Room <no-reply@musicroom.local>'),
  SMTP_SECURE: Joi.boolean().default(false),
});
