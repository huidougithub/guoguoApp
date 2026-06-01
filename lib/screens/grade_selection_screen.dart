import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../services/app_store.dart';
import '../services/audio_service.dart';
import '../widgets/ui_components.dart';
import 'pet_selection_screen.dart';

class GradeSelectionScreen extends StatelessWidget {
  const GradeSelectionScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ExplorerScaffold(
      title: '选择学习年级',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              '智慧小探险家',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              '先选择当前年级，我会加载对应的知识大陆。',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                children: [
                  _GradeCard(
                    grade: 1,
                    title: '一年级',
                    subtitle: '数学 M1-M8、语文 Y1-Y2、英语 E1-E2、数独侦探',
                    color: const Color(0xFFFFD4A3),
                    store: store,
                  ),
                  const SizedBox(width: 18),
                  _GradeCard(
                    grade: 2,
                    title: '二年级',
                    subtitle: '数学 M1-M16、语文 Y1-Y4、英语 E1-E3、9宫数独',
                    color: const Color(0xFFA7F3D0),
                    store: store,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({
    required this.grade,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.store,
  });

  final int grade;
  final String title;
  final String subtitle;
  final Color color;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SoftCard(
        color: color,
        onTap: () async {
          await AudioService.playSfx(
            AppSound.reward,
            enabled: store.progress.settings['sfx'] ?? true,
          );
          await store.selectGrade(grade);
          if (!context.mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => PetSelectionScreen(store: store)),
          );
        },
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                child: Text(
                  '$grade',
                  style: const TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2D2A32),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${gradeName(grade)} 出发',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
