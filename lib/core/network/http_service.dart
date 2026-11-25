import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../constants/app_constants.dart';
import '../security/certificate_pinning.dart';
import '../security/device_id_service.dart';
import '../security/secure_cookie_storage.dart';
import 'api_exception.dart';

/// The single choke point for HTTP traffic. Nothing else performs requests.
///
/// Security posture (all applied here, once):
/// - Session cookies (the API's HTTP-only auth) live in a [PersistCookieJar]
///   backed by the platform keystore ([SecureCookieStorage]).
/// - Release builds refuse any non-HTTPS request.
/// - Optional certificate pinning via [CertificatePinning].
/// - A per-install device id is sent on every request
///   ([AppConstants.deviceIdHeader]).
/// - Endpoint payloads and responses are logged via [PrettyDioLogger] in debug
///   mode, guarded by `assert` so it is stripped from release builds to prevent
///   leaks in production.
class HttpService {
  HttpService({
    Dio? dio,
    CookieJar? cookieJar,
    DeviceIdService? deviceIdService,
    CertificatePinning? pinning,
    String? baseUrl,
  })  : _cookieJar = cookieJar ??
            PersistCookieJar(storage: SecureCookieStorage()),
        _deviceId = deviceIdService ?? DeviceIdService(),
        _dio = dio ?? Dio() {
    final url = baseUrl ?? AppConstants.apiBaseUrl;
    if (kReleaseMode && Uri.parse(url).scheme != 'https') {
      throw StateError('API_BASE_URL must use HTTPS in release builds.');
    }
    _dio.options
      ..baseUrl = url
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 60)
      ..headers['Accept'] = 'application/json';

    final pin = pinning ?? CertificatePinning();
    if (pin.isEnabled) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        validateCertificate: pin.validate,
      );
    }

    _dio.interceptors
      ..add(_secureRequestInterceptor())
      ..add(CookieManager(_cookieJar));

    assert(() {
      _dio.interceptors.add(
        PrettyDioLogger(
          request: true,
          requestHeader: false,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          compact: true,
          maxWidth: 90,
        ),
      );
      return true;
    }());
  }

  final Dio _dio;
  final CookieJar _cookieJar;
  final DeviceIdService _deviceId;
  String? _bearerToken;

  /// Sets or clears the mobile `Authorization: Bearer <accessToken>` header
  /// returned by `/auth/verify` or `/parties/join-lobby`.
  void setBearerToken(String? token) {
    final trimmed = token?.trim();
    _bearerToken = (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
  }

  /// Current Bearer token, if any.
  String? get bearerToken => _bearerToken;

  /// Rejects cleartext requests in release and attaches the device id and
  /// Bearer token (when present).
  InterceptorsWrapper _secureRequestInterceptor() => InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (kReleaseMode && options.uri.scheme != 'https') {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                error: 'Cleartext HTTP is not allowed.',
              ),
            );
          }
          options.headers[AppConstants.deviceIdHeader] =
              await _deviceId.getOrCreate();
          final token = _bearerToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      );

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path, {Object? body}) =>
      _send('DELETE', path, body: body);

  /// Multipart upload. Pass a [FormData] body.
  Future<dynamic> postForm(String path, FormData form) =>
      _send('POST', path, body: form);

  Future<dynamic> putForm(String path, FormData form) =>
      _send('PUT', path, body: form);

  /// Drops all session cookies and Bearer token (e.g. on logout).
  Future<void> clearSession() async {
    _bearerToken = null;
    await _cookieJar.deleteAll();
  }

  // --- Internals ---

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );
      return response.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('The request timed out. Please try again.');
      case DioExceptionType.connectionError:
        return const ApiException('No internet connection.');
      default:
        break;
    }

    if (data is Map) {
      final serverMessage = data['message'] ?? data['error'] ?? data['detail'];
      if (serverMessage is String && serverMessage.isNotEmpty) {
        return ApiException(serverMessage, statusCode: status, body: data);
      }
    }
    if (status == 401 || status == 403) {
      return ApiException(
        'Your session is invalid or has expired.',
        statusCode: status,
        body: data,
      );
    }
    if (status == 429) {
      return ApiException(
        'Too many requests. Please wait and try again.',
        statusCode: status,
        body: data,
      );
    }
    if (status != null && status >= 500) {
      return ApiException(
        'Server error. Please try again later.',
        statusCode: status,
        body: data,
      );
    }
    return ApiException(
      'Something went wrong. Please try again.',
      statusCode: status,
      body: data,
    );
  }
}

final httpServiceProvider = Provider<HttpService>((ref) => HttpService());
