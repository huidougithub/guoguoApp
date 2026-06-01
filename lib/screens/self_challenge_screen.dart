import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../models/app_models.dart';
import '../services/app_store.dart';
import '../services/audio_service.dart';
import '../services/question_factory.dart';
import '../widgets/parent_gate.dart';
import '../widgets/ui_components.dart';
import 'quiz_screen.dart';
import 'wrong_challenge_screen.dart';

class SelfChallengeScreen extends StatelessWidget {
  const SelfChallengeScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final progress = store.progress;
    final grade = progress.selectedGrade ?? 1;
    final dailyBest = progress.challengeHistory['daily_best'] ?? 0;
    return ExplorerScaffold(
      title: '自我挑战',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 2.2,
          children: [
            _ChallengeTile(
              icon: Icons.today,
              title: '今日挑战',
              subtitle: '数学5题 + 语文3题 + 英语2题，历史最佳 $dailyBest/10',
              color: const Color(0xFFFFF0A8),
              onTap: () {
                final level = LevelDefinition(
                  id: 'daily_challenge',
                  island: Island.math,
                  chapterId: 'DAILY',
                  chapterTitle: '今日挑战',
                  title: '今日挑战',
                  scene: '自我挑战',
                  knowledgePoint: '跨学科综合',
                  levelIndex: grade,
                  generatorKind: 'daily',
                  questionType: 'challenge',
                  gradeMin: 1,
                  gradeMax: 2,
                  bossKind: dailyChallengeBossKind(),
                );
                pushScreen(
                  context,
                  QuizScreen(
                    store: store,
                    level: level,
                    questions: QuestionFactory().buildDailyChallenge(grade),
                    onComplete: store.recordDailyChallenge,
                  ),
                );
              },
            ),
            _ChallengeTile(
              icon: Icons.timer,
              title: '速度之星',
              subtitle: '同一关全对会记录最快用时，已记录 ${progress.bestTimes.length} 项。',
              color: const Color(0xFFA7F3D0),
              onTap: null,
            ),
            _ChallengeTile(
              icon: Icons.local_fire_department,
              title: '连胜纪录',
              subtitle: '当前连续答对 ${progress.winStreak} 题，继续保持会刷新本地纪录。',
              color: const Color(0xFFFFC6D9),
              onTap: null,
            ),
            _ChallengeTile(
              icon: Icons.psychology_alt,
              title: '错题秘境',
              subtitle:
                  '${progress.wrongItems.length}道错题，${progress.wrongItems.length ~/ 5}个挑战。',
              color: const Color(0xFFBFDBFE),
              onTap: () =>
                  pushScreen(context, WrongChallengeScreen(store: store)),
            ),
          ],
        ),
      ),
    );
  }
}

class ParentChallengeScreen extends StatefulWidget {
  const ParentChallengeScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ParentChallengeScreen> createState() => _ParentChallengeScreenState();
}

class _ParentChallengeScreenState extends State<ParentChallengeScreen> {
  final promptController = TextEditingController();
  final answerController = TextEditingController();
  String subject = '综合';
  ParentChallenge? active;
  String? selected;

  @override
  void dispose() {
    promptController.dispose();
    answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenges = widget.store.progress.parentChallenges;
    return ExplorerScaffold(
      title: '家长挑战',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: SoftCard(
                color: const Color(0xFFE3F2FD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('家长录入题目'),
                      onPressed: _showCreateDialog,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: challenges.isEmpty
                          ? const Center(child: Text('还没有家长挑战题。'))
                          : ListView.separated(
                              itemCount: challenges.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final challenge = challenges[index];
                                return ListTile(
                                  tileColor: challenge.completed
                                      ? const Color(0xFFD1FAE5)
                                      : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(
                                      color: Color(0xFF2D2A32),
                                    ),
                                  ),
                                  title: Text(challenge.prompt),
                                  subtitle: Text(challenge.subject),
                                  onTap: () => setState(() {
                                    active = challenge;
                                    selected = null;
                                  }),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 6,
              child: SoftCard(
                color: const Color(0xFFFFFBEB),
                child: active == null
                    ? const Center(
                        child: Text(
                          '选择一道家长挑战题开始。',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    : _activeCard(active!),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeCard(ParentChallenge challenge) {
    final choices = <String>{
      challenge.answer,
      '${challenge.answer}1',
      '再想想',
      '不知道',
    }.toList();
    return Column(
      children: [
        Text(
          challenge.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 4.8,
          children: choices.map((choice) {
            final picked = selected == choice;
            final right = picked && choice == challenge.answer;
            return FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: right
                    ? const Color(0xFF4CAF50)
                    : picked
                    ? const Color(0xFFE57373)
                    : null,
              ),
              onPressed: challenge.completed
                  ? null
                  : () async {
                      setState(() => selected = choice);
                      final ok = choice == challenge.answer;
                      await AudioService.playSfx(
                        ok ? AppSound.correct : AppSound.wrong,
                        enabled: widget.store.progress.settings['sfx'] ?? true,
                      );
                      if (ok) {
                        await widget.store.completeParentChallenge(challenge);
                      }
                      if (mounted) setState(() {});
                    },
              child: Text(choice, style: const TextStyle(fontSize: 22)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _showCreateDialog() async {
    if (!await showParentGate(context)) return;
    if (!mounted) return;
    promptController.clear();
    answerController.clear();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('录入家长挑战'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: subject,
                  items: const [
                    DropdownMenuItem(value: '数学', child: Text('数学')),
                    DropdownMenuItem(value: '语文', child: Text('语文')),
                    DropdownMenuItem(value: '英语', child: Text('英语')),
                    DropdownMenuItem(value: '综合', child: Text('综合')),
                  ],
                  onChanged: (value) => subject = value ?? '综合',
                  decoration: const InputDecoration(labelText: '科目'),
                ),
                TextField(
                  controller: promptController,
                  decoration: const InputDecoration(labelText: '题目'),
                ),
                TextField(
                  controller: answerController,
                  decoration: const InputDecoration(labelText: '正确答案'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final prompt = promptController.text.trim();
                final answer = answerController.text.trim();
                if (prompt.isEmpty || answer.isEmpty) return;
                await widget.store.addParentChallenge(
                  prompt: prompt,
                  answer: answer,
                  subject: subject,
                );
                if (context.mounted) Navigator.of(context).pop();
                if (mounted) setState(() {});
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  const _ChallengeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: color,
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Icon(icon, size: 34, color: const Color(0xFF2D2A32)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
