import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guoguo_forward/services/worksheet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bundledCatalog = '''
  {
    "sets": [
      {
        "id": "math_daily",
        "title": "Bundled Math",
        "subject": "math",
        "grade": "一年级下册",
        "description": "bundled",
        "asset": "assets/worksheets/generated/math_daily.json"
      },
      {
        "id": "local_only",
        "title": "Local Only",
        "subject": "chinese",
        "grade": "一年级下册",
        "description": "bundled only",
        "asset": "assets/worksheets/generated/local_only.json"
      }
    ]
  }
  ''';

  const remoteCatalog = '''
  {
    "version": 1,
    "baseUrl": "https://cdn.example.test/worksheets/",
    "sets": [
      {
        "id": "math_daily",
        "title": "Cloud Math",
        "subject": "math",
        "grade": "一年级下册",
        "description": "cloud replaces bundled",
        "asset": "generated/math_daily.json"
      }
    ]
  }
  ''';

  const remoteWorksheet = '''
  {
    "formatVersion": 1,
    "id": "math_daily",
    "title": "Cloud Math",
    "subject": "math",
    "grade": "一年级下册",
    "description": "cloud worksheet",
    "days": [
      {
        "day": 1,
        "title": "Day 1",
        "questions": [
          {
            "id": "q1",
            "type": "math",
            "prompt": "1+2=",
            "answers": ["3"],
            "answerSource": "auto"
          }
        ]
      }
    ]
  }
  ''';

  const remoteWorksheetWithDifferentInternalId = '''
  {
    "formatVersion": 1,
    "id": "math_daily_internal",
    "title": "Cloud Math",
    "subject": "math",
    "grade": "一年级下册",
    "description": "cloud worksheet",
    "days": [
      {
        "day": 1,
        "title": "Day 1",
        "questions": [
          {
            "id": "q1",
            "type": "math",
            "prompt": "1+2=",
            "answers": ["3"],
            "answerSource": "auto"
          }
        ]
      }
    ]
  }
  ''';

  Future<String> bundledLoader(String asset) async {
    if (asset == WorksheetService.catalogAsset) return bundledCatalog;
    return jsonEncode({
      'id': 'local_only',
      'title': 'Local Only',
      'subject': 'chinese',
      'days': const [],
    });
  }

  test('remote catalog replaces bundled items with the same id', () async {
    SharedPreferences.setMockInitialValues({});
    final fetched = <String>[];
    final service = WorksheetService(
      remoteCatalogUrl: 'https://cdn.example.test/worksheets/index.json',
      assetLoader: bundledLoader,
      remoteFetcher: (uri) async {
        fetched.add(uri.toString());
        if (uri.path.endsWith('/index.json')) return remoteCatalog;
        if (uri.path.endsWith('/generated/math_daily.json')) {
          return remoteWorksheet;
        }
        throw StateError('unexpected uri: $uri');
      },
    );

    final catalog = await service.loadCatalog();

    expect(catalog.map((item) => item.id), ['math_daily', 'local_only']);
    expect(catalog.first.title, 'Cloud Math');
    expect(
      catalog.first.asset,
      'remote:math_daily|https://cdn.example.test/worksheets/generated/math_daily.json',
    );

    final worksheet = await service.loadWorksheet(catalog.first.asset);
    expect(worksheet.title, 'Cloud Math');
    expect(worksheet.questionCount, 1);
    expect(fetched, contains('https://cdn.example.test/worksheets/index.json'));
    expect(
      fetched,
      contains('https://cdn.example.test/worksheets/generated/math_daily.json'),
    );
  });

  test(
    'cached remote catalog and worksheet are used when network fails',
    () async {
      SharedPreferences.setMockInitialValues({});
      final online = WorksheetService(
        remoteCatalogUrl: 'https://cdn.example.test/worksheets/index.json',
        assetLoader: bundledLoader,
        remoteFetcher: (uri) async {
          if (uri.path.endsWith('/index.json')) return remoteCatalog;
          if (uri.path.endsWith('/generated/math_daily.json')) {
            return remoteWorksheet;
          }
          throw StateError('unexpected uri: $uri');
        },
      );

      final onlineCatalog = await online.loadCatalog();
      await online.loadWorksheet(onlineCatalog.first.asset);

      final offline = WorksheetService(
        remoteCatalogUrl: 'https://cdn.example.test/worksheets/index.json',
        assetLoader: bundledLoader,
        remoteFetcher: (uri) => throw StateError('offline'),
      );

      final cachedCatalog = await offline.loadCatalog();
      final cachedWorksheet = await offline.loadWorksheet(
        cachedCatalog.first.asset,
      );

      expect(cachedCatalog.first.title, 'Cloud Math');
      expect(cachedWorksheet.title, 'Cloud Math');
      expect(cachedWorksheet.questionCount, 1);
    },
  );

  test(
    'remote worksheet cache also works when catalog id differs from json id',
    () async {
      SharedPreferences.setMockInitialValues({});
      final online = WorksheetService(
        remoteCatalogUrl: 'https://cdn.example.test/worksheets/index.json',
        assetLoader: bundledLoader,
        remoteFetcher: (uri) async {
          if (uri.path.endsWith('/index.json')) return remoteCatalog;
          if (uri.path.endsWith('/generated/math_daily.json')) {
            return remoteWorksheetWithDifferentInternalId;
          }
          throw StateError('unexpected uri: $uri');
        },
      );

      final onlineCatalog = await online.loadCatalog();
      await online.loadWorksheet(onlineCatalog.first.asset);

      final offline = WorksheetService(
        remoteCatalogUrl: 'https://cdn.example.test/worksheets/index.json',
        assetLoader: bundledLoader,
        remoteFetcher: (uri) => throw StateError('offline'),
      );

      final cachedCatalog = await offline.loadCatalog();
      final cachedWorksheet = await offline.loadWorksheet(
        cachedCatalog.first.asset,
      );

      expect(cachedCatalog.first.id, 'math_daily');
      expect(cachedWorksheet.id, 'math_daily_internal');
      expect(cachedWorksheet.questionCount, 1);
    },
  );
}
