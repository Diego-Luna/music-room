import 'package:dio/dio.dart';

class ApiErrorHandler {
  static String getMessage(
    dynamic error, {
    String defaultMessage = 'An unexpected error occurred',
  }) {
    if (error is DioException && error.response?.data != null) {
      final data = error.response!.data;
      if (data is Map && data['message'] != null) {
        final msg = data['message'];
        if (msg is List) {
          return msg.join(', ');
        }
        return msg.toString();
      }
    }
    return error.toString();
  }
}
