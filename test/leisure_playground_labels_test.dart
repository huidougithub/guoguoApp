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

  test('找不同新增轻写实关卡资源成对接入', () {
    final source = File(
      'lib/screens/leisure_playground_screen.dart',
    ).readAsStringSync();

    final expectedCounts = <int, int>{
      46: 5,
      47: 6,
      48: 6,
      49: 5,
      50: 6,
      for (var level = 51; level <= 60; level += 1) level: 5,
    };

    for (final entry in expectedCounts.entries) {
      final level = entry.key;
      final leftAsset = 'assets/leisure/spot/ai/level_${level}_left.jpg';
      final rightAsset = 'assets/leisure/spot/ai/level_${level}_right.jpg';

      expect(source, contains(leftAsset));
      expect(source, contains(rightAsset));
      expect(File(leftAsset).existsSync(), isTrue);
      expect(File(rightAsset).existsSync(), isTrue);

      final block = RegExp(
        "leftAsset: '$leftAsset',[\\s\\S]*?\\n  \\),",
      ).firstMatch(source)?.group(0);

      expect(block, isNotNull);
      expect(
        RegExp('_SpotDifferenceMark').allMatches(block!).length,
        entry.value,
        reason: 'level_$level should use saved manual marks',
      );
    }
  });

  test('spot difference levels are persisted as manually marked', () {
    final source = File(
      'lib/screens/leisure_playground_screen.dart',
    ).readAsStringSync();

    final levelBlocks = RegExp(r"_SpotLevel\([\s\S]*?\n  \),")
        .allMatches(source)
        .map((match) => match.group(0)!)
        .where((block) => block.contains('leftAsset:'))
        .toList();

    expect(levelBlocks, hasLength(60));
    expect(
      levelBlocks.where((block) => block.contains('manualMarked: true,')),
      hasLength(50),
    );
    expect(
      levelBlocks.where((block) => block.contains('manualMarked: false,')),
      hasLength(10),
    );

    final expectedCounts = <int, int>{
      45: 5,
      46: 5,
      47: 6,
      48: 6,
      49: 5,
      50: 6,
      for (var level = 51; level <= 60; level += 1) level: 5,
    };
    for (final entry in expectedCounts.entries) {
      final rightAsset = 'assets/leisure/spot/ai/level_${entry.key}_right.jpg';
      final block = levelBlocks.singleWhere(
        (block) => block.contains("rightAsset: '$rightAsset'"),
      );
      if (entry.key <= 50) {
        expect(block, contains('manualMarked: true,'));
      } else {
        expect(block, contains('manualMarked: false,'));
      }
      expect(
        RegExp('_SpotDifferenceMark').allMatches(block).length,
        entry.value,
        reason: 'level_${entry.key} should use saved manual marks',
      );
    }
  });
}
