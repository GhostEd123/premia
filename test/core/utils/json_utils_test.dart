import 'package:flutter_test/flutter_test.dart';
import 'package:premia/core/utils/json_utils.dart';

void main() {
  group('JsonUtils.numberOrNull', () {
    test('returns num when present as numeric value', () {
      final json = {'amount': 5375, 'vat': 375.5};
      expect(JsonUtils.numberOrNull(json, ['amount']), 5375);
      expect(JsonUtils.numberOrNull(json, ['vat']), 375.5);
    });

    test('parses numeric string', () {
      final json = {'amount': '1250.75'};
      expect(JsonUtils.numberOrNull(json, ['amount']), 1250.75);
    });

    test('returns null when key is absent or non-numeric', () {
      final json = {'name': 'premia'};
      expect(JsonUtils.numberOrNull(json, ['amount']), isNull);
      expect(JsonUtils.numberOrNull(json, ['name']), isNull);
    });
  });
}

