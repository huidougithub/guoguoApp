import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/app_store.dart';
import '../services/audio_service.dart';
import '../services/question_factory.dart';
import '../widgets/ui_components.dart';
import 'quiz_screen.dart';

class LevelListScreen extends StatelessWidget {
  const LevelListScreen({
    super.key,
    required this.store,
    required this.title,
    required this.levels,
  });

  final AppStore store;
  final String title;
  final List<LevelDefinition> levels;

  @override
  Widget build(BuildContext context) {
    return ExplorerScaffold(
      title: title,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 5,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: levels.map((level) {
            final stars = store.progress.levelStars[level.id] ?? 0;
            return SoftCard(
              color: stars > 0 ? const Color(0xFFFFF0A8) : Colors.white,
              onTap: () async {
                final questions = QuestionFactory().buildForLevel(level);
                await pushScreen(
                  context,
                  QuizScreen(store: store, level: level, questions: questions),
                );
                if (!context.mounted) return;
                if (store.progress.settings['music'] ?? false) {
                  AudioService.playBgm(_sceneForIsland(level.island));
                }
              },
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 145,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.flag,
                        size: 30,
                        color: Color(0xFF2D2A32),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '第${level.levelIndex}关',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        level.knowledgePoint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      StarRow(count: stars, size: 22),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

AppMusicScene _sceneForIsland(Island island) {
  return switch (island) {
    Island.math => AppMusicScene.math,
    Island.chinese => AppMusicScene.chinese,
    Island.english => AppMusicScene.english,
    Island.sudoku => AppMusicScene.sudoku,
  };
}
