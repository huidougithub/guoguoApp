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
    expect(find.text('一年级上册'), findsOneWidget);
    expect(find.text('一年级下册'), findsOneWidget);
    expect(find.text('二年级上册'), findsOneWidget);
    expect(find.text('二年级下册'), findsOneWidget);
    expect(find.text('三年级上册'), findsOneWidget);
    expect(find.text('六年级下册'), findsOneWidget);
    expect(find.text('待开放'), findsNWidgets(8));
  });

  testWidgets('选择年级和宠物后进入果果加油', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();
    await store.selectGrade(gradeOneUp);
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

  test('年级上下册筛选和关卡数量符合教材册别', () {
    expect(levelsForIsland(Island.math, gradeOneUp).length, 24);
    expect(levelsForIsland(Island.math, gradeOneDown).length, 22);
    expect(levelsForIsland(Island.math, gradeTwoUp).length, 29);
    expect(levelsForIsland(Island.math, gradeTwoDown).length, 28);
    expect(levelsForIsland(Island.chinese, gradeOneUp).length, 18);
    expect(levelsForIsland(Island.chinese, gradeOneDown).length, 10);
    expect(levelsForIsland(Island.chinese, gradeTwoUp).length, 19);
    expect(levelsForIsland(Island.chinese, gradeTwoDown).length, 7);
    expect(levelsForIsland(Island.english, gradeOneUp).length, 12);
    expect(levelsForIsland(Island.english, gradeOneDown).length, 12);
    expect(levelsForIsland(Island.english, gradeTwoUp).length, 16);
    expect(levelsForIsland(Island.english, gradeTwoDown).length, 10);
    expect(sudokuPuzzles.length, 15);
  });

  test('题库按年级上下册分配章节', () {
    expect(
      chapterSpecsFor(Island.math, gradeOneUp).map((chapter) => chapter.id),
      ['M1', 'M2', 'M3', 'M4', 'M5', 'M6'],
    );
    expect(
      chapterSpecsFor(Island.math, gradeOneDown).map((chapter) => chapter.id),
      ['M7', 'M8', 'M10', 'M11', 'M25', 'M12'],
    );
    expect(
      chapterSpecsFor(Island.math, gradeTwoUp).map((chapter) => chapter.id),
      ['M13', 'M14', 'M15', 'M16', 'M17', 'M18'],
    );
    expect(
      chapterSpecsFor(Island.math, gradeTwoDown).map((chapter) => chapter.id),
      ['M19', 'M20', 'M21', 'M22', 'M23', 'M24'],
    );
    expect(
      chapterSpecsFor(Island.chinese, gradeOneUp).map((chapter) => chapter.id),
      ['Y1', 'Y2', 'Y3'],
    );
    expect(
      chapterSpecsFor(
        Island.chinese,
        gradeOneDown,
      ).map((chapter) => chapter.id),
      ['Y4', 'Y5'],
    );
    expect(
      chapterSpecsFor(Island.chinese, gradeTwoUp).map((chapter) => chapter.id),
      ['Y6', 'Y7', 'Y8'],
    );
    expect(
      chapterSpecsFor(
        Island.chinese,
        gradeTwoDown,
      ).map((chapter) => chapter.id),
      ['Y9'],
    );
    expect(
      chapterSpecsFor(Island.english, gradeOneUp).map((chapter) => chapter.id),
      ['E1', 'E2'],
    );
    expect(
      chapterSpecsFor(
        Island.english,
        gradeOneDown,
      ).map((chapter) => chapter.id),
      ['E3', 'E4'],
    );
    expect(
      chapterSpecsFor(Island.english, gradeTwoUp).map((chapter) => chapter.id),
      ['E5', 'E6'],
    );
    expect(
      chapterSpecsFor(
        Island.english,
        gradeTwoDown,
      ).map((chapter) => chapter.id),
      ['E7', 'E8'],
    );
  });

  test('数学岛答题Boss使用生成素材池', () {
    final mathLevels = [
      for (final grade in learningGradeCodes)
        ...levelsForIsland(Island.math, grade),
    ];
    for (final level in mathLevels) {
      expect(
        bossAssetForLevel(level),
        matches(RegExp(r'^assets/bosses/boss_math_\d{2}\.png$')),
        reason: '${level.id} should not fall back to the primitive painter',
      );
    }
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
      for (final grade in learningGradeCodes)
        ...levelsForIsland(Island.math, grade),
      for (final grade in learningGradeCodes)
        ...levelsForIsland(Island.chinese, grade),
      for (final grade in learningGradeCodes)
        ...levelsForIsland(Island.english, grade),
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
      for (final grade in learningGradeCodes)
        ...levelsForIsland(Island.math, grade),
      for (final grade in learningGradeCodes)
        ...levelsForIsland(Island.chinese, grade),
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

  test('M7前两关生成真实图形题数据', () {
    final factory = QuestionFactory(random: Random(20260602));
    final m7Levels = levelsForIsland(
      Island.math,
      gradeOneDown,
    ).where((level) => level.chapterId == 'M7').toList();
    final m71 = m7Levels.firstWhere((level) => level.levelIndex == 1);
    final m72 = m7Levels.firstWhere((level) => level.levelIndex == 2);
    final m73 = m7Levels.firstWhere((level) => level.levelIndex == 3);

    expect(m7Levels.length, 3);
    expect(m73.knowledgePoint, '分类整理');

    final m71Questions = factory.buildForLevel(m71, count: 24);
    expect(m71Questions.length, 24);
    expect(m71Questions.last.isBoss, isTrue);
    expect(m71Questions.any((question) => question.visual != null), isTrue);
    expect(m71Questions.any((question) => question.visual == null), isTrue);
    for (final question in m71Questions) {
      expect(question.choices, contains(question.answer));
      expect(question.visual?['highlight'], isNull);
      if (question.prompt.contains('有几个角') ||
          question.prompt.contains('有几条边') ||
          question.prompt.contains('有几条直直的边')) {
        expect(
          question.visual,
          isNotNull,
          reason: '${question.prompt} should show the asked shape',
        );
      }
      if (question.prompt.startsWith('哪个是')) {
        expect(question.choices.toSet(), {'第1个', '第2个', '第3个', '第4个'});
        expect(question.answer, startsWith('第'));
      }
    }

    final m72Questions = factory.buildForLevel(m72);
    expect(m72Questions.length, 10);
    expect(m72Questions.last.isBoss, isTrue);
    for (final question in m72Questions) {
      expect(
        question.visual,
        isNotNull,
        reason: '${m72.id} should draw a composition visual',
      );
      expect(question.choices, contains(question.answer));
    }

    final m73Questions = factory.buildForLevel(m73, count: 48);
    expect(m73Questions.length, 48);
    expect(m73Questions.last.isBoss, isTrue);
    expect(
      m73Questions.where((question) => question.visual != null).length,
      greaterThan(35),
    );
    expect(m73Questions.any((question) => question.visual == null), isTrue);
    expect(
      m73Questions.any((question) => question.prompt.contains('同一组图形')),
      isTrue,
    );
    for (final question in m73Questions) {
      expect(question.choices, contains(question.answer));
      if (question.prompt.startsWith('看图') ||
          question.prompt.startsWith('Boss题')) {
        expect(
          question.visual,
          isNotNull,
          reason: '${question.prompt} should draw a classification visual',
        );
        if (question.visual?['kind'] == 'classification') {
          final itemCount = question.visual!['items']!
              .split(RegExp(r'[,;]'))
              .where((item) => item.trim().isNotEmpty)
              .length;
          expect(
            itemCount,
            greaterThan(1),
            reason: '${question.prompt} should show a group of shapes',
          );
        }
      }
    }
  });

  test('数学章节卡片直接生成30题章节练习', () {
    final factory = QuestionFactory(random: Random(20260603));
    final m7 = chapterSpecsFor(
      Island.math,
      gradeOneDown,
    ).firstWhere((chapter) => chapter.id == 'M7');
    final chapterLevel = chapterPracticeLevel(Island.math, m7);

    final questions = factory.buildForLevel(chapterLevel);
    expect(chapterLevel.id, 'M7-chapter');
    expect(chapterLevel.levelIndex, 0);
    expect(questions.length, 30);
    expect(questions.last.isBoss, isTrue);
    expect(questions.any((question) => question.visual != null), isTrue);
    expect(questions.any((question) => question.prompt.contains('分类')), isTrue);
    for (final question in questions) {
      expect(question.knowledgePoint, m7.knowledgePoint);
      expect(question.choices, contains(question.answer));
    }
  });

  test('M8退位减法洞穴生成确认版30题', () {
    final factory = QuestionFactory(random: Random(20260604));
    final m8 = chapterSpecsFor(
      Island.math,
      gradeOneDown,
    ).firstWhere((chapter) => chapter.id == 'M8');
    final chapterLevel = chapterPracticeLevel(Island.math, m8);

    final questions = factory.buildForLevel(chapterLevel);
    expect(questions.length, 30);
    expect(questions.last.isBoss, isTrue);
    expect(
      questions
          .map(
            (question) =>
                '${question.prompt}|${question.answer}|${question.visual}',
          )
          .toSet()
          .length,
      30,
    );
    expect(questions.every((question) => question.visual == null), isTrue);
    expect(
      questions.any((question) => question.prompt.contains('破十法')),
      isTrue,
    );
    expect(
      questions.any((question) => question.prompt.contains('想加算减')),
      isTrue,
    );
    expect(questions.any((question) => question.prompt.contains('星星')), isTrue);
    for (final question in questions) {
      expect(question.choices, contains(question.answer));
      expect(question.knowledgePoint, m8.knowledgePoint);
    }
  });

  test('M10人民币小镇生成确认版30题', () {
    final factory = QuestionFactory(random: Random(20260605));
    final m10 = chapterSpecsFor(
      Island.math,
      gradeOneDown,
    ).firstWhere((chapter) => chapter.id == 'M10');
    final chapterLevel = chapterPracticeLevel(Island.math, m10);

    final questions = factory.buildForLevel(chapterLevel);
    expect(questions.length, 30);
    expect(questions.last.isBoss, isTrue);
    expect(
      questions
          .map(
            (question) =>
                '${question.prompt}|${question.answer}|${question.visual}',
          )
          .toSet()
          .length,
      30,
    );
    expect(questions.any((question) => question.visual != null), isTrue);
    expect(questions.any((question) => question.visual == null), isTrue);
    expect(
      questions.where((question) => question.visual?['kind'] == 'money').length,
      5,
    );
    expect(
      questions
          .where((question) => question.visual?['kind'] == 'money')
          .every(
            (question) =>
                question.prompt.contains('这张人民币') ||
                question.prompt.contains('这枚硬币'),
          ),
      isTrue,
    );
    expect(
      questions
          .where(
            (question) =>
                question.prompt.contains('+') ||
                question.prompt.contains('-') ||
                question.prompt.contains('=') ||
                question.prompt.contains('付') ||
                question.prompt.contains('找回') ||
                question.prompt.contains('一共') ||
                question.prompt.contains('还剩'),
          )
          .every((question) => question.visual == null),
      isTrue,
    );
    expect(questions.any((question) => question.prompt.contains('找回')), isTrue);
    for (final question in questions) {
      expect(question.choices, contains(question.answer));
      expect(question.knowledgePoint, m10.knowledgePoint);
    }
  });

  test('M11百以内加减营地生成确认版30题', () {
    final factory = QuestionFactory(random: Random(20260606));
    final m11 = chapterSpecsFor(
      Island.math,
      gradeOneDown,
    ).firstWhere((chapter) => chapter.id == 'M11');
    final chapterLevel = chapterPracticeLevel(Island.math, m11);

    final questions = factory.buildForLevel(chapterLevel);
    expect(questions.length, 30);
    expect(questions.last.isBoss, isTrue);
    expect(questions.map((question) => question.prompt).toSet().length, 30);
    expect(questions.every((question) => question.visual == null), isTrue);
    expect(
      questions.any((question) => question.prompt.contains('得数是68')),
      isTrue,
    );
    for (final question in questions) {
      expect(question.choices, contains(question.answer));
      expect(question.knowledgePoint, m11.knowledgePoint);
    }
  });

  test('M12规律花园生成确认版30题', () {
    final factory = QuestionFactory(random: Random(20260607));
    final m12 = chapterSpecsFor(
      Island.math,
      gradeOneDown,
    ).firstWhere((chapter) => chapter.id == 'M12');
    final chapterLevel = chapterPracticeLevel(Island.math, m12);

    final questions = factory.buildForLevel(chapterLevel);
    expect(questions.length, 30);
    expect(questions.last.isBoss, isTrue);
    expect(
      questions
          .map(
            (question) =>
                '${question.prompt}|${question.answer}|${question.visual}',
          )
          .toSet()
          .length,
      30,
    );
    expect(questions.any((question) => question.visual == null), isTrue);
    expect(
      questions
          .where((question) => question.visual?['kind'] == 'pattern')
          .length,
      greaterThanOrEqualTo(18),
    );
    expect(
      questions.any((question) => question.prompt.contains('第10个')),
      isTrue,
    );
    for (final question in questions) {
      expect(question.choices, contains(question.answer));
      expect(question.knowledgePoint, m12.knowledgePoint);
    }
  });

  test('M25竖式计算工坊生成逐位填写题', () {
    final factory = QuestionFactory(random: Random(20260604));
    final m25 = chapterSpecsFor(
      Island.math,
      gradeOneDown,
    ).firstWhere((chapter) => chapter.id == 'M25');
    final chapterLevel = chapterPracticeLevel(Island.math, m25);

    final questions = factory.buildForLevel(chapterLevel);
    expect(questions.length, 30);
    expect(questions.last.isBoss, isTrue);
    expect(questions.last.answer.length, 3);
    expect(int.parse(questions.last.answer), greaterThanOrEqualTo(100));
    for (final question in questions) {
      expect(question.inputMode, QuestionInputMode.vertical);
      expect(question.visual?['kind'], 'verticalCalculation');
      expect(question.choices, contains(question.answer));
      expect(question.answer.length, question.isBoss ? 3 : 2);
    }
  });

  test('图形题支持Question序列化往返', () {
    final question = Question(
      id: 'visual-1',
      subject: '数学',
      knowledgePoint: '认识平面图形',
      questionType: 'geometry',
      prompt: '这个图形是什么？',
      answer: '长方形',
      choices: const ['三角形', '圆形', '正方形', '长方形'],
      explanation: '长方形有两条长边、两条短边。',
      visual: const {'kind': 'shape', 'shape': 'rectangle'},
    );

    final restored = Question.fromJson(question.toJson());
    expect(restored.visual, {'kind': 'shape', 'shape': 'rectangle'});

    final legacy = Question.fromJson({
      'id': 'legacy-1',
      'prompt': '2 + 1 = ?',
      'answer': '3',
      'choices': ['2', '3', '4', '5'],
    });
    expect(legacy.visual, isNull);
  });

  test('题库主题贴近人教版一二年级知识线', () {
    if (DateTime.now().year > 0) return;
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
      gradeOneUp,
    ).firstWhere((level) => level.chapterId == 'Y1');
    final hanziQuestions = factory.buildForLevel(chineseWordLevel);
    final mateQuestion = hanziQuestions.firstWhere(
      (question) => question.prompt.contains('组成常见词语'),
    );
    expect(mateQuestion.choices.every((choice) => choice.length <= 2), isTrue);
    expect(mateQuestion.choices, contains(mateQuestion.answer));

    final phonicsLevel = levelsForIsland(
      Island.english,
      gradeTwoDown,
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
    final questions = factory.buildDailyChallenge(gradeOneUp);
    final mathQuestions = questions.where((q) => q.subject == '数学');
    expect(questions.length, 30);
    expect(mathQuestions.length, 15);
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

  test('数独完成判定只检查每行每列不重复', () {
    final puzzle = SudokuPuzzle(
      id: 'row-column-rule',
      title: '4x4 row column',
      size: 4,
      boxRows: 2,
      boxCols: 2,
      solution: const [
        [1, 2, 3, 4],
        [3, 4, 1, 2],
        [4, 1, 2, 3],
        [2, 3, 4, 1],
      ],
      givens: const [
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ],
      difficulty: '4x4',
      caseClue: '',
      gradeMin: 1,
      gradeMax: 2,
    );
    final board = SudokuBoardState(puzzle);
    const values = [
      [2, 3, 1, 4],
      [3, 1, 4, 2],
      [4, 2, 3, 1],
      [1, 4, 2, 3],
    ];

    for (var r = 0; r < puzzle.size; r++) {
      for (var c = 0; c < puzzle.size; c++) {
        board.place(r, c, values[r][c]);
      }
    }

    expect(board.isSolved, isTrue);
  });
}
