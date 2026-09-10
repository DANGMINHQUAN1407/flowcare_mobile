import 'dart:async';
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

  ApiClient({
    String? baseUrl,
    http.Client? client,
    Duration? timeout,
  })  : baseUrl = baseUrl ?? ApiEndpoints.defaultBaseUrl,
        _client = client ?? http.Client(),
        timeout = timeout ?? const Duration(seconds: AppConstants.connectTimeoutSeconds);

  Map<String, String> get _defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

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
  }) async {
    try {
      final uri = _buildUri(path, queryParameters);
      final response = await _client
          .get(uri, headers: {..._defaultHeaders, ...?headers})
          .timeout(timeout);

      return _handleResponse<T>(response, fromJsonT);
    } on SocketException {
      throw NetworkException();
    } on TimeoutException {
      throw TimeoutException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Lỗi không xác định khi kết nối: ${e.toString()}');
    }
  }

  Future<BaseResponse<T>> post<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJsonT,
  }) async {
    try {
      final uri = _buildUri(path, queryParameters);
      final response = await _client
          .post(
            uri,
            headers: {..._defaultHeaders, ...?headers},
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);

      return _handleResponse<T>(response, fromJsonT);
    } on SocketException {
      throw NetworkException();
    } on TimeoutException {
      throw TimeoutException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Lỗi không xác định khi gửi dữ liệu: ${e.toString()}');
    }
  }

  Future<BaseResponse<T>> put<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJsonT,
  }) async {
    try {
      final uri = _buildUri(path, queryParameters);
      final response = await _client
          .put(
            uri,
            headers: {..._defaultHeaders, ...?headers},
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);

      return _handleResponse<T>(response, fromJsonT);
    } on SocketException {
      throw NetworkException();
    } on TimeoutException {
      throw TimeoutException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Lỗi không xác định khi cập nhật dữ liệu: ${e.toString()}');
    }
  }

  Future<BaseResponse<T>> patch<T>(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJsonT,
  }) async {
    try {
      final uri = _buildUri(path, queryParameters);
      final response = await _client
          .patch(
            uri,
            headers: {..._defaultHeaders, ...?headers},
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);

      return _handleResponse<T>(response, fromJsonT);
    } on SocketException {
      throw NetworkException();
    } on TimeoutException {
      throw TimeoutException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Lỗi không xác định khi cập nhật: ${e.toString()}');
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
        return BaseResponse.fromJson(decodedBody, fromJsonT);
      }
      return BaseResponse<T>(success: true, data: decodedBody as T?);
    }

    // Handle standard error codes
    final errorMessage = (decodedBody is Map<String, dynamic>)
        ? decodedBody['message'] ?? 'Yêu cầu không thành công'
        : 'Yêu cầu thất bại (${response.statusCode})';

    switch (response.statusCode) {
      case 400:
        throw ValidationException(
          errorMessage.toString(),
          errors: decodedBody is Map<String, dynamic> ? decodedBody['errors'] : null,
        );
      case 404:
        throw NotFoundException(errorMessage.toString());
      case 409:
        throw ServerException(errorMessage.toString(), statusCode: 409);
      case 500:
      default:
        throw ServerException(
          errorMessage.toString(),
          statusCode: response.statusCode,
          data: decodedBody,
        );
    }
  }
}
