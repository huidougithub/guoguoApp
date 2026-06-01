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
    final worksheet = WorksheetSet.fromJson(parsed);
    _validateImportedWorksheet(worksheet);
    return worksheet;
  }

  Future<WorksheetCatalogItem> importWorksheetFromJson(
    String raw, {
    String? title,
  }) async {
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    final titleOverride = title?.trim();
    if (titleOverride != null && titleOverride.isNotEmpty) {
      parsed['title'] = titleOverride;
    }
    final worksheet = WorksheetSet.fromJson(parsed);
    _validateImportedWorksheet(worksheet);

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

  void _validateImportedWorksheet(WorksheetSet worksheet) {
    if (worksheet.id.trim().isEmpty) {
      throw const FormatException('题库缺少 id。');
    }
    if (worksheet.title.trim().isEmpty) {
      throw const FormatException('题库缺少标题。');
    }
    if (worksheet.days.isEmpty || worksheet.questionCount == 0) {
      throw const FormatException('题库里没有可练习的题目。');
    }
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
