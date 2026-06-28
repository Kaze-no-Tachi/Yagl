import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config.dart';

/// Thin wrapper around Dio that persists the JWT and attaches it to requests.
class ApiClient {
  ApiClient._(this._dio, this._storage);

  final Dio _dio;
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'yagl_access_token';

  Dio get dio => _dio;

  factory ApiClient.create() {
    final storage = const FlutterSecureStorage();
    final dio = Dio(
      BaseOptions(
        baseUrl: Config.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        // Don't throw on 4xx — callers inspect status codes themselves.
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    final client = ApiClient._(dio, storage);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.read(key: _tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
    return client;
  }

  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}

/// Raised for non-success API responses so the UI can show a message.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;

  /// Build from a Dio Response, pulling FastAPI's `detail` when present.
  factory ApiException.fromResponse(Response res) {
    String msg = 'Request failed (${res.statusCode})';
    final data = res.data;
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      msg = detail is List ? detail.map((e) => e.toString()).join(', ')
                            : detail.toString();
    }
    return ApiException(res.statusCode, msg);
  }
}
