import 'dart:math';

import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../models/app_models.dart';
import '../services/ai_service.dart';
import '../services/app_store.dart';
import '../services/audio_service.dart';
import '../services/question_factory.dart';
import '../widgets/ui_components.dart';

class WrongChallengeScreen extends StatefulWidget {
  const WrongChallengeScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<WrongChallengeScreen> createState() => _WrongChallengeScreenState();
}

class _WrongChallengeScreenState extends State<WrongChallengeScreen> {
  final aiService = AiService();
  WrongItem? activeItem;
  Question? activeQuestion;
  String message = '有错题就可以练习；每5道错题会形成一个挑战组。';
  bool aiLoading = false;

  @override
  void dispose() {
    aiService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.store.progress.wrongItems;
    final unlockedChallenges = items.isEmpty ? 0 : max(1, items.length ~/ 5);
    return ExplorerScaffold(
      title: '错题秘境',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: SoftCard(
                color: const Color(0xFFFFF8E1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '错题 ${items.length} 道',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text('已解锁 $unlockedChallenges 个挑战关'),
                    const SizedBox(height: 12),
                    Expanded(
                      child: items.isEmpty
                          ? const Center(child: Text('还没有错题，太棒了！'))
                          : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return ListTile(
                                  tileColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(
                                      color: Color(0xFF2D2A32),
                                    ),
                                  ),
                                  title: Text(item.knowledgePoint),
                                  subtitle: Text(
                                    '答错${item.wrongCount}次，连续答对${item.variantCorrectStreak}/3',
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'AI讲解',
                                    icon: aiLoading && activeItem == item
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                            ),
                                          )
                                        : const Icon(Icons.auto_awesome),
                                    onPressed: aiLoading
                                        ? null
                                        : () => _explainWithAi(item),
                                  ),
                                  onTap: () => _start(item),
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
              child: activeQuestion == null
                  ? SoftCard(
                      color: const Color(0xFFFFC6D9),
                      child: Center(
                        child: SingleChildScrollView(
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              height: 1.45,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    )
                  : _ChallengeCard(
                      question: activeQuestion!,
                      message: message,
                      onAnswer: _answer,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _start(WrongItem item) {
    setState(() {
      activeItem = item;
      activeQuestion = QuestionFactory().buildVariant(item);
      message = '变式题来了，连续答对3次就能移出错题本。';
    });
  }

  Future<void> _explainWithAi(WrongItem item) async {
    final question = item.originalQuestion;
    setState(() {
      activeItem = item;
      activeQuestion = null;
      aiLoading = true;
      message = '果果正在看这道错题...';
    });
    try {
      final result = await aiService.explainWrongItem(
        subject: question.subject,
        question: question.prompt,
        studentAnswer: '曾答错',
        correctAnswer: question.answer,
        knowledgePoint: item.knowledgePoint,
        gradeLabel: gradeName(normalizeGradeCode(widget.store.progress.selectedGrade)),
      );
      if (!mounted) return;
      setState(() {
        message = result.explanation;
      });
    } on AiServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        message = error.statusCode == 503
            ? 'AI 服务还没有配置 DeepSeek API Key。配置完成后果果就能讲题。'
            : '果果暂时没连上 AI 服务：${error.message}';
      });
    } finally {
      if (mounted) {
        setState(() => aiLoading = false);
      }
    }
  }

  Future<void> _answer(String choice) async {
    final item = activeItem;
    final question = activeQuestion;
    if (item == null || question == null) return;
    final ok = choice == question.answer;
    await widget.store.recordWrongChallenge(item: item, isCorrect: ok);
    await AudioService.playSfx(
      ok ? AppSound.correct : AppSound.wrong,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
    setState(() {
      message = ok ? '答对了！再稳住几次。' : '没关系，这次我们把步骤看慢一点。';
      activeQuestion = widget.store.progress.wrongItems.contains(item)
          ? QuestionFactory().buildVariant(item)
          : null;
      activeItem = widget.store.progress.wrongItems.contains(item)
          ? item
          : null;
    });
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.question,
    required this.message,
    required this.onAnswer,
  });

  final Question question;
  final String message;
  final void Function(String choice) onAnswer;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: const Color(0xFFFFFBEB),
      child: Column(
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Text(
                question.prompt,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 4.8,
            children: question.choices.map((choice) {
              return FilledButton(
                onPressed: () => onAnswer(choice),
                child: Text(choice, style: const TextStyle(fontSize: 24)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
