import {
  HttpException,
  HttpStatus,
  BadRequestException,
} from '@nestjs/common';
import { HttpExceptionFilter } from './http-exception.filter';

describe('HttpExceptionFilter', () => {
  let filter: HttpExceptionFilter;
  let mockReply: { status: ReturnType<typeof vi.fn>; send: ReturnType<typeof vi.fn> };
  let mockHost: {
    switchToHttp: ReturnType<typeof vi.fn>;
  };

  beforeEach(() => {
    filter = new HttpExceptionFilter();
    mockReply = {
      status: vi.fn().mockReturnThis(),
      send: vi.fn(),
    };
    mockHost = {
      switchToHttp: vi.fn().mockReturnValue({
        getResponse: vi.fn().mockReturnValue(mockReply),
      }),
    };
  });

  it('should handle HttpException with string response', () => {
    const exception = new HttpException('Not found', HttpStatus.NOT_FOUND);
    filter.catch(exception, mockHost as never);

    expect(mockReply.status).toHaveBeenCalledWith(404);
    expect(mockReply.send).toHaveBeenCalledWith(
      expect.objectContaining({
        statusCode: 404,
        message: 'Not found',
      }),
    );
  });

  it('should handle HttpException with object response', () => {
    const exception = new BadRequestException(['field is required']);
    filter.catch(exception, mockHost as never);

    expect(mockReply.status).toHaveBeenCalledWith(400);
    expect(mockReply.send).toHaveBeenCalledWith(
      expect.objectContaining({
        statusCode: 400,
      }),
    );
  });

  it('should handle non-HttpException as 500', () => {
    const exception = new Error('Something went wrong');
    filter.catch(exception, mockHost as never);

    expect(mockReply.status).toHaveBeenCalledWith(500);
    expect(mockReply.send).toHaveBeenCalledWith(
      expect.objectContaining({
        statusCode: 500,
        message: 'Internal server error',
      }),
    );
  });

  it('should include timestamp in response', () => {
    const exception = new HttpException('Test', 400);
    filter.catch(exception, mockHost as never);

    const sentBody = mockReply.send.mock.calls[0][0];
    expect(sentBody.timestamp).toBeDefined();
    expect(new Date(sentBody.timestamp).getTime()).not.toBeNaN();
  });
});
