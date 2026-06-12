import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/worksheet_models.dart';

class WorksheetService {
  static const String catalogAsset = 'assets/worksheets/index.json';
  static const String defaultAsset =
      'assets/worksheets/generated/math_daily_20_full.json';
  static const MethodChannel _fileChannel = MethodChannel(
    'guoguo_forward/files',
  );
  static const String _importedCatalogKey = 'imported_worksheet_catalog';
  static const String _localAssetPrefix = 'local:';

  static String _progressKey(String worksheetId) =>
      'worksheet_progress_$worksheetId';
  static String _worksheetKey(String worksheetId) =>
      'imported_worksheet_$worksheetId';

  // ===== v1.0 格式规范常量 =====
  static const Set<String> _validTypes = {
    'chinese',
    'math',
    'english',
    'example',
    'display_only',
  };
  static const Set<String> _validAnswerSources = {
    'auto',
    'textbook',
    'manual_required',
    'display_only',
  };
  static const Set<String> _deprecatedFields = {
    'answer',
    'displayPrompt',
    'blanks',
    'segments',
  };
  static const Map<String, String> _legacyTypeMap = {
    'calculation': 'math',
    'blank_equation': 'math',
    'word_problem': 'math',
    'text_fill': 'chinese',
    'pinyin_write': 'chinese',
    'pinyin_annotation': 'chinese',
    'pinyin_word_write': 'chinese',
    'stroke_fill': 'chinese',
    'stroke': 'chinese',
    'word_group': 'chinese',
    'word_usage': 'chinese',
    'word_fill': 'chinese',
    'word_match_fill': 'chinese',
    'sentence': 'chinese',
    'sentence_imitation': 'chinese',
    'sentence_write': 'chinese',
    'poem_fill': 'chinese',
    'recitation': 'chinese',
    'choice_manual': 'chinese',
    'polyphone': 'chinese',
    'letter_fill': 'chinese',
    'reading': 'chinese',
    'dictionary_fill': 'chinese',
    'chinese_manual': 'chinese',
    'pronunciation': 'chinese',
  };

