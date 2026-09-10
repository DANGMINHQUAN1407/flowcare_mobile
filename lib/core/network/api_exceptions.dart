class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NetworkException extends ApiException {
  NetworkException([super.message = 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng.']);
}

class TimeoutException extends ApiException {
  TimeoutException([super.message = 'Yêu cầu quá thời gian chờ (Timeout). Vui lòng thử lại.']);
}

class ServerException extends ApiException {
  ServerException(super.message, {super.statusCode, super.data});
}

class NotFoundException extends ApiException {
  NotFoundException([super.message = 'Dữ liệu không tồn tại.']) : super(statusCode: 404);
}

class ValidationException extends ApiException {
  final Map<String, dynamic>? errors;
  ValidationException(super.message, {this.errors}) : super(statusCode: 400);
}
