import 'dart:async' as async;
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/api_endpoints.dart';
import '../constants/app_constants.dart';
import 'api_exceptions.dart';
import 'base_response.dart';

class ApiClient {
  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  ApiClient({String? baseUrl, http.Client? client, Duration? timeout})
    : baseUrl = baseUrl ?? ApiEndpoints.defaultBaseUrl,
      _client = client ?? http.Client(),
      timeout =
          timeout ??
          const Duration(seconds: AppConstants.receiveTimeoutSeconds);

  static String? _authToken;
  static String? get authToken => _authToken;
  static bool _readOnlyDemo = false;
  static int _sessionVersion = 0;
  static int get sessionVersion => _sessionVersion;
  static void Function()? onUnauthorized;

  static void setAuthToken(String? token, {bool readOnlyDemo = false}) {
    _authToken = token;
    _readOnlyDemo = token != null && readOnlyDemo;
    _sessionVersion++;
  }

  static Future<void> ensureAuthenticated({String? baseUrl}) async {
    if (authToken == null || authToken!.isEmpty) throw UnauthorizedException();
  }

  void close() => _client.close();

  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$baseUrl$cleanPath';
    final uri = Uri.parse(fullUrl);

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    final queryMap = <String, String>{};
    queryParameters.forEach((key, value) {
      if (value != null) {
        queryMap[key] = value.toString();
      }
    });

    return uri.replace(queryParameters: queryMap);
  }

  Future<BaseResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJsonT,
    bool requiresAuth = true,
  }) => _send(
    'GET',
    path,
    queryParameters: queryParameters,
    headers: headers,
    fromJsonT: fromJsonT,
    requiresAuth: requiresAuth,
  );

  Future<BaseResponse<T>> post<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJsonT,
    bool requiresAuth = true,
  }) => _send(
    'POST',
    path,
    body: body,
    queryParameters: queryParameters,
    headers: headers,
    fromJsonT: fromJsonT,
    requiresAuth: requiresAuth,
  );

  Future<BaseResponse<T>> put<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJsonT,
    bool requiresAuth = true,
  }) => _send(
    'PUT',
    path,
    body: body,
    queryParameters: queryParameters,
    headers: headers,
    fromJsonT: fromJsonT,
    requiresAuth: requiresAuth,
  );

  Future<BaseResponse<T>> patch<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJsonT,
    bool requiresAuth = true,
  }) => _send(
    'PATCH',
    path,
    body: body,
    queryParameters: queryParameters,
    headers: headers,
    fromJsonT: fromJsonT,
    requiresAuth: requiresAuth,
  );

  Future<BaseResponse<T>> _send<T>(
    String method,
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJsonT,
    required bool requiresAuth,
  }) async {
    final version = _sessionVersion;
    final token = authToken;
    try {
      if (_readOnlyDemo && method != 'GET' && path != '/auth/login') {
        throw ForbiddenException(
          'Phiên chỉ xem không thể tạo hoặc sửa dữ liệu.',
        );
      }
      if (requiresAuth) await ensureAuthenticated();
      final request = http.Request(method, _buildUri(path, queryParameters))
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (requiresAuth) 'Authorization': 'Bearer $token',
          ...?headers,
        });
      if (body != null) request.body = jsonEncode(body);
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(timeout);
      if (requiresAuth && version != _sessionVersion) {
        throw SessionChangedException();
      }
      if (requiresAuth && response.statusCode == 401) {
        setAuthToken(null);
        onUnauthorized?.call();
        throw UnauthorizedException();
      }
      return _handleResponse<T>(response, fromJsonT);
    } on SocketException {
      throw NetworkException();
    } on http.ClientException {
      throw NetworkException();
    } on async.TimeoutException {
      throw TimeoutException();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Máy chủ trả dữ liệu không hợp lệ. Vui lòng thử lại.');
    }
  }

  BaseResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic json)? fromJsonT,
  ) {
    dynamic decodedBody;
    try {
      decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decodedBody = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decodedBody is Map<String, dynamic>) {
        if (decodedBody['success'] != true) {
          throw ServerException(
            'Máy chủ chưa xác nhận yêu cầu thành công.',
            statusCode: response.statusCode,
          );
        }
        return BaseResponse.fromJson(decodedBody, fromJsonT);
      }
      throw ServerException(
        'Máy chủ trả dữ liệu không hợp lệ.',
        statusCode: response.statusCode,
      );
    }

    // Handle standard error codes
    final errorMessage = (decodedBody is Map<String, dynamic>)
        ? decodedBody['message'] ?? 'Yêu cầu không thành công'
        : 'Yêu cầu thất bại (${response.statusCode})';

    switch (response.statusCode) {
      case 401:
        throw UnauthorizedException('Tên đăng nhập hoặc mật khẩu không đúng.');
      case 403:
        throw ForbiddenException();
      case 400:
        throw ValidationException(
          errorMessage.toString(),
          errors: decodedBody is Map<String, dynamic>
              ? decodedBody['errors']
              : null,
        );
      case 404:
        throw NotFoundException(errorMessage.toString());
      case 409:
        throw ServerException(
          errorMessage.toString(),
          statusCode: 409,
          data: decodedBody,
        );
      case 500:
      default:
        throw ServerException(
          response.statusCode >= 500
              ? 'Máy chủ đang gặp lỗi (${response.statusCode}). Vui lòng thử lại sau.'
              : errorMessage.toString(),
          statusCode: response.statusCode,
          data: decodedBody,
        );
    }
  }
}
