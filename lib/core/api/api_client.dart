import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../storage/secure_storage.dart';
import '../config/app_config.dart';

class ApiClient {
  late final Dio dio;
  final SecureStorage _storage = SecureStorage();

  // Callback for handling unauthorized errors (401)
  static Function()? onUnauthorized;

  static String get baseUrl => AppConfig.apiUrl;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: AppConfig.connectionTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: AppConfig.defaultHeaders,
      ),
    );

    _setupInterceptors();
  }

  void _setupInterceptors() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _storage.deleteToken();
            // Trigger callback if set (app will handle navigation)
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );

    // Add logger in debug mode
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
      ),
    );
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    try {
      final response = await dio.get(path, queryParameters: queryParameters, options: options);
      return response;
    } on DioException catch (e) {
      // For validation errors (422), let the original DioException pass through
      if (e.response?.statusCode == 422) {
        rethrow;
      }
      throw _handleError(e);
    }
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options, void Function(int, int)? onSendProgress}) async {
    try {
      final response = await dio.post(path, data: data, queryParameters: queryParameters, options: options, onSendProgress: onSendProgress);
      return response;
    } on DioException catch (e) {
      // For validation errors (422), let the original DioException pass through
      // so the calling service can handle the specific validation errors
      if (e.response?.statusCode == 422) {
        rethrow;
      }
      throw _handleError(e);
    }
  }

  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await dio.put(path, data: data, queryParameters: queryParameters);
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> delete(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await dio.delete(path, queryParameters: queryParameters);
      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException error) {
    String message = 'An error occurred';

    if (error.response != null) {
      final data = error.response?.data;
      if (data is Map && data.containsKey('message')) {
        message = data['message'];
      } else {
        switch (error.response?.statusCode) {
          case 400:
            message = 'Bad request';
            break;
          case 401:
            message = 'Unauthorized';
            break;
          case 403:
            message = 'Forbidden';
            break;
          case 404:
            message = 'Not found';
            break;
          case 422:
            message = 'Validation error';
            break;
          case 500:
            message = 'Server error';
            break;
          default:
            message = 'Something went wrong';
        }
      }
    } else if (error.type == DioExceptionType.connectionTimeout) {
      message = 'Connection timeout';
    } else if (error.type == DioExceptionType.connectionError) {
      message = 'No internet connection';
    }

    return Exception(message);
  }
}