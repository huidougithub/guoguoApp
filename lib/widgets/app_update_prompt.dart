import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_update_service.dart';

Future<void> checkForAppUpdate(
  BuildContext context, {
  bool manual = false,
}) async {
  final service = AppUpdateService();
  try {
    final check = await service.checkForUpdate();
    if (!context.mounted) return;
    if (!check.hasUpdate) {
      if (manual) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前已是最新版本。')));
      }
      return;
    }
    final accepted = await _showUpdateDialog(context, check);
    if (accepted != true || !context.mounted) return;

    final canInstall = await service.platform.canInstallPackages();
    if (!context.mounted) return;
    if (!canInstall) {
      final openSettings = await showDialog<bool>(
        context: context,
        barrierDismissible: !check.isForced,
        builder: (context) => AlertDialog(
          title: const Text('需要安装授权'),
          content: const Text('请允许“果果向前冲”安装未知应用，授权后回到 APP 再点击检查更新。'),
          actions: [
            if (!check.isForced)
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('稍后'),
              ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('去授权'),
            ),
          ],
        ),
      );
      if (openSettings == true) {
        await service.platform.openInstallPermissionSettings();
      }
      return;
    }

    final apkPath = await _downloadWithProgress(context, service, check);
    if (apkPath == null || !context.mounted) return;
    await service.platform.installApk(apkPath);
  } on AppUpdateException catch (error) {
    if (manual && context.mounted) {
      _showUpdateError(context, error.message);
    }
  } on PlatformException catch (error) {
    if (manual && context.mounted) {
      _showUpdateError(context, error.message ?? '更新失败，请稍后重试。');
    }
  } catch (error) {
    if (manual && context.mounted) {
      _showUpdateError(context, '更新失败：$error');
    }
  } finally {
    service.close();
  }
}

Future<bool?> _showUpdateDialog(BuildContext context, AppUpdateCheck check) {
  final manifest = check.manifest;
  final notes = manifest.releaseNotes.isEmpty
      ? const ['发现新版本，建议更新后继续使用。']
      : manifest.releaseNotes;
  return showDialog<bool>(
    context: context,
    barrierDismissible: !check.isForced,
    builder: (context) => AlertDialog(
      title: Text('发现新版本 v${manifest.latestVersion}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前版本：v${check.current.versionName}（${check.current.versionCode}）',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '新版本：v${manifest.latestVersion}（${manifest.latestBuild}）',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            if (manifest.size > 0) ...[
              const SizedBox(height: 6),
              Text('安装包大小：${_formatBytes(manifest.size)}'),
            ],
            const SizedBox(height: 14),
            const Text(
              '更新内容',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            ...notes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $note'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!check.isForced)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('稍后'),
          ),
        FilledButton.icon(
          icon: const Icon(Icons.system_update_alt),
          label: const Text('下载更新'),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
}

Future<String?> _downloadWithProgress(
  BuildContext context,
  AppUpdateService service,
  AppUpdateCheck check,
) async {
  final progress = ValueNotifier<AppUpdateDownloadProgress?>(null);
  var dialogOpen = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('正在下载更新'),
        content: ValueListenableBuilder<AppUpdateDownloadProgress?>(
          valueListenable: progress,
          builder: (context, value, _) {
            final fraction = value?.fraction;
            final received = value?.received ?? 0;
            final total = value?.total ?? check.manifest.size;
            return SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: fraction),
                  const SizedBox(height: 12),
                  Text('${_formatBytes(received)} / ${_formatBytes(total)}'),
                  const SizedBox(height: 6),
                  const Text('下载完成后会打开系统安装界面。'),
                ],
              ),
            );
          },
        ),
      ),
    ),
  ).whenComplete(() => dialogOpen = false);

  try {
    final apkPath = await service.downloadApk(
      check.manifest,
      onProgress: (value) => progress.value = value,
    );
    return apkPath;
  } catch (_) {
    rethrow;
  } finally {
    if (context.mounted && dialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
      await Future<void>.delayed(Duration.zero);
    }
    progress.dispose();
  }
}

void _showUpdateError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '未知';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  final digits = unit == 0 || value >= 10 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}
