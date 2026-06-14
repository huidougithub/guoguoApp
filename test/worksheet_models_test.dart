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
    final catalog =
        jsonDecode(File('assets/worksheets/index.json').readAsStringSync())
            as Map<String, dynamic>;
    final mathDaily = (catalog['sets'] as List<dynamic>).firstWhere(
      (item) =>
          (item as Map<String, dynamic>)['asset'] ==
          'assets/worksheets/generated/math_daily_20_full.json',
    );
    final catalogItem = WorksheetCatalogItem.fromJson(
      mathDaily as Map<String, dynamic>,
    );
    expect(
      catalogItem.asset,
      'assets/worksheets/generated/math_daily_20_full.json',
    );

    final file = File(catalogItem.asset);
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

  test('每日练习支持导入本地题库JSON并持久化', () async {
    SharedPreferences.setMockInitialValues({});
    final service = WorksheetService();
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
