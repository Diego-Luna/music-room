import { ExecutionContext } from '@nestjs/common';

// Set by @Throttle({ auth }) even when the override object is empty.
const AUTH_LIMIT_METADATA = 'THROTTLER:LIMITauth';

/**
 * The auth bucket (10/min) is opt-in. Routes without @Throttle({ auth })
 * keep only the default bucket.
 */
export function skipAuthThrottler(context: ExecutionContext): boolean {
  const handler = context.getHandler();
  const controller = context.getClass();
  const optedIn =
    Reflect.hasMetadata(AUTH_LIMIT_METADATA, handler) ||
    Reflect.hasMetadata(AUTH_LIMIT_METADATA, controller);
  return !optedIn;
}
