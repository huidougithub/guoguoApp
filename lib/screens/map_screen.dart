import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../models/app_models.dart';
import '../services/app_store.dart';
import '../services/question_factory.dart';
import '../widgets/ui_components.dart';
import 'level_list_screen.dart';
import 'quiz_screen.dart';
import 'sudoku_screen.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key, required this.store, required this.island});

  final AppStore store;
  final Island island;

  @override
  Widget build(BuildContext context) {
    final grade = normalizeGradeCode(store.progress.selectedGrade);
    final chapters = chapterSpecsFor(island, grade);
    return ExplorerScaffold(
      title: '${islandName(island)} · ${gradeName(grade)}',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: island == Island.sudoku
            ? _SudokuMap(store: store)
            : GridView.count(
                crossAxisCount: island == Island.math ? 3 : 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 2.05,
                children: chapters.map((chapter) {
                  final chapterLevel = chapterPracticeLevel(island, chapter);
                  final levels = levelsForIsland(
                    island,
                    grade,
                  ).where((level) => level.chapterId == chapter.id).toList();
                  final mathChapter = island == Island.math;
                  final finished = mathChapter
                      ? (store.progress.levelStars[chapterLevel.id] ?? 0)
                      : levels
                            .where(
                              (level) => store.progress.completedLevels
                                  .contains(level.id),
                            )
                            .length;
                  final total = mathChapter ? 3 : levels.length;
                  return SoftCard(
                    color: _chapterColor(chapter.id, island),
                    onTap: () {
                      if (mathChapter) {
                        final questions = QuestionFactory().buildForLevel(
                          chapterLevel,
                        );
                        pushScreen(
                          context,
                          QuizScreen(
                            store: store,
                            level: chapterLevel,
                            questions: questions,
                          ),
                        );
                        return;
                      }
                      pushScreen(
                        context,
                        LevelListScreen(
                          store: store,
                          title: chapter.title,
                          levels: levels,
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: Icon(_chapterIcon(chapter.kind), size: 34),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chapter.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                chapter.knowledgePoint,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: total == 0 ? 0 : finished / total,
                                minHeight: 10,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ],
                          ),
                        ),
                        Text('$finished/$total'),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }
}

class _SudokuMap extends StatelessWidget {
  const _SudokuMap({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.55,
      children: [
        _SudokuTypeCard(store: store, size: 4, color: const Color(0xFFEDE7F6)),
        _SudokuTypeCard(store: store, size: 6, color: const Color(0xFFD9C7FF)),
        _SudokuTypeCard(store: store, size: 9, color: const Color(0xFFFFF0A8)),
      ],
    );
  }
}

class _SudokuTypeCard extends StatelessWidget {
  const _SudokuTypeCard({
    required this.store,
    required this.size,
    required this.color,
  });

  final AppStore store;
  final int size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final completed = store.progress.completedLevels.contains('S-random-$size');
    final subtitle = switch (size) {
      4 => '入门观察，适合热身',
      6 => '进阶推理，难度提升',
      _ => '侦探大师，完整挑战',
    };
    return SoftCard(
      color: color,
      onTap: () => pushScreen(
        context,
        SudokuScreen(store: store, puzzle: buildRandomSudoku(size)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.grid_on, size: 44, color: Color(0xFF2D2A32)),
              const SizedBox(height: 8),
              Text(
                '$size×$size 随机数独',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              StarRow(count: completed ? 3 : 0),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _chapterIcon(String kind) {
  switch (kind) {
    case 'number':
      return Icons.pin;
    case 'add_sub':
    case 'carry':
    case 'chain':
    case 'vertical_calc':
    case 'multiply_low':
    case 'multiply_high':
    case 'divide':
    case 'mixed':
      return Icons.calculate;
    case 'shape':
      return Icons.category;
    case 'time':
      return Icons.schedule;
    case 'money':
      return Icons.payments;
    case 'pattern':
      return Icons.auto_graph;
    case 'large_number':
      return Icons.looks;
    case 'weight':
      return Icons.scale;
    case 'logic':
      return Icons.psychology;
    case 'pinyin':
      return Icons.record_voice_over;
    case 'hanzi':
      return Icons.draw;
    case 'words_cn':
      return Icons.menu_book;
    case 'reading':
      return Icons.local_library;
    case 'word':
      return Icons.abc;
    case 'phonics':
      return Icons.volume_up;
    case 'dialogue':
      return Icons.chat_bubble;
    default:
      return Icons.flag;
  }
}

Color _chapterColor(String id, Island island) {
  if (island == Island.chinese) {
    final colors = [
      const Color(0xFFFFF8E1),
      const Color(0xFFD7CCC8),
      const Color(0xFFC8E6C9),
      const Color(0xFFFFECB3),
    ];
    return colors[id.codeUnitAt(id.length - 1) % colors.length];
  }
  final colors = [
    const Color(0xFFFFD4A3),
    const Color(0xFFA7F3D0),
    const Color(0xFFBFDBFE),
    const Color(0xFFFBCFE8),
    const Color(0xFFFFF0A8),
    const Color(0xFFD9C7FF),
  ];
  return colors[id.codeUnitAt(id.length - 1) % colors.length];
}
