import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/study_material_models.dart';

class StudyMaterialService {
  static const MethodChannel _channel = MethodChannel(
    'guoguo_forward/study_materials',
  );
  static const String _importedKey = 'imported_study_materials';

  static const List<StudyMaterialItem> bundledMaterials = [
    StudyMaterialItem(
      id: 'chinese_final_review_key_points_2026_spring',
      title: '26春一年级下语文期末复习高频考点知识汇总',
      description: '一年级下册语文 · 期末复习资料 · 图片版',
      fileName: 'chinese_final_review_key_points',
      pageAssets: [
        'assets/study_materials/chinese_final_review_key_points/page_001.jpg',
        'assets/study_materials/chinese_final_review_key_points/page_002.jpg',
        'assets/study_materials/chinese_final_review_key_points/page_003.jpg',
        'assets/study_materials/chinese_final_review_key_points/page_004.jpg',
        'assets/study_materials/chinese_final_review_key_points/page_005.jpg',
        'assets/study_materials/chinese_final_review_key_points/page_006.jpg',
        'assets/study_materials/chinese_final_review_key_points/page_007.jpg',
        'assets/study_materials/chinese_final_review_key_points/page_008.jpg',
        'assets/study_materials/chinese_final_review_key_points/page_009.jpg',
        'assets/study_materials/chinese_final_review_key_points/page_010.jpg',
        'assets/study_materials/chinese_final_review_key_points/page_011.jpg',
        'assets/study_materials/chinese_final_review_key_points/page_012.jpg',
      ],
      sizeBytes: 4514275,
    ),
  ];

  Future<List<StudyMaterialItem>> loadMaterials() async {
    final prefs = await SharedPreferences.getInstance();
    final importedRaw = prefs.getString(_importedKey);
    if (importedRaw == null || importedRaw.isEmpty) {
      return bundledMaterials;
    }
    final imported = (jsonDecode(importedRaw) as List<dynamic>)
        .map((item) => StudyMaterialItem.fromJson(item as Map<String, dynamic>))
        .where((item) => item.localPath != null && item.localPath!.isNotEmpty)
        .toList();
    return [...imported, ...bundledMaterials];
  }

  Future<StudyMaterialItem?> importPdf() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'pickStudyMaterialPdf',
    );
    if (result == null) return null;
    final localPath = result['path'] as String? ?? '';
    if (localPath.isEmpty) return null;

    final fileName = result['fileName'] as String? ?? 'study_material.pdf';
    final title = _titleFromFileName(fileName);
    final item = StudyMaterialItem(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: '用户导入资料 · PDF',
      fileName: fileName,
      localPath: localPath,
      imported: true,
      sizeBytes: result['sizeBytes'] as int? ?? 0,
    );
    final prefs = await SharedPreferences.getInstance();
    final current = await _loadImported(prefs);
    current.insert(0, item);
    await prefs.setString(
      _importedKey,
      jsonEncode(current.map((material) => material.toJson()).toList()),
    );
    return item;
  }

  Future<String> prepareLocalPdfPath(StudyMaterialItem item) async {
    if (item.localPath != null && item.localPath!.isNotEmpty) {
      return item.localPath!;
    }
    final assetPath = item.assetPath;
    if (assetPath == null || assetPath.isEmpty) {
      throw StateError('资料文件不存在。');
    }
    final data = await rootBundle.load(assetPath);
    final path = await _channel.invokeMethod<String>('cacheBundledPdf', {
      'fileName': item.fileName,
      'bytes': data.buffer.asUint8List(),
    });
    if (path == null || path.isEmpty) {
      throw StateError('资料缓存失败。');
    }
    return path;
  }

  Future<int> pageCount(String localPath) async {
    final count = await _channel.invokeMethod<int>('pdfPageCount', {
      'path': localPath,
    });
    return count ?? 0;
  }

  Future<Uint8List> renderPage({
    required String localPath,
    required int pageIndex,
    required int widthPx,
  }) async {
    final bytes = await _channel.invokeMethod<Uint8List>('renderPdfPage', {
      'path': localPath,
      'pageIndex': pageIndex,
      'widthPx': widthPx,
    });
    if (bytes == null || bytes.isEmpty) {
      throw StateError('页面渲染失败。');
    }
    return bytes;
  }

  Future<List<StudyMaterialItem>> _loadImported(SharedPreferences prefs) async {
    final raw = prefs.getString(_importedKey);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((item) => StudyMaterialItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  String _titleFromFileName(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    final raw = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    return raw.trim().isEmpty ? '考试重点资料' : raw.trim();
  }
}
