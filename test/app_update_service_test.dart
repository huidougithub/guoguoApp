import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guoguo_forward/services/app_update_service.dart';

void main() {
  test('update manifest parses server json and detects newer builds', () {
    final manifest = AppUpdateManifest.fromJson(
      jsonDecode('''
      {
        "appId": "guoguo_forward",
        "latestVersion": "1.2.0",
        "latestBuild": 120,
        "minSupportedBuild": 100,
        "apkUrl": "http://8.163.115.183/guoguo/apk/guoguo_forward_1.2.0.apk",
        "sha256": "abc123",
        "size": 85700000,
        "force": true,
        "releaseNotes": ["新增自动更新", "优化试卷练习"]
      }
      ''')
          as Map<String, dynamic>,
    );

    expect(manifest.appId, 'guoguo_forward');
    expect(manifest.latestVersion, '1.2.0');
    expect(manifest.latestBuild, 120);
    expect(manifest.minSupportedBuild, 100);
    expect(manifest.force, isTrue);
    expect(manifest.releaseNotes, ['新增自动更新', '优化试卷练习']);
    expect(manifest.isNewerThan(119), isTrue);
    expect(manifest.isNewerThan(120), isFalse);
    expect(manifest.requiresBuild(99), isTrue);
    expect(manifest.requiresBuild(100), isFalse);
  });

  test('update manifest tolerates missing optional fields', () {
    final manifest = AppUpdateManifest.fromJson({
      'latestBuild': 7,
      'apkUrl': 'https://example.com/app.apk',
    });

    expect(manifest.appId, 'guoguo_forward');
    expect(manifest.latestVersion, '0.0.0');
    expect(manifest.latestBuild, 7);
    expect(manifest.releaseNotes, isEmpty);
    expect(manifest.force, isFalse);
  });

  test('apk file names are deterministic and safe', () {
    final manifest = AppUpdateManifest.fromJson({
      'latestVersion': '1.2.0 beta',
      'latestBuild': 120,
      'apkUrl': 'https://example.com/download/app.apk?token=abc',
    });

    expect(manifest.safeApkFileName, 'guoguo_forward_1.2.0_beta_120.apk');
  });
}
