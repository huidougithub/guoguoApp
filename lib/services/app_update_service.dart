import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

const String defaultAppUpdateUrl = 'http://8.163.115.183/guoguo/update.json';

class AppVersionInfo {
  const AppVersionInfo({required this.versionName, required this.versionCode});

  final String versionName;
  final int versionCode;
}

class AppUpdateManifest {
  const AppUpdateManifest({
    required this.appId,
    required this.latestVersion,
    required this.latestBuild,
    required this.minSupportedBuild,
    required this.apkUrl,
    required this.sha256,
    required this.size,
    required this.force,
    required this.releaseNotes,
  });

  factory AppUpdateManifest.fromJson(Map<String, dynamic> json) {
    return AppUpdateManifest(
      appId: _stringValue(json['appId'], 'guoguo_forward'),
      latestVersion: _stringValue(json['latestVersion'], '0.0.0'),
      latestBuild: _intValue(json['latestBuild']),
      minSupportedBuild: _intValue(json['minSupportedBuild']),
      apkUrl: _stringValue(json['apkUrl'], ''),
      sha256: _stringValue(json['sha256'], ''),
      size: _intValue(json['size']),
      force: json['force'] == true,
      releaseNotes: (json['releaseNotes'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
    );
  }

  final String appId;
  final String latestVersion;
  final int latestBuild;
  final int minSupportedBuild;
  final String apkUrl;
  final String sha256;
  final int size;
  final bool force;
  final List<String> releaseNotes;

  bool isNewerThan(int currentBuild) => latestBuild > currentBuild;

  bool requiresBuild(int currentBuild) =>
      minSupportedBuild > 0 && currentBuild < minSupportedBuild;

  String get safeApkFileName {
    final version = latestVersion
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final safeVersion = version.isEmpty ? 'update' : version;
    return 'guoguo_forward_${safeVersion}_$latestBuild.apk';
  }

  static String _stringValue(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AppUpdateCheck {
  const AppUpdateCheck({required this.current, required this.manifest});

  final AppVersionInfo current;
  final AppUpdateManifest manifest;

  bool get hasUpdate => manifest.isNewerThan(current.versionCode);

  bool get isForced =>
      manifest.force || manifest.requiresBuild(current.versionCode);
}

class AppUpdateDownloadProgress {
  const AppUpdateDownloadProgress({
    required this.received,
    required this.total,
  });

  final int received;
  final int total;

  double? get fraction {
    if (total <= 0) return null;
    return (received / total).clamp(0, 1).toDouble();
  }
}

class AppUpdatePlatform {
  static const MethodChannel _channel = MethodChannel('guoguo_forward/update');

  Future<AppVersionInfo> currentAppInfo() async {
    final raw = await _channel.invokeMapMethod<String, Object?>('getAppInfo');
    return AppVersionInfo(
      versionName: raw?['versionName']?.toString() ?? '0.0.0',
      versionCode: _intValue(raw?['versionCode']),
    );
  }

  Future<String> apkPath(String fileName) async {
    return await _channel.invokeMethod<String>('getApkPath', fileName) ?? '';
  }

  Future<String> sha256File(String path) async {
    return await _channel.invokeMethod<String>('sha256File', path) ?? '';
  }

  Future<bool> canInstallPackages() async {
    return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
  }

  Future<void> openInstallPermissionSettings() {
    return _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  Future<void> installApk(String path) {
    return _channel.invokeMethod<void>('installApk', path);
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class AppUpdateService {
  AppUpdateService({
    this.updateUrl = defaultAppUpdateUrl,
    AppUpdatePlatform? platform,
    HttpClient? httpClient,
  }) : platform = platform ?? AppUpdatePlatform(),
       httpClient = httpClient ?? HttpClient();

  final String updateUrl;
  final AppUpdatePlatform platform;
  final HttpClient httpClient;

  Future<AppUpdateCheck> checkForUpdate() async {
    final current = await platform.currentAppInfo();
    final manifest = await fetchManifest();
    return AppUpdateCheck(current: current, manifest: manifest);
  }

  Future<AppUpdateManifest> fetchManifest() async {
    final request = await httpClient.getUrl(Uri.parse(updateUrl));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppUpdateException('检查更新失败：HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw AppUpdateException('更新文件格式不正确。');
    }
    return AppUpdateManifest.fromJson(decoded);
  }

  Future<String> downloadApk(
    AppUpdateManifest manifest, {
    void Function(AppUpdateDownloadProgress progress)? onProgress,
  }) async {
    if (manifest.apkUrl.trim().isEmpty) {
      throw AppUpdateException('新版 APK 地址为空。');
    }
    final targetPath = await platform.apkPath(manifest.safeApkFileName);
    if (targetPath.trim().isEmpty) {
      throw AppUpdateException('无法创建 APK 下载路径。');
    }
    final file = File(targetPath);
    await file.parent.create(recursive: true);

    final request = await httpClient.getUrl(Uri.parse(manifest.apkUrl));
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppUpdateException('下载 APK 失败：HTTP ${response.statusCode}');
    }

    final total = response.contentLength > 0
        ? response.contentLength
        : manifest.size;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(
          AppUpdateDownloadProgress(received: received, total: total),
        );
      }
    } finally {
      await sink.close();
    }

    if (manifest.size > 0 && await file.length() != manifest.size) {
      throw AppUpdateException('APK 文件大小不一致，请重新下载。');
    }
    if (manifest.sha256.trim().isNotEmpty) {
      final actual = await platform.sha256File(file.path);
      if (actual.toLowerCase() != manifest.sha256.trim().toLowerCase()) {
        throw AppUpdateException('APK 校验失败，请重新下载。');
      }
    }
    return file.path;
  }

  void close() {
    httpClient.close(force: true);
  }
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