  Future<List<WorksheetCatalogItem>> loadCatalog() async {
    final raw = await rootBundle.loadString(catalogAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final bundled = (json['sets'] as List<dynamic>? ?? const [])
        .map(
          (item) => WorksheetCatalogItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
    final prefs = await SharedPreferences.getInstance();
    final importedRaw = prefs.getString(_importedCatalogKey);
    if (importedRaw == null || importedRaw.isEmpty) return bundled;
    final importedJson = jsonDecode(importedRaw) as List<dynamic>;
    final imported = importedJson
        .map(
          (item) => WorksheetCatalogItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
    return [...imported, ...bundled];
  }

  Future<WorksheetSet> loadWorksheet(String asset) async {
    if (asset.startsWith(_localAssetPrefix)) {
      final worksheetId = asset.substring(_localAssetPrefix.length);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_worksheetKey(worksheetId));
      if (raw == null || raw.isEmpty) {
        throw StateError('导入题库不存在：$worksheetId');
      }
      return WorksheetSet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    final raw = await rootBundle.loadString(asset);
    return WorksheetSet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<WorksheetSet> loadDefaultWorksheet() async {
    return loadWorksheet(defaultAsset);
  }

  Future<WorksheetProgress> loadProgress(String worksheetId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey(worksheetId));
    if (raw == null || raw.isEmpty) return WorksheetProgress();
    return WorksheetProgress.fromJson(
      (jsonDecode(raw) as Map<dynamic, dynamic>).cast<String, dynamic>(),
    );
  }

  Future<void> saveProgress(
    String worksheetId,
    WorksheetProgress progress,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_progressKey(worksheetId), jsonEncode(progress));
  }

  Future<void> clearProgress(String worksheetId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_progressKey(worksheetId));
  }

  Future<String?> pickWorksheetJson() async {
    final raw = await _fileChannel.invokeMethod<String>('pickWorksheetJson');
    if (raw == null || raw.trim().isEmpty) return null;
    return raw;
  }

  Future<WorksheetCatalogItem?> importWorksheetFromFile({String? title}) async {
    final raw = await pickWorksheetJson();
    if (raw == null) return null;
    return importWorksheetFromJson(raw, title: title);
  }

  WorksheetSet previewWorksheet(String raw) {
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    _validateWorksheet(parsed);
    return WorksheetSet.fromJson(parsed);
  }

  Future<WorksheetCatalogItem> importWorksheetFromJson(
    String raw, {
    String? title,
  }) async {
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    _validateWorksheet(parsed);

    final titleOverride = title?.trim();
    if (titleOverride != null && titleOverride.isNotEmpty) {
      parsed['title'] = titleOverride;
    }
    final worksheet = WorksheetSet.fromJson(parsed);

    final catalogItem = WorksheetCatalogItem(
      id: worksheet.id,
      title: worksheet.title,
      subject: _displaySubject(worksheet.subject),
      grade: parsed['grade'] as String? ?? '未设置年级',
      description:
          parsed['description'] as String? ??
          '${worksheet.days.length}天 · ${worksheet.questionCount}题',
      asset: '$_localAssetPrefix${worksheet.id}',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_worksheetKey(worksheet.id), jsonEncode(parsed));

    final catalog = await _loadImportedCatalog(prefs);
    final existingIndex = catalog.indexWhere((item) => item.id == worksheet.id);
    if (existingIndex >= 0) {
      catalog[existingIndex] = catalogItem;
    } else {
      catalog.insert(0, catalogItem);
    }
    await prefs.setString(
      _importedCatalogKey,
      jsonEncode(catalog.map((item) => item.toJson()).toList()),
    );
    return catalogItem;
  }

  Future<List<WorksheetCatalogItem>> _loadImportedCatalog(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_importedCatalogKey);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map(
          (item) => WorksheetCatalogItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  /// 对导入的 JSON 进行严格的 v1.0 格式校验。
  /// 不符合规范的直接报错，不做任何自动迁移。
  void _validateWorksheet(Map<String, dynamic> parsed) {
    final errors = <String>[];

    // ===== 顶层字段校验 =====
    final worksheetId = (parsed['id'] as String? ?? '').trim();
    if (worksheetId.isEmpty) {
      errors.add('题库缺少 id。');
    }

    final title = (parsed['title'] as String? ?? '').trim();
    if (title.isEmpty) {
      errors.add('题库缺少 title（标题）。');
    }

    final daysRaw = parsed['days'] as List<dynamic>?;
    if (daysRaw == null || daysRaw.isEmpty) {
      errors.add('题库缺少 days 数组。');
    }

    // 检查废弃字段（顶层）
    for (final field in _deprecatedFields) {
      if (parsed.containsKey(field)) {
        errors.add('顶层存在废弃字段 "$field"，请按 v1.0 标准移除。');
      }
    }

    // ===== 遍历 days / questions 进行严格校验 =====
    final allQuestionIds = <String>{};
    var totalQuestions = 0;
    var totalPracticeQuestions = 0;

    if (daysRaw != null) {
      for (var d = 0; d < daysRaw.length; d++) {
        final dayRaw = daysRaw[d] as Map<String, dynamic>?;
        if (dayRaw == null) continue;

        final questionsRaw = dayRaw['questions'] as List<dynamic>?;
        if (questionsRaw == null || questionsRaw.isEmpty) {
          errors.add('第 ${d + 1} 天（${dayRaw['title'] ?? '未命名'}）没有题目。');
          continue;
        }

        for (var q = 0; q < questionsRaw.length; q++) {
          final questionRaw = questionsRaw[q] as Map<String, dynamic>?;
          if (questionRaw == null) continue;
          totalQuestions++;

          final qId = (questionRaw['id'] as String? ?? '').trim();
          final qPrefix = qId.isEmpty ? '第${d + 1}天第${q + 1}题' : '题目 "$qId"';

          // id 唯一性
          if (qId.isNotEmpty) {
            if (allQuestionIds.contains(qId)) {
              errors.add('$qPrefix：id 重复 "$qId"，同一试卷内题目 id 必须唯一。');
            } else {
              allQuestionIds.add(qId);
            }
          } else {
            errors.add('$qPrefix：缺少 id。');
          }

          // type 严格校验（不迁移）
          final type = (questionRaw['type'] as String? ?? '').trim().toLowerCase();
          if (type.isEmpty) {
            errors.add('$qPrefix：缺少 type。');
          } else if (!_validTypes.contains(type)) {
            errors.add(
              '$qPrefix：type "$type" 不合法。合法取值：${_validTypes.join('、')}。',
            );
          }

          // answerSource 校验
          final answerSource =
              (questionRaw['answerSource'] as String? ?? '').trim().toLowerCase();
          if (answerSource.isEmpty) {
            errors.add('$qPrefix：缺少 answerSource。');
          } else if (!_validAnswerSources.contains(answerSource)) {
            errors.add(
              '$qPrefix：answerSource "$answerSource" 不合法。合法取值：${_validAnswerSources.join('、')}。',
            );
          }

          // prompt 中不允许出现 ____
          final prompt = questionRaw['prompt'] as String? ?? '';
          if (prompt.contains('____')) {
            errors.add(
              '$qPrefix：prompt 中存在旧格式 "____"，请替换为 "/r"。',
            );
          }

          // 废弃字段检查
          for (final field in _deprecatedFields) {
            if (questionRaw.containsKey(field)) {
              errors.add('$qPrefix：存在废弃字段 "$field"，请按 v1.0 标准移除。');
            }
          }

          // 不允许存在旧 answer 字段
          if (questionRaw.containsKey('answer')) {
            errors.add(
              '$qPrefix：存在旧字段 "answer"，请替换为 "answers" 数组。',
            );
          }

          // /r 与 answers 数量严格校验
          final blankCount = '/r'.allMatches(prompt).length;
          final answers = questionRaw['answers'] as List<dynamic>?;

          if (blankCount > 0) {
            if (answers == null) {
              errors.add('$qPrefix：有 $blankCount 个 "/r" 但缺少 answers 数组。');
            } else if (answers.length != blankCount) {
              errors.add(
                '$qPrefix："/r" 数量（$blankCount）与 answers 长度（${answers.length}）不匹配。',
              );
            }
            totalPracticeQuestions++;
          } else {
            // 无 /r 的题目
            if (answers != null && answers.isNotEmpty) {
              totalPracticeQuestions++;
            }
          }

          // match 配对题校验
          final left = questionRaw['left'] as List<dynamic>?;
          final right = questionRaw['right'] as List<dynamic>?;
          if (left != null || right != null) {
            if (left == null || left.isEmpty) {
              errors.add('$qPrefix：match 题型缺少 left 数组。');
            }
            if (right == null || right.isEmpty) {
              errors.add('$qPrefix：match 题型缺少 right 数组。');
            }
            if (left != null &&
                right != null &&
                answers != null &&
                answers.length != left.length) {
              errors.add(
                '$qPrefix：match 题型的 answers 长度（${answers.length}）与 left 长度（${left.length}）不匹配。',
              );
            }
            if (left != null && right != null && answers != null) {
              for (var i = 0; i < answers.length; i++) {
                final idx = int.tryParse(answers[i].toString());
                if (idx == null || idx < 0 || idx >= right.length) {
                  errors.add(
                    '$qPrefix：answers[$i] = "${answers[i]}" 不是有效的 right 索引（0-${right.length - 1}）。',
                  );
                }
              }
            }
          }
        }
      }
    }

    if (totalQuestions == 0) {
      errors.add('题库里没有题目。');
    }
    if (totalPracticeQuestions == 0) {
      errors.add('题库里没有可练习的题目（所有题目都是 example/display_only 或没有答案）。');
    }

    // ===== 抛出错误（如有） =====
    if (errors.isNotEmpty) {
      throw FormatException(
        '导入失败，共 ${errors.length} 处错误：\n\n${errors.join('\n')}',
      );
    }
  }

  Future<void> deleteImportedWorksheet(String worksheetId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_worksheetKey(worksheetId));
    await prefs.remove(_progressKey(worksheetId));

    final catalog = await _loadImportedCatalog(prefs);
    catalog.removeWhere((item) => item.id == worksheetId);
    await prefs.setString(
      _importedCatalogKey,
      jsonEncode(catalog.map((item) => item.toJson()).toList()),
    );
  }

  String _displaySubject(String subject) {
    return switch (subject) {
      'math' => '数学',
      'chinese' => '语文',
      'english' => '英语',
      _ => subject.isEmpty ? '综合' : subject,
    };
  }
}

extension _StringCount on String {
  int count(String pattern) {
    var count = 0;
    var start = 0;
    while (true) {
      final index = indexOf(pattern, start);
      if (index == -1) break;
      count++;
      start = index + pattern.length;
    }
    return count;
  }
}
