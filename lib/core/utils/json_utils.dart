import '../network/api_exception.dart';

/// Tolerant JSON helpers used at the data edge only.
abstract class JsonUtils {
  JsonUtils._();

  /// Returns [raw] as a map or throws the single fallback [ApiException].
  static Map<String, dynamic> asMap(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw const ApiException(ApiException.unexpectedResponse);
  }

  /// Returns [raw] as a list of maps (non-map items are dropped).
  static List<Map<String, dynamic>> asMapList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    throw const ApiException(ApiException.unexpectedResponse);
  }

  static String string(Map<String, dynamic> j, List<String> keys,
      {String fallback = ''}) {
    for (final k in keys) {
      final v = j[k];
      if (v != null) return v.toString();
    }
    return fallback;
  }

  static String? stringOrNull(Map<String, dynamic> j, List<String> keys) {
    for (final k in keys) {
      final v = j[k];
      if (v != null) return v.toString();
    }
    return null;
  }

  static num? numberOrNull(Map<String, dynamic> j, List<String> keys) {
    for (final k in keys) {
      final v = j[k];
      if (v is num) return v;
      if (v is String) {
        final p = num.tryParse(v);
        if (p != null) return p;
      }
    }
    return null;
  }

  static num number(Map<String, dynamic> j, List<String> keys, {num fallback = 0}) =>
      numberOrNull(j, keys) ?? fallback;

  static int integer(Map<String, dynamic> j, List<String> keys, {int fallback = 0}) =>
      number(j, keys, fallback: fallback).toInt();

  static double decimal(Map<String, dynamic> j, List<String> keys,
          {double fallback = 0}) =>
      number(j, keys, fallback: fallback).toDouble();

  static DateTime? dateTime(Map<String, dynamic> j, List<String> keys) {
    final s = stringOrNull(j, keys);
    return s == null ? null : DateTime.tryParse(s);
  }
}
