import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../models/worksheet_models.dart';
import '../services/app_store.dart';
import '../services/worksheet_service.dart';
import '../widgets/ui_components.dart';

class WorksheetPracticeScreen extends StatefulWidget {
  const WorksheetPracticeScreen({
    super.key,
    required this.store,
    required this.catalogItem,
  });

  final AppStore store;
  final WorksheetCatalogItem catalogItem;

  @override
  State<WorksheetPracticeScreen> createState() =>
      _WorksheetPracticeScreenState();
}

class _WorksheetPracticeScreenState extends State<WorksheetPracticeScreen> {
  final WorksheetService service = WorksheetService();
  final Map<String, TextEditingController> controllers = {};

  late Future<void> loadFuture;
  late WorksheetSet worksheet;
  late WorksheetProgress progress;
  int selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    loadFuture = _load();
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExplorerScaffold(
      title: '试卷练习',
      child: FutureBuilder<void>(
        future: loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('练习加载失败：${snapshot.error}'));
          }
          final day = worksheet.days[selectedDayIndex];
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _DayRail(
                  worksheet: worksheet,
                  progress: progress,
                  selectedDayIndex: selectedDayIndex,
                  onSelected: (index) {
                    setState(() => selectedDayIndex = index);
                    _syncControllersFor(worksheet.days[index]);
                  },
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _PracticePanel(
                    day: day,
                    progress: progress,
                    controllerFor: _controllerFor,
                    onAnswerChanged: _setAnswer,
                    onCheck: () => _checkDay(day),
                    onClear: () => _clearDay(day),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _load() async {
    worksheet = await service.loadWorksheet(widget.catalogItem.asset);
    progress = await service.loadProgress(worksheet.id);
    if (worksheet.days.isNotEmpty) {
      _syncControllersFor(worksheet.days.first);
    }
  }

  void _syncControllersFor(WorksheetDay day) {
    for (final question in day.questions) {
      _controllerFor(question.id).text = progress.answers[question.id] ?? '';
    }
  }

  TextEditingController _controllerFor(String id) {
    return controllers.putIfAbsent(id, TextEditingController.new);
  }

  Future<void> _setAnswer(String questionId, String value) async {
    progress.answers[questionId] = value;
    progress.checkedQuestionIds.remove(questionId);
    progress.correctQuestionIds.remove(questionId);
    await service.saveProgress(worksheet.id, progress);
    if (mounted) setState(() {});
  }

  Future<void> _checkDay(WorksheetDay day) async {
    final missedQuestions = <Question>[];
    var correct = 0;
    var total = 0;
    setState(() {
      for (final question in day.questions) {
        final answer = question.answer;
        if (answer == null) continue;
        total += 1;
        final input = _controllerFor(question.id).text.trim();
        progress.answers[question.id] = input;
        progress.checkedQuestionIds.add(question.id);
        if (_normalizeAnswer(input) == _normalizeAnswer(answer)) {
          correct += 1;
          progress.correctQuestionIds.add(question.id);
        } else {
          progress.correctQuestionIds.remove(question.id);
          missedQuestions.add(_toWrongQuestion(question));
        }
      }
    });
    await service.saveProgress(worksheet.id, progress);
    final result = await widget.store.completeWorksheetPractice(
      worksheetId: worksheet.id,
      day: day.day,
      correct: correct,
      total: total,
      missedQuestions: missedQuestions,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_resultTitle(result)),
        content: Text(result.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Question _toWrongQuestion(WorksheetQuestion question) {
    return Question(
      id: 'worksheet:${worksheet.id}:${question.id}',
      subject: '数学',
      knowledgePoint: '试卷练习',
      questionType: question.type,
      prompt: question.prompt,
      answer: question.answer ?? '',
      choices: const [],
      explanation: '来自试卷练习 ${worksheet.title}',
    );
  }

  String _normalizeAnswer(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();

  String _resultTitle(WorksheetCompletionResult result) {
    if (result.total <= 0) return '已检查';
    if (result.stars == 3) return '三星完成';
    if (result.stars > 0) return '练习完成';
    return '继续加油';
  }

  Future<void> _clearDay(WorksheetDay day) async {
    setState(() {
      for (final question in day.questions) {
        _controllerFor(question.id).clear();
        progress.answers.remove(question.id);
        progress.checkedQuestionIds.remove(question.id);
        progress.correctQuestionIds.remove(question.id);
      }
    });
    await service.saveProgress(worksheet.id, progress);
  }
}

class _DayRail extends StatelessWidget {
  const _DayRail({
    required this.worksheet,
    required this.progress,
    required this.selectedDayIndex,
    required this.onSelected,
  });

  final WorksheetSet worksheet;
  final WorksheetProgress progress;
  final int selectedDayIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: SoftCard(
        color: const Color(0xFFFFF8E1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              worksheet.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '${worksheet.days.length} 天 · ${worksheet.questionCount} 题',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: worksheet.days.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final day = worksheet.days[index];
                  final answered = progress.answeredCountFor(day.questions);
                  final selected = index == selectedDayIndex;
                  return FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      backgroundColor: selected
                          ? const Color(0xFFFFD166)
                          : Colors.white,
                      foregroundColor: const Color(0xFF2D2A32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.event_note),
                    label: Text(
                      'Day ${day.day}  $answered/${day.questions.length}',
                    ),
                    onPressed: () => onSelected(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticePanel extends StatelessWidget {
  const _PracticePanel({
    required this.day,
    required this.progress,
    required this.controllerFor,
    required this.onAnswerChanged,
    required this.onCheck,
    required this.onClear,
  });

  final WorksheetDay day;
  final WorksheetProgress progress;
  final TextEditingController Function(String id) controllerFor;
  final Future<void> Function(String questionId, String value) onAnswerChanged;
  final VoidCallback onCheck;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final correct = progress.correctCountFor(day.questions);
    final answered = progress.answeredCountFor(day.questions);
    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day ${day.day}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '$answered/${day.questions.length} 已填写 · '
                      '$correct/${day.autoQuestionCount} 自动批改正确',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt),
                label: const Text('清空本页'),
                onPressed: onClear,
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('检查'),
                onPressed: onCheck,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: day.questions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final question = day.questions[index];
                return _QuestionRow(
                  index: index,
                  question: question,
                  controller: controllerFor(question.id),
                  checked: progress.checkedResultFor(question.id),
                  onChanged: (value) => onAnswerChanged(question.id, value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.index,
    required this.question,
    required this.controller,
    required this.checked,
    required this.onChanged,
  });

  final int index;
  final WorksheetQuestion question;
  final TextEditingController controller;
  final bool? checked;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final borderColor = checked == null
        ? const Color(0xFFE5E7EB)
        : checked!
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.4),
        color: const Color(0xFFF8FAFC),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              '${index + 1}.',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.prompt,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (question.images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: question.images
                        .map(
                          (image) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(image),
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const SizedBox(
                                width: 120,
                                height: 80,
                                child: Center(child: Text('图片加载失败')),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (question.needsManualAnswer)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      '应用题暂不自动批改，可先填写答案给家长检查。',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: TextField(
              controller: controller,
              keyboardType: _keyboardTypeFor(question),
              textAlign: TextAlign.center,
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: '答案',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: checked == null
                ? null
                : Icon(
                    checked! ? Icons.check_circle : Icons.cancel,
                    color: checked!
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
          ),
        ],
      ),
    );
  }

  TextInputType _keyboardTypeFor(WorksheetQuestion question) {
    return switch (question.type) {
      'calculation' || 'blank_equation' => TextInputType.number,
      _ => TextInputType.text,
    };
  }
}
