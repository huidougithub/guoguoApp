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

  test('导入和删除手动试卷入口受家长模式控制', () {
    final source = File(
      'lib/screens/worksheet_library_screen.dart',
    ).readAsStringSync();

    expect(source, contains("settings['parentReview'] == true"));
    expect(source, contains('category != null && parentReviewMode'));
    expect(
      source,
      contains('onImport: parentReviewMode ? _importWorksheet : null'),
    );
    expect(
      source,
      matches(
        RegExp(
          r'onDelete:\s*parentReviewMode\s*\?\s*\(item\)\s*=>\s*_deleteWorksheet\(item\)\s*:\s*null',
          multiLine: true,
        ),
      ),
    );
  });
}
