import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('试卷列表页面不能残留问号占位文案', () {
    final source = File(
      'lib/screens/worksheet_library_screen.dart',
    ).readAsStringSync();

    final placeholderText = RegExp(r"""(['"])[^'"\r\n]*\?\?[^'"\r\n]*\1""");
    expect(placeholderText.allMatches(source), isEmpty);
  });
}
