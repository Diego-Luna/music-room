import * as Joi from 'joi';

export const envValidationSchema = Joi.object({
  NODE_ENV: Joi.string()
    .valid('development', 'production', 'test')
    .default('development'),
  PORT: Joi.number().default(3000),

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

  THROTTLE_TTL: Joi.number().default(60000),
  THROTTLE_LIMIT: Joi.number().default(100),
});
