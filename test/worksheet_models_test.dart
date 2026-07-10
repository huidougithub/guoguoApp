import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guoguo_forward/models/app_models.dart';
import 'package:guoguo_forward/models/worksheet_models.dart';
import 'package:guoguo_forward/services/app_store.dart';
import 'package:guoguo_forward/services/worksheet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('每日练习JSON能被模型加载并统计进度', () {
    final file = File('assets/worksheets/generated/math_daily_20_full.json');
    final worksheet = WorksheetSet.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );

    expect(worksheet.days.length, 20);
    expect(worksheet.questionCount, 374);
    expect(worksheet.autoQuestionCount, 0);

    final firstDay = worksheet.days.first;
    expect(firstDay.questions.length, 19);
    expect(firstDay.autoQuestionCount, 0);
    expect(firstDay.questions.first.prompt, '14-7=');
    expect(firstDay.questions.first.answers, isEmpty);

    final progress = WorksheetProgress(
      answers: {
        firstDay.questions.first.id: '7',
        firstDay.questions.last.id: '7',
      },
      checkedQuestionIds: {
        firstDay.questions.first.id,
        firstDay.questions.last.id,
      },
      correctQuestionIds: {
        firstDay.questions.first.id,
        firstDay.questions.last.id,
      },
    );

    expect(progress.answeredCountFor(firstDay.questions), 2);
    expect(progress.correctCountFor(firstDay.questions), 2);
    expect(progress.checkedResultFor(firstDay.questions.first.id), isTrue);
  });

  test('每日练习进度支持序列化恢复', () {
    final progress = WorksheetProgress(
      answers: {'day01_q01': '7'},
      checkedQuestionIds: {'day01_q01'},
      correctQuestionIds: {'day01_q01'},
    );

    final restored = WorksheetProgress.fromJson(progress.toJson());

    expect(restored.answers['day01_q01'], '7');
    expect(restored.checkedResultFor('day01_q01'), isTrue);
    expect(restored.checkedResultFor('day01_q02'), isNull);
  });

  test('数学列式题 inputTypes 可选且空值默认为数字', () {
    final expression = WorksheetQuestion.fromJson({
      'id': 'expr_001',
      'type': 'math',
      'prompt': '/r /r /r = /r',
      'answers': ['8', '+', '5', '13'],
      'inputTypes': ['', 'operator'],
      'answerSource': 'auto',
    });
    final legacy = WorksheetQuestion.fromJson({
      'id': 'expr_legacy',
      'type': 'math',
      'prompt': '/r+/r=/r',
      'answers': ['8', '5', '13'],
      'answerSource': 'auto',
    });

    expect(expression.inputTypes, ['', 'operator']);
    expect(expression.blankInputType(0), 'number');
    expect(expression.blankInputType(1), 'operator');
    expect(expression.blankInputType(2), 'number');
    expect(expression.blankInputType(3), 'number');
    expect(legacy.inputTypes, isEmpty);
    expect(legacy.blankInputType(0), 'number');
  });

  test('内联选择题支持一组 blankChoices 共享给多个填空', () {
    final question = WorksheetQuestion.fromJson({
      'id': 'polyphone_001',
      'type': 'inline_choice',
      'prompt': '只/r有一只/r乌鸦居住在大树上。',
      'blankChoices': [
        ['zhǐ', 'zhī'],
      ],
      'answers': ['zhǐ', 'zhī'],
      'answerSource': 'auto',
    });

    expect(question.isInlineChoice, isTrue);
    expect(question.blankCount, 2);
    expect(question.blankChoicesForBlank(0), ['zhǐ', 'zhī']);
    expect(question.blankChoicesForBlank(1), ['zhǐ', 'zhī']);
  });

  test('final review day 2 to 4 uses fillable operators and valid images', () {
    final file = File('assets/worksheets/generated/final_review.json');
    final worksheet = WorksheetSet.fromJson(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );

    for (final day in worksheet.days.where(
      (day) => day.day >= 2 && day.day <= 4,
    )) {
      for (final question in day.questions) {
        expect(
          question.prompt.contains('/r+/r='),
          isFalse,
          reason: question.id,
        );
        expect(
          question.prompt.contains('/r-/r='),
          isFalse,
          reason: question.id,
        );
        expect(
          question.answers.length,
          question.blankCount,
          reason: question.id,
        );

        for (var i = 0; i < question.answers.length; i++) {
          final answer = question.answers[i];
          if (answer == '+' || answer == '-') {
            expect(question.blankInputType(i), 'operator', reason: question.id);
          }
        }

        for (final image in question.images) {
          expect(File(image).existsSync(), isTrue, reason: question.id);
        }
      }
    }
  });

  test('语文七天逆袭带图题已配置图片资源', () {
    final worksheet = WorksheetSet.fromJson(
      jsonDecode(
            File(
              'assets/worksheets/generated/chinese_final_7day_comeback.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>,
    );
    final day4 = worksheet.days.firstWhere((day) => day.day == 4);
    final day5 = worksheet.days.firstWhere((day) => day.day == 5);
    final day4ImageQuestion = day4.questions.firstWhere(
      (question) => question.id == 'chinese_7day_d04_q015',
    );
    final day5ImageQuestion = day5.questions.firstWhere(
      (question) => question.id == 'chinese_7day_d05_q031',
    );

    expect(day4ImageQuestion.images, [
      'assets/worksheets/images/chinese_final_7day_comeback/d04_q015.png',
    ]);
    expect(day5ImageQuestion.images, [
      'assets/worksheets/images/chinese_final_7day_comeback/d05_q031.png',
    ]);
    expect(File(day4ImageQuestion.images.single).existsSync(), isTrue);
    expect(File(day5ImageQuestion.images.single).existsSync(), isTrue);
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('assets/worksheets/images/chinese_final_7day_comeback/'),
    );
  });

  test('语文期末七天逆袭小卷已接入目录且题库合法', () {
    final catalog =
        jsonDecode(File('assets/worksheets/index.json').readAsStringSync())
            as Map<String, dynamic>;
    final item = (catalog['sets'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((item) => item['id'] == 'chinese_final_7day_comeback');

    expect(item['title'], '语文期末七天逆袭小卷');
    expect(item['subject'], '语文');
    expect(item['grade'], '一年级下册');

    final worksheet = WorksheetSet.fromJson(
      jsonDecode(File(item['asset'] as String).readAsStringSync())
          as Map<String, dynamic>,
    );

    expect(worksheet.id, 'chinese_final_7day_comeback');
    expect(worksheet.subject, 'chinese');
    expect(worksheet.days.length, 7);
    expect(worksheet.days.map((day) => day.day), [7, 6, 5, 4, 3, 2, 1]);
    expect(worksheet.questionCount, 215);
    final day2 = worksheet.days.firstWhere((day) => day.day == 2);
    final day3 = worksheet.days.firstWhere((day) => day.day == 3);
    final day4 = worksheet.days.firstWhere((day) => day.day == 4);
    final day5 = worksheet.days.firstWhere((day) => day.day == 5);
    final day6 = worksheet.days.firstWhere((day) => day.day == 6);
    final day7 = worksheet.days.firstWhere((day) => day.day == 7);
    const day6InlineChoiceIds = {
      'chinese_7day_d06_q001',
      'chinese_7day_d06_q002',
      'chinese_7day_d06_q003',
      'chinese_7day_d06_q006',
      'chinese_7day_d06_q007',
      'chinese_7day_d06_q008',
      'chinese_7day_d06_q009',
      'chinese_7day_d06_q010',
      'chinese_7day_d06_q011',
      'chinese_7day_d06_q014',
      'chinese_7day_d06_q015',
      'chinese_7day_d06_q016',
      'chinese_7day_d06_q018',
      'chinese_7day_d06_q019',
      'chinese_7day_d06_q020',
      'chinese_7day_d06_q021',
      'chinese_7day_d06_q026',
      'chinese_7day_d06_q027',
      'chinese_7day_d06_q028',
      'chinese_7day_d06_q029',
      'chinese_7day_d06_q031',
      'chinese_7day_d06_q032',
      'chinese_7day_d06_q033',
    };
    final day6InlineChoices = day6.questions
        .where((question) => day6InlineChoiceIds.contains(question.id))
        .toList();
    final day7InlineChoices = day7.questions
        .where((question) => question.isInlineChoice)
        .toList();
    expect(day2.title, '考前第2天');
    expect(day3.title, '考前第3天');
    expect(day4.title, '考前第4天');
    expect(day5.title, '考前第5天');
    expect(day6.title, '考前第6天');
    expect(day7.title, '考前第7天');
    expect(day6InlineChoices, hasLength(day6InlineChoiceIds.length));
    for (final question in day6InlineChoices) {
      expect(question.isInlineChoice, isTrue, reason: question.id);
      expect(question.prompt, isNot(contains('?')), reason: question.id);
      expect(question.blankChoices, isNotEmpty, reason: question.id);
      expect(
        question.blankChoices.length == 1 ||
            question.blankChoices.length == question.blankCount,
        isTrue,
        reason: question.id,
      );
      expect(
        question.answers,
        hasLength(question.blankCount),
        reason: question.id,
      );
      for (var i = 0; i < question.blankCount; i++) {
        expect(
          question.blankChoicesForBlank(i),
          contains(question.answers[i]),
          reason: question.id,
        );
      }
    }
    expect(day7InlineChoices, hasLength(day7.questions.length));
    for (final question in day7InlineChoices) {
      expect(question.isInlineChoice, isTrue, reason: question.id);
      expect(question.blankChoices, hasLength(1), reason: question.id);
      expect(
        question.blankChoicesForBlank(0),
        hasLength(2),
        reason: question.id,
      );
      if (question.blankCount > 1) {
        expect(
          question.blankChoicesForBlank(1),
          hasLength(2),
          reason: question.id,
        );
      }
    }
    for (final day in [day2, day3, day4, day5, day6, day7]) {
      expect(day.questions, isNotEmpty, reason: 'day ${day.day}');
      expect(
        day.questions.any((q) => q.sectionTitle.trim().isNotEmpty),
        isTrue,
        reason: 'day ${day.day}',
      );
    }
    expect(
      day7.questions.map((q) => q.sectionTitle).toSet(),
      contains('请选择正确读音'),
    );
    expect(
      worksheet.days.expand((day) => day.questions).map((q) => q.id).toSet(),
      hasLength(worksheet.days.expand((day) => day.questions).length),
    );
    for (final question in worksheet.days.expand((day) => day.questions)) {
      if (question.isDisplayOnly ||
          question.answerSource == 'manual_required') {
        continue;
      }
      if (question.isMatch) {
        expect(question.leftItems, isNotEmpty, reason: question.id);
        expect(question.rightItems, isNotEmpty, reason: question.id);
        expect(
          question.answers.length,
          question.leftItems.length,
          reason: question.id,
        );
        for (final answer in question.answers) {
          final index = int.tryParse(answer);
          expect(index, isNotNull, reason: question.id);
          expect(
            index,
            inInclusiveRange(0, question.rightItems.length - 1),
            reason: question.id,
          );
        }
      } else if (question.isChoice) {
        expect(
          question.options.length,
          greaterThanOrEqualTo(2),
          reason: question.id,
        );
        expect(question.answers, isNotEmpty, reason: question.id);
        for (final answer in question.answers) {
          final index = int.tryParse(answer);
          expect(index, isNotNull, reason: question.id);
          expect(
            index,
            inInclusiveRange(0, question.options.length - 1),
            reason: question.id,
          );
        }
      } else if (question.hasBlankMarkers &&
          question.answerSource != 'manual_required') {
        expect(
          question.answers.length,
          question.blankCount,
          reason: question.id,
        );
      }
    }
  });

  test('所有语文题库的客观题答案结构合法', () {
    final catalog =
        jsonDecode(File('assets/worksheets/index.json').readAsStringSync())
            as Map<String, dynamic>;
    final chineseItems = (catalog['sets'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((item) => item['subject'] == '语文')
        .toList();

    expect(chineseItems, isNotEmpty);
    for (final item in chineseItems) {
      final worksheet = WorksheetSet.fromJson(
        jsonDecode(File(item['asset'] as String).readAsStringSync())
            as Map<String, dynamic>,
      );
      final questions = worksheet.days.expand((day) => day.questions).toList();
      expect(
        questions.map((question) => question.id).toSet(),
        hasLength(questions.length),
        reason: worksheet.id,
      );

      for (final question in questions) {
        if (question.isDisplayOnly ||
            question.answerSource == 'manual_required') {
          continue;
        }
        if (question.isMatch) {
          expect(
            question.answers,
            hasLength(question.leftItems.length),
            reason: question.id,
          );
          for (final answer in question.answers) {
            final index = int.tryParse(answer);
            expect(index, isNotNull, reason: question.id);
            expect(
              index,
              inInclusiveRange(0, question.rightItems.length - 1),
              reason: question.id,
            );
          }
        } else if (question.isChoice) {
          expect(question.answers, isNotEmpty, reason: question.id);
          for (final answer in question.answers) {
            final index = int.tryParse(answer);
            expect(index, isNotNull, reason: question.id);
            expect(
              index,
              inInclusiveRange(0, question.options.length - 1),
              reason: question.id,
            );
          }
        } else if (question.isInlineChoice) {
          expect(question.blankChoices, isNotEmpty, reason: question.id);
          expect(
            question.blankChoices.length == 1 ||
                question.blankChoices.length == question.blankCount,
            isTrue,
            reason: question.id,
          );
          expect(
            question.answers,
            hasLength(question.blankCount),
            reason: question.id,
          );
          for (var i = 0; i < question.blankCount; i++) {
            expect(
              question.blankChoicesForBlank(i),
              contains(question.answers[i]),
              reason: question.id,
            );
          }
        } else if (question.hasBlankMarkers) {
          expect(
            question.answers,
            hasLength(question.blankCount),
            reason: question.id,
          );
        }
      }
    }
  });

  test('每日练习支持导入本地题库JSON并持久化', () async {
    SharedPreferences.setMockInitialValues({});
    final service = WorksheetService(remoteCatalogUrl: '');
    final item = await service.importWorksheetFromJson(
      jsonEncode({
        'formatVersion': 1,
        'id': 'local_math_sample',
        'title': '本地导入练习',
        'subject': 'math',
        'grade': '一年级上',
        'description': '本地导入测试',
        'days': [
          {
            'day': 1,
            'title': 'Day1',
            'questions': [
              {
                'id': 'day01_q01',
                'type': 'math',
                'prompt': '1+1=',
                'answers': ['2'],
                'answerSource': 'auto',
              },
            ],
          },
        ],
      }),
    );

    expect(item.asset, 'local:local_math_sample');

    final catalog = await service.loadCatalog();
    expect(catalog.first.id, 'local_math_sample');

    final worksheet = await service.loadWorksheet(item.asset);
    expect(worksheet.title, '本地导入练习');
    expect(worksheet.questionCount, 1);
    expect(worksheet.days.first.questions.first.answers, ['2']);
  });

  test('每日练习结算接入奖励和错题', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();
    final starsBefore = store.progress.totalStars;
    final fruitBefore = store.progress.energyFruit;

    final missed = Question(
      id: 'worksheet:sample:day01_q02',
      subject: '数学',
      knowledgePoint: '每日练习',
      questionType: 'calculation',
      prompt: '5+6-6=',
      answer: '5',
      choices: const [],
      explanation: '来自每日练习',
    );

    final first = await store.completeWorksheetPractice(
      worksheetId: 'sample',
      day: 1,
      correct: 18,
      total: 19,
      missedQuestions: [missed],
    );

    expect(first.stars, 2);
    expect(first.addedStars, 2);
    expect(first.addedEnergyFruit, 1);
    expect(store.progress.totalStars, starsBefore + 2);
    expect(store.progress.energyFruit, fruitBefore + 1);
    expect(store.progress.wrongItems.first.originalQuestion.prompt, '5+6-6=');

    final second = await store.completeWorksheetPractice(
      worksheetId: 'sample',
      day: 1,
      correct: 19,
      total: 19,
      missedQuestions: const [],
    );

    expect(second.stars, 3);
    expect(second.addedStars, 1);
    expect(second.addedEnergyFruit, 3);
    expect(store.progress.levelStars['worksheet:sample:day1'], 3);
  });

  test('试卷全对奖励钻石且现实奖励每次消耗一颗钻石', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();

    final first = await store.grantWorksheetDiamondIfPerfect(
      worksheetId: 'sample',
      correct: 10,
      total: 10,
    );
    final second = await store.grantWorksheetDiamondIfPerfect(
      worksheetId: 'sample',
      correct: 10,
      total: 10,
    );

    expect(first, isTrue);
    expect(second, isFalse);
    expect(store.progress.diamonds, 1);

    final redeemed = await store.redeemRealReward('milk_tea');

    expect(redeemed, isTrue);
    expect(store.progress.diamonds, 0);
    expect(store.progress.realRewardRedemptions['milk_tea'], 1);
    expect(await store.redeemRealReward('cake'), isFalse);
  });
}
