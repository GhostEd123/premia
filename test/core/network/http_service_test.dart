import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'package:premia/core/network/http_service.dart';

void main() {
  group('HttpService logging', () {
    test('registers PrettyDioLogger in interceptors when assertions enabled', () {
      final dio = Dio();
      HttpService(dio: dio, baseUrl: 'https://api.example.com');

      final hasPrettyLogger = dio.interceptors.any((i) => i is PrettyDioLogger);
      expect(hasPrettyLogger, isTrue);

      final logger = dio.interceptors.firstWhere((i) => i is PrettyDioLogger)
          as PrettyDioLogger;
      expect(logger.requestBody, isTrue);
      expect(logger.responseBody, isTrue);
      expect(logger.requestHeader, isFalse);
    });
  });
}
