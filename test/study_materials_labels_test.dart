import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'study materials module is wired from home with bundled image pages',
    () {
      final homeSource = File(
        'lib/screens/home_screen.dart',
      ).readAsStringSync();
      final screenSource = File(
        'lib/screens/study_materials_screen.dart',
      ).readAsStringSync();
      final serviceSource = File(
        'lib/services/study_material_service.dart',
      ).readAsStringSync();
      const bundledPageAsset =
          'assets/study_materials/chinese_final_review_key_points/page_001.jpg';
      const removedPdfAsset =
          'assets/study_materials/chinese_final_review_key_points.pdf';

      expect(homeSource, contains('考试重点'));
      expect(homeSource, contains('StudyMaterialsScreen'));
      expect(screenSource, contains('导入资料'));
      expect(screenSource, contains('PDF'));
      expect(serviceSource, contains('pageAssets'));
      expect(serviceSource, contains(bundledPageAsset));
      expect(serviceSource, isNot(contains(removedPdfAsset)));
      expect(File(bundledPageAsset).existsSync(), isTrue);
      expect(File(removedPdfAsset).existsSync(), isFalse);
    },
  );

  test('study material viewer switches to portrait while reading', () {
    final screenSource = File(
      'lib/screens/study_materials_screen.dart',
    ).readAsStringSync();

    expect(screenSource, contains('package:flutter/services.dart'));
    expect(screenSource, contains('DeviceOrientation.portraitUp'));
    expect(screenSource, contains('DeviceOrientation.landscapeLeft'));
    expect(screenSource, contains('DeviceOrientation.landscapeRight'));
  });
}
