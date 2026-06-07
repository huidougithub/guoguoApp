import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../services/app_store.dart';
import '../services/audio_service.dart';
import '../widgets/ui_components.dart';
import 'grade_selection_screen.dart';

class StatsSettingsScreen extends StatefulWidget {
  const StatsSettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<StatsSettingsScreen> createState() => _StatsSettingsScreenState();
}

class _StatsSettingsScreenState extends State<StatsSettingsScreen> {
  AppStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    final progress = store.progress;
    final completed = progress.completedLevels.length;
    return ExplorerScaffold(
      title: '统计与设置',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: SoftCard(
                color: const Color(0xFFFFF8E1),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '学习统计',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      StatPill(
                        icon: Icons.school,
                        label: '当前年级',
                        value: gradeName(progress.selectedGrade),
                        color: const Color(0xFFD9C7FF),
                      ),
                      const SizedBox(height: 12),
                      StatPill(
                        icon: Icons.flag,
                        label: '已完成关卡',
                        value: '$completed',
                        color: const Color(0xFFA7F3D0),
                      ),
                      const SizedBox(height: 12),
                      StatPill(
                        icon: Icons.star,
                        label: '总星星',
                        value: '${progress.totalStars}',
                        color: const Color(0xFFFFE08A),
                      ),
                      const SizedBox(height: 12),
                      StatPill(
                        icon: Icons.psychology_alt,
                        label: '错题本',
                        value: '${progress.wrongItems.length}',
                        color: const Color(0xFFFFC6D9),
                      ),
                      const SizedBox(height: 12),
                      StatPill(
                        icon: Icons.diamond,
                        label: '钻石',
                        value: '${progress.diamonds}',
                        color: const Color(0xFFE9D5FF),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: progress.badges.isEmpty
                            ? [const Chip(label: Text('还没有勋章'))]
                            : progress.badges
                                  .map((badge) => Chip(label: Text(badge)))
                                  .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: SoftCard(
                color: const Color(0xFFE3F2FD),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '安全设置',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('背景音乐'),
                        subtitle: const Text('主界面、关卡和数独会播放本地背景音乐。'),
                        value: progress.settings['music'] ?? false,
                        onChanged: (value) async {
                          await store.setSetting('music', value);
                          if (value) {
                            await AudioService.playBgm(AppMusicScene.home);
                          } else {
                            await AudioService.stopBgm();
                          }
                          await AudioService.playSfx(
                            AppSound.tap,
                            enabled: store.progress.settings['sfx'] ?? true,
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                      SwitchListTile(
                        title: const Text('音效反馈'),
                        subtitle: const Text('点击、答题、奖励、数独操作会播放短音效。'),
                        value: progress.settings['sfx'] ?? true,
                        onChanged: (value) async {
                          await store.setSetting('sfx', value);
                          await AudioService.playSfx(
                            AppSound.tap,
                            enabled: value,
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                      SwitchListTile(
                        title: const Text('家长批改模式'),
                        subtitle: const Text(
                          '开启后，语文试卷练习会显示“对/错”按钮，方便家长给手写题做标记。',
                        ),
                        value: progress.settings['parentReview'] ?? false,
                        onChanged: (value) async {
                          await store.setSetting('parentReview', value);
                          await AudioService.playSfx(
                            AppSound.tap,
                            enabled: store.progress.settings['sfx'] ?? true,
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.school),
                        title: const Text('选择年级'),
                        subtitle: Text(
                          '当前：${gradeName(progress.selectedGrade)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await AudioService.playSfx(
                            AppSound.tap,
                            enabled: store.progress.settings['sfx'] ?? true,
                          );
                          if (!context.mounted) return;
                          await pushScreen(
                            context,
                            GradeSelectionScreen(
                              store: store,
                              returnToPrevious: true,
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip),
                        title: const Text('隐私模式'),
                        subtitle: const Text('无广告、无社交、无内购、无上传。'),
                        trailing: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('重置进度'),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('确认重置进度？'),
                              content: const Text('这会清空本地学习记录、奖励、宠物成长和商店兑换。'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('取消'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('确认重置'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !context.mounted) return;
                          final navigator = Navigator.of(context);
                          navigator.popUntil((route) => route.isFirst);
                          await Future<void>.delayed(Duration.zero);
                          await store.resetProgress();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
