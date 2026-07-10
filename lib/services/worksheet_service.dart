import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/worksheet_models.dart';

typedef WorksheetAssetLoader = Future<String> Function(String asset);
typedef WorksheetRemoteFetcher = Future<String> Function(Uri uri);

const String defaultWorksheetRemoteCatalogUrl =
    'http://8.163.115.183/guoguo/worksheets/index.json';

class WorksheetService {
  WorksheetService({
    String? remoteCatalogUrl,
    WorksheetAssetLoader? assetLoader,
    WorksheetRemoteFetcher? remoteFetcher,
  }) : remoteCatalogUrl = remoteCatalogUrl ?? defaultWorksheetRemoteCatalogUrl,
       _assetLoader = assetLoader ?? rootBundle.loadString,
       _remoteFetcher = remoteFetcher ?? _fetchRemoteText;

  static const String catalogAsset = 'assets/worksheets/index.json';
  static const String defaultAsset =
      'assets/worksheets/generated/math_daily_20_full.json';
  static const MethodChannel _fileChannel = MethodChannel(
    'guoguo_forward/files',
  );
  static const String _importedCatalogKey = 'imported_worksheet_catalog';
  static const String _localAssetPrefix = 'local:';
  static const String _remoteAssetPrefix = 'remote:';
  static const String _remoteCatalogCacheKey = 'remote_worksheet_catalog_v1';

  final String remoteCatalogUrl;
  final WorksheetAssetLoader _assetLoader;
  final WorksheetRemoteFetcher _remoteFetcher;

  static String _progressKey(String worksheetId) =>
      'worksheet_progress_$worksheetId';
  static String _worksheetKey(String worksheetId) =>
      'imported_worksheet_$worksheetId';
  static String _remoteWorksheetKey(String worksheetId) =>
      'remote_worksheet_$worksheetId';

