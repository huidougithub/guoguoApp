import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:guoguo_forward/data/app_data.dart';
import 'package:guoguo_forward/main.dart';
import 'package:guoguo_forward/models/app_models.dart';
import 'package:guoguo_forward/services/app_store.dart';
import 'package:guoguo_forward/services/question_factory.dart';
import 'package:guoguo_forward/services/sudoku_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('首次启动进入年级选择', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();

    await tester.pumpWidget(WisdomExplorerApp(store: store));

    expect(find.text('智慧小探险家'), findsOneWidget);
    expect(find.text('一年级'), findsOneWidget);
    expect(find.text('二年级'), findsOneWidget);
  });

  testWidgets('选择年级和宠物后进入果果加油', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();
    await store.selectGrade(1);
    await store.selectPet('dino');
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(WisdomExplorerApp(store: store));
    await tester.pump();

    expect(find.text('果果加油！'), findsOneWidget);
    expect(find.text('数学岛'), findsOneWidget);
    expect(find.text('语文岛'), findsOneWidget);
    expect(find.text('英语岛'), findsOneWidget);
    expect(find.text('自我挑战'), findsOneWidget);
  });

  test('年级筛选和关卡数量符合2.0方案', () {
    expect(levelsForIsland(Island.math, 1).length, 51);
    expect(levelsForIsland(Island.math, 2).length, 59);
    expect(levelsForIsland(Island.chinese, 1).length, 28);
    expect(levelsForIsland(Island.chinese, 2).length, 26);
    expect(levelsForIsland(Island.english, 1).length, 24);
    expect(levelsForIsland(Island.english, 2).length, 26);
    expect(sudokuPuzzles.length, 15);
  });

  test('所有关卡默认开放', () {
    final store = AppStore();
    for (final level in playableLevels.take(40)) {
      expect(store.isLevelUnlocked(level), isTrue);
    }
    for (final puzzle in sudokuPuzzles) {
      expect(store.isSudokuUnlocked(puzzle), isTrue);
    }
  });

  test('题目生成器覆盖数学、语文、英语且包含正确答案', () {
    final factory = QuestionFactory();
    final sampleLevels = [
      ...levelsForIsland(Island.math, 2),
      ...levelsForIsland(Island.chinese, 2),
      ...levelsForIsland(Island.english, 2),
    ];
    for (final level in sampleLevels) {
      final questions = factory.buildForLevel(level);
      expect(
        questions.length,
        greaterThanOrEqualTo(4),
        reason: '${level.id} should keep enough useful questions',
      );
      expect(questions.length, lessThanOrEqualTo(10));
      expect(questions.last.isBoss, isTrue);
      for (final question in questions) {
        expect(question.choices, contains(question.answer));
      }
    }
  });

  test('数学和语文同一关卡不再生成重复题', () {
    final factory = QuestionFactory(random: Random(20260531));
    final levels = [
      ...levelsForIsland(Island.math, 1),
      ...levelsForIsland(Island.math, 2),
      ...levelsForIsland(Island.chinese, 1),
      ...levelsForIsland(Island.chinese, 2),
    ];

    for (final level in levels) {
      final questions = factory.buildForLevel(level);
      final prompts = questions
          .map((question) => question.prompt.replaceAll(RegExp(r'\s+'), ''))
          .toList();
      expect(
        prompts.toSet().length,
        prompts.length,
        reason: '${level.id} should not contain repeated prompts',
      );
    }
  });

  test('题库主题贴近人教版一二年级知识线', () {
    expect(
      levelsForIsland(Island.math, 1).map((level) => level.knowledgePoint),
      containsAll(['上下前后左右', '人民币换算', '简单找零']),
    );
    expect(
      levelsForIsland(Island.math, 2).map((level) => level.knowledgePoint),
      containsAll(['图形运动与数据比较', '万以内写数', '有余数除法']),
    );
    expect(
      levelsForIsland(Island.chinese, 1).map((level) => level.knowledgePoint),
      containsAll(['对韵歌', '青蛙写诗', '静夜思']),
    );
    expect(
      levelsForIsland(Island.chinese, 2).map((level) => level.knowledgePoint),
      containsAll(['登鹳雀楼', '寓言二则', '传统节日']),
    );
    expect(
      levelsForIsland(Island.english, 1).map((level) => level.knowledgePoint),
      containsAll(['hello', 'pencil', 'banana', 'milk']),
    );
    expect(
      levelsForIsland(Island.english, 2).map((level) => level.knowledgePoint),
      containsAll(['father', 'hospital', 'season', 'short o']),
    );
  });

  test('专项题库规则避免泄题并保持合法选项', () {
    final factory = QuestionFactory();
    final chineseWordLevel = levelsForIsland(
      Island.chinese,
      1,
    ).firstWhere((level) => level.chapterId == 'Y1');
    final hanziQuestions = factory.buildForLevel(chineseWordLevel);
    final mateQuestion = hanziQuestions.firstWhere(
      (question) => question.prompt.contains('组成常见词语'),
    );
    expect(mateQuestion.choices.every((choice) => choice.length <= 2), isTrue);
    expect(mateQuestion.choices, contains(mateQuestion.answer));

    final phonicsLevel = levelsForIsland(
      Island.english,
      2,
    ).firstWhere((level) => level.chapterId == 'E8' && level.levelIndex == 4);
    final phonicsQuestions = factory.buildForLevel(phonicsLevel);
    expect(
      phonicsQuestions.any((question) => question.prompt.contains('cl _ ck')),
      isTrue,
    );
    for (final question in phonicsQuestions) {
      expect(question.choices, contains(question.answer));
    }
  });

  test('错题变式支持三科', () {
    final factory = QuestionFactory();
    for (final subject in ['数学', '语文', '英语']) {
      final item = WrongItem(
        originalQuestion: Question(
          id: subject,
          subject: subject,
          knowledgePoint: subject == '语文'
              ? '词语搭配'
              : subject == '英语'
              ? '自然拼读'
              : '表内除法',
          questionType: subject == '语文'
              ? 'vocabulary'
              : subject == '英语'
              ? 'phonics'
              : 'calculation',
          prompt: '示例题',
          answer: '1',
          choices: const ['1', '2', '3', '4'],
          explanation: '示例',
        ),
        knowledgePoint: subject,
        questionType: subject == '语文'
            ? 'vocabulary'
            : subject == '英语'
            ? 'phonics'
            : 'calculation',
        createdAt: DateTime(2026),
      );
      final variant = factory.buildVariant(item);
      expect(variant.choices, contains(variant.answer));
    }
  });

  test('宠物等级和装扮扩展到Lv7', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();
    store.progress.petExp = 350;
    store.progress.energyFruit = 1200;
    store.progress.totalStars = 1200;
    await store.completeSudoku(sudokuPuzzles.first);
    await store.purchaseCosmetic(cosmeticById('cape'));
    await store.purchaseCosmetic(cosmeticById('crown'));

    expect(store.progress.petLevel, 7);
    expect(store.progress.unlockedCosmetics, contains('dino:cape'));
    expect(store.progress.unlockedCosmetics, contains('dino:crown'));
  });

  test('能量果喂食只增加1点经验，装扮按宠物独立拥有', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();
    await store.selectPet('fifi');
    store.progress.energyFruit = 100;
    store.progress.totalStars = 100;
    store.progress.petExp = 25;

    await store.feedPet();
    expect(store.progress.petExp, 26);
    expect(store.progress.energyFruit, 99);

    final ok = await store.purchaseCosmetic(cosmeticById('hat'));
    expect(ok, isTrue);
    expect(store.progress.unlockedCosmetics, contains('fifi:hat'));
    expect(store.equippedCosmeticsForPet('fifi'), contains('hat'));
    expect(store.equippedCosmeticsForPet('dino'), isNot(contains('hat')));
  });

  test('一年级今日挑战不生成乘除混合题', () {
    final factory = QuestionFactory();
    final questions = factory.buildDailyChallenge(1);
    final mathQuestions = questions.where((q) => q.subject == '数学');
    expect(mathQuestions.length, 5);
    for (final question in mathQuestions) {
      expect(question.prompt.contains('×'), isFalse);
      expect(question.prompt.contains('÷'), isFalse);
      expect(question.prompt.contains('余'), isFalse);
    }
  });

  test('数独状态支持填入、笔记、提示和完成判断', () {
    final puzzle = sudokuPuzzles.first;
    final board = SudokuBoardState(puzzle);
    final hint = board.useHint();
    expect(hint, isNotNull);
    expect(board.hintsLeft, 2);
    final row = hint!.row;
    final col = hint.col;
    board.toggleNote(row, col, puzzle.solution[row][col]);
    expect(board.notes[row][col], contains(puzzle.solution[row][col]));
    board.place(row, col, puzzle.solution[row][col]);
    expect(board.values[row][col], puzzle.solution[row][col]);
  });
}
