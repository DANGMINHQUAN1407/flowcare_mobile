class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NetworkException extends ApiException {
  NetworkException([
    super.message =
        'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng.',
  ]);
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([
    super.message = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
  ]) : super(statusCode: 401);
}

class ForbiddenException extends ApiException {
  ForbiddenException([
    super.message = 'Tài khoản chưa được cấp quyền sử dụng chức năng này.',
  ]) : super(statusCode: 403);
}

class SessionChangedException extends ApiException {
  SessionChangedException() : super('Phiên bệnh nhân đã thay đổi.');
}

String patientErrorMessage(
  Object error, {
  String fallback = 'Không thể tải dữ liệu. Vui lòng thử lại.',
}) => error is ApiException ? error.message : fallback;

class TimeoutException extends ApiException {
  TimeoutException([
    super.message = 'Yêu cầu quá thời gian chờ (Timeout). Vui lòng thử lại.',
  ]);
}

class ServerException extends ApiException {
  ServerException(super.message, {super.statusCode, super.data});
}

class NotFoundException extends ApiException {
  NotFoundException([super.message = 'Dữ liệu không tồn tại.'])
    : super(statusCode: 404);
}

class ValidationException extends ApiException {
  final Map<String, dynamic>? errors;
  ValidationException(super.message, {this.errors}) : super(statusCode: 400);
}