  // ===== v1.0 格式规范常量 =====
  static const Set<String> _validTypes = {
    'chinese',
    'math',
    'english',
    'example',
    'display_only',
    'choice',
  };
  static const Set<String> _validAnswerSources = {
    'auto',
    'textbook',
    'manual_required',
    'display_only',
  };
  static const Set<String> _validInputTypes = {
    '',
    'number',
    'operator',
    'compare',
  };
  static const Set<String> _deprecatedFields = {
    'answer',
    'displayPrompt',
    'blanks',
    'segments',
  };
  // ignore: unused_field
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
    'choice': 'choice',
  };

  Future<List<WorksheetCatalogItem>> loadCatalog() async {
    final raw = await _assetLoader(catalogAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final bundled = (json['sets'] as List<dynamic>? ?? const [])
        .map(
          (item) => WorksheetCatalogItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
    final prefs = await SharedPreferences.getInstance();
    final remote = await _loadRemoteCatalog(prefs);
    final importedRaw = prefs.getString(_importedCatalogKey);
    final imported = importedRaw == null || importedRaw.isEmpty
        ? <WorksheetCatalogItem>[]
        : (jsonDecode(importedRaw) as List<dynamic>)
              .map(
                (item) =>
                    WorksheetCatalogItem.fromJson(item as Map<String, dynamic>),
              )
              .toList();
    return _mergeCatalogs([imported, remote, bundled]);
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
    if (asset.startsWith(_remoteAssetPrefix)) {
      return _loadRemoteWorksheet(asset);
    }
    final raw = await _assetLoader(asset);
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
          final type = (questionRaw['type'] as String? ?? '')
              .trim()
              .toLowerCase();
          if (type.isEmpty) {
            errors.add('$qPrefix：缺少 type。');
          } else if (!_validTypes.contains(type)) {
            errors.add(
              '$qPrefix：type "$type" 不合法。合法取值：${_validTypes.join('、')}。',
            );
          }

          // answerSource 校验
          final answerSource = (questionRaw['answerSource'] as String? ?? '')
              .trim()
              .toLowerCase();
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
            errors.add('$qPrefix：prompt 中存在旧格式 "____"，请替换为 "/r"。');
          }

          // 废弃字段检查
          for (final field in _deprecatedFields) {
            if (questionRaw.containsKey(field)) {
              errors.add('$qPrefix：存在废弃字段 "$field"，请按 v1.0 标准移除。');
            }
          }

          // 不允许存在旧 answer 字段
          if (questionRaw.containsKey('answer')) {
            errors.add('$qPrefix：存在旧字段 "answer"，请替换为 "answers" 数组。');
          }

          // /r 与 answers 数量严格校验
          final blankCount = '/r'.allMatches(prompt).length;
          final answers = questionRaw['answers'] as List<dynamic>?;
          final inputTypes = questionRaw['inputTypes'] as List<dynamic>?;

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

          if (inputTypes != null) {
            if (inputTypes.length > blankCount) {
              errors.add(
                '$qPrefix：inputTypes 长度（${inputTypes.length}）不能超过 "/r" 数量（$blankCount）。',
              );
            }
            for (var i = 0; i < inputTypes.length; i++) {
              final inputType = inputTypes[i].toString().trim().toLowerCase();
              if (!_validInputTypes.contains(inputType)) {
                errors.add(
                  '$qPrefix：inputTypes[$i] = "${inputTypes[i]}" 不合法。合法取值：空字符串、number、operator、compare。',
                );
              }
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

          // 选择题（choice）校验
          final options = questionRaw['options'] as List<dynamic>?;
          if (options != null && options.isNotEmpty) {
            if (options.length < 2) {
              errors.add('$qPrefix：选择题至少需要 2 个选项。');
            }
            if (answers != null && answers.isNotEmpty) {
              for (var i = 0; i < answers.length; i++) {
                final idx = int.tryParse(answers[i].toString());
                if (idx == null || idx < 0 || idx >= options.length) {
                  errors.add(
                    '$qPrefix：answers[$i] = "${answers[i]}" 不是有效的选项索引（0-${options.length - 1}）。',
                  );
                }
              }
              // 多选校验：answers 数量不应超过选项数量
              final multiSelect = questionRaw['multiSelect'] as bool? ?? false;
              if (multiSelect && answers.length > options.length) {
                errors.add(
                  '$qPrefix：多选题 answers 数量（${answers.length}）超过选项数量（${options.length}）。',
                );
              }
            }
            totalPracticeQuestions++;
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

  Future<List<WorksheetCatalogItem>> _loadRemoteCatalog(
    SharedPreferences prefs,
  ) async {
    final urlText = remoteCatalogUrl.trim();
    if (urlText.isEmpty) return _loadCachedRemoteCatalog(prefs);

    try {
      final catalogUri = Uri.parse(urlText);
      final raw = await _remoteFetcher(catalogUri);
      final items = _parseRemoteCatalog(raw, catalogUri);
      await prefs.setString(
        _remoteCatalogCacheKey,
        jsonEncode(items.map((item) => item.toJson()).toList()),
      );
      return items;
    } catch (_) {
      return _loadCachedRemoteCatalog(prefs);
    }
  }

  List<WorksheetCatalogItem> _parseRemoteCatalog(String raw, Uri catalogUri) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const [];
    final baseUrlText = decoded['baseUrl']?.toString().trim() ?? '';
    final baseUri = baseUrlText.isEmpty
        ? catalogUri.resolve('.')
        : _directoryUri(Uri.parse(baseUrlText));
    final sets = decoded['sets'] as List<dynamic>? ?? const [];

    return sets
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final id = item['id']?.toString().trim() ?? '';
          if (id.isEmpty) return null;
          final assetText = item['asset']?.toString().trim() ?? '';
          final worksheetUri = _resolveRemoteWorksheetUri(
            baseUri: baseUri,
            worksheetId: id,
            asset: assetText,
          );
          return WorksheetCatalogItem.fromJson({
            ...item,
            'asset': '$_remoteAssetPrefix$id|$worksheetUri',
          });
        })
        .whereType<WorksheetCatalogItem>()
        .toList();
  }

  Future<List<WorksheetCatalogItem>> _loadCachedRemoteCatalog(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_remoteCatalogCacheKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map(
            (item) =>
                WorksheetCatalogItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<WorksheetCatalogItem> _mergeCatalogs(
    List<List<WorksheetCatalogItem>> groups,
  ) {
    final result = <WorksheetCatalogItem>[];
    final seen = <String>{};
    for (final group in groups) {
      for (final item in group) {
        final id = item.id.trim();
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        result.add(item);
      }
    }
    return result;
  }

  Future<WorksheetSet> _loadRemoteWorksheet(String asset) async {
    final remote = _parseRemoteAsset(asset);
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = await _remoteFetcher(remote.uri);
      final worksheet = WorksheetSet.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      final cacheId = worksheet.id.trim().isEmpty ? remote.id : worksheet.id;
      await prefs.setString(_remoteWorksheetKey(cacheId), raw);
      if (cacheId != remote.id) {
        await prefs.setString(_remoteWorksheetKey(remote.id), raw);
      }
      return worksheet;
    } catch (_) {
      final cached = prefs.getString(_remoteWorksheetKey(remote.id));
      if (cached == null || cached.isEmpty) rethrow;
      return WorksheetSet.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }
  }

  ({String id, Uri uri}) _parseRemoteAsset(String asset) {
    final body = asset.substring(_remoteAssetPrefix.length);
    final splitIndex = body.indexOf('|');
    if (splitIndex <= 0 || splitIndex == body.length - 1) {
      throw FormatException('Invalid remote worksheet asset: $asset');
    }
    return (
      id: body.substring(0, splitIndex),
      uri: Uri.parse(body.substring(splitIndex + 1)),
    );
  }

  Uri _resolveRemoteWorksheetUri({
    required Uri baseUri,
    required String worksheetId,
    required String asset,
  }) {
    if (asset.startsWith('http://') || asset.startsWith('https://')) {
      return Uri.parse(asset);
    }
    final relative = asset.isEmpty ? 'generated/$worksheetId.json' : asset;
    return baseUri.resolve(relative);
  }

  static Uri _directoryUri(Uri uri) {
    final text = uri.toString();
    return text.endsWith('/') ? uri : Uri.parse('$text/');
  }

  static Future<String> _fetchRemoteText(Uri uri) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }
}

extension _StringCount on String {
  // ignore: unused_element
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
