import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('找不同标记工具条不能残留乱码文案', () {
    final source = File(
      'lib/screens/leisure_playground_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('绗')));
    expect(source, isNot(contains('寮')));
    expect(source, isNot(contains('宸叉爣')));
    expect(source, contains('已标记'));
  });
}
