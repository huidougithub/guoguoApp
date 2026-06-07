import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../models/app_models.dart';
import '../models/worksheet_models.dart';
import '../services/app_store.dart';
import '../services/worksheet_service.dart';

class WorksheetPracticeScreen extends StatefulWidget {
  const WorksheetPracticeScreen({
    super.key,
    this.asset,
    this.catalogItem,
    required this.store,
  }) : assert(asset != null || catalogItem != null);

  final String? asset;
  final WorksheetCatalogItem? catalogItem;
  final AppStore store;

  @override
  State<WorksheetPracticeScreen> createState() =>
      _WorksheetPracticeScreenState();
}

class _WorksheetPracticeScreenState extends State<WorksheetPracticeScreen> {
  final WorksheetService _service = WorksheetService();
  late Future<void> _loadFuture;
  late WorksheetSet _worksheet;
  late WorksheetProgress _progress;
  int _selectedDayIndex = 0;
  String? _selectedQuestionId;
  final Map<String, GlobalKey> _questionKeys = {};

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<void> _load() async {
    final worksheet = await _service.loadWorksheet(
      widget.asset ?? widget.catalogItem!.asset,
    );
    final progress = await _service.loadProgress(worksheet.id);
    _worksheet = worksheet;
    _progress = progress;
    if (worksheet.days.isNotEmpty &&
        worksheet.days.first.questions.isNotEmpty) {
      _selectedQuestionId = _firstPracticeQuestion(worksheet.days.first)?.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _WorksheetBackdrop(
        child: FutureBuilder<void>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_worksheet.days.isEmpty) {
              return const Center(child: Text('这套练习册还没有题目。'));
            }
            final day = _worksheet.days[_selectedDayIndex];
            final pet = petById(widget.store.progress.selectedPet ?? 'fifi');
            final isMathWorksheet = _worksheet.subject == 'math';
            final parentReviewMode =
                widget.store.progress.settings['parentReview'] ?? false;
            return SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1360),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 300,
                          child: _WorksheetSidePanel(
                            worksheet: _worksheet,
                            progress: _progress,
                            selectedDayIndex: _selectedDayIndex,
                            pet: pet,
                            isMathWorksheet: isMathWorksheet,
                            onBack: () => Navigator.of(context).pop(),
                            onSelectDay: (index) {
                              final nextDay = _worksheet.days[index];
                              final firstPracticeQuestion =
                                  _firstPracticeQuestion(nextDay);
                              setState(() {
                                _selectedDayIndex = index;
                                _selectedQuestionId = firstPracticeQuestion?.id;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _WorksheetWorkArea(
                            day: day,
                            progress: _progress,
                            selectedQuestionId: _selectedQuestionId,
                            isMathWorksheet: isMathWorksheet,
                            parentReviewMode: parentReviewMode,
                            questionKeyFor: _questionKeyFor,
                            onSelectQuestion: (id) {
                              setState(() => _selectedQuestionId = id);
                            },
                            onDigit: _appendDigitToSelected,
                            onBackspace: _backspaceSelectedAnswer,
                            onClearSelected: _clearSelectedAnswer,
                            onOpenHandwriting: (id) =>
                                _openHandwritingPractice(day, questionId: id),
                            onPreviousQuestion: () =>
                                _selectPreviousQuestion(day),
                            onNextQuestion: () => _selectNextQuestion(day),
                            onMarkSelectedCorrect: () =>
                                _markSelectedQuestion(day, true),
                            onMarkSelectedWrong: () =>
                                _markSelectedQuestion(day, false),
                            onCheck: isMathWorksheet
                                ? () => _checkDay(day)
                                : () => _markDayComplete(day),
                            onClearDay: () => _clearDay(day),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _appendDigitToSelected(String digit) async {
    final id = _selectedQuestionId;
    if (id == null) return;
    final current = _progress.answers[id] ?? '';
    await _setAnswer(id, '$current$digit');
  }

  Future<void> _backspaceSelectedAnswer() async {
    final id = _selectedQuestionId;
    if (id == null) return;
    final current = _progress.answers[id] ?? '';
    if (current.isEmpty) return;
    await _setAnswer(id, current.substring(0, current.length - 1));
  }

  Future<void> _clearSelectedAnswer() async {
    final id = _selectedQuestionId;
    if (id == null) return;
    await _setAnswer(id, '');
  }

  Future<void> _markSelectedQuestion(WorksheetDay day, bool isCorrect) async {
    final id = _selectedQuestionId;
    if (id == null) return;
    final question = day.questions.cast<WorksheetQuestion?>().firstWhere(
      (question) => question?.id == id,
      orElse: () => null,
    );
    if (question == null || !question.countsForProgress) return;

    _progress.checkedQuestionIds.add(id);
    if (isCorrect) {
      _progress.correctQuestionIds.add(id);
    } else {
      _progress.correctQuestionIds.remove(id);
    }
    await _service.saveProgress(_worksheet.id, _progress);
    await _tryGrantPerfectWorksheetDiamond();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openHandwritingPractice(
    WorksheetDay day, {
    String? questionId,
  }) async {
    final id = questionId ?? _selectedQuestionId;
    if (id == null) return;
    final question = day.questions.cast<WorksheetQuestion?>().firstWhere(
      (question) => question?.id == id,
      orElse: () => null,
    );
    if (question == null) return;
    if (question.isDisplayOnly) return;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _HandwritingPracticeDialog(
        question: question,
        initialInk: _progress.answers[id] ?? '',
      ),
    );
    if (result == null) return;
    await _setAnswer(id, result);
  }

  void _selectPreviousQuestion(WorksheetDay day) {
    final practiceQuestions = day.questions
        .where((question) => question.countsForProgress)
        .toList();
    if (practiceQuestions.isEmpty) return;
    final currentIndex = practiceQuestions.indexWhere(
      (question) => question.id == _selectedQuestionId,
    );
    final previousIndex = currentIndex <= 0
        ? practiceQuestions.length - 1
        : currentIndex - 1;
    final previousId = practiceQuestions[previousIndex].id;
    setState(() => _selectedQuestionId = previousId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollQuestionIntoView(previousId);
    });
  }

  void _selectNextQuestion(WorksheetDay day) {
    final practiceQuestions = day.questions
        .where((question) => question.countsForProgress)
        .toList();
    if (practiceQuestions.isEmpty) return;
    final currentIndex = practiceQuestions.indexWhere(
      (question) => question.id == _selectedQuestionId,
    );
    final nextIndex = currentIndex < 0
        ? 0
        : (currentIndex + 1) % practiceQuestions.length;
    final nextId = practiceQuestions[nextIndex].id;
    setState(() => _selectedQuestionId = nextId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollQuestionIntoView(nextId);
    });
  }

  GlobalKey _questionKeyFor(String questionId) {
    return _questionKeys.putIfAbsent(questionId, GlobalKey.new);
  }

  void _scrollQuestionIntoView(String questionId) {
    final itemContext = _questionKeys[questionId]?.currentContext;
    if (itemContext == null) return;
    Scrollable.ensureVisible(
      itemContext,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: .45,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  Future<void> _setAnswer(String questionId, String value) async {
    final trimmed = value.trim();
    _progress.answers[questionId] = trimmed;
    _progress.checkedQuestionIds.remove(questionId);
    _progress.correctQuestionIds.remove(questionId);
    await _service.saveProgress(_worksheet.id, _progress);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _markDayComplete(WorksheetDay day) async {
    for (final question in day.questions) {
      if (!question.countsForProgress) continue;
      _progress.answers[question.id] = '已练习';
      _progress.checkedQuestionIds.remove(question.id);
      _progress.correctQuestionIds.remove(question.id);
    }
    await _service.saveProgress(_worksheet.id, _progress);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('本页已标记完成，继续保持哦！')));
  }

  Future<void> _clearDay(WorksheetDay day) async {
    for (final question in day.questions) {
      _progress.answers.remove(question.id);
      _progress.checkedQuestionIds.remove(question.id);
      _progress.correctQuestionIds.remove(question.id);
    }
    await _service.saveProgress(_worksheet.id, _progress);
    if (!mounted) return;
    final firstPracticeQuestion = _firstPracticeQuestion(day);
    setState(() {
      _selectedQuestionId = firstPracticeQuestion?.id;
    });
  }

  WorksheetQuestion? _firstPracticeQuestion(WorksheetDay day) {
    for (final question in day.questions) {
      if (question.countsForProgress) return question;
    }
    return null;
  }

  Future<void> _checkDay(WorksheetDay day) async {
    var total = 0;
    var correct = 0;
    final missedQuestions = <Question>[];
    for (final question in day.questions) {
      if (!question.canAutoCheck) continue;
      final input = (_progress.answers[question.id] ?? '').trim();
      _progress.answers[question.id] = input;
      _progress.checkedQuestionIds.add(question.id);
      final expected = question.answer ?? question.answerSource;
      final isCorrect = _normalizeAnswer(input) == _normalizeAnswer(expected);
      if (isCorrect) {
        correct += 1;
        _progress.correctQuestionIds.add(question.id);
      } else {
        _progress.correctQuestionIds.remove(question.id);
        missedQuestions.add(_toWrongQuestion(question));
      }
      total += 1;
    }

    await _service.saveProgress(_worksheet.id, _progress);
    await widget.store.completeWorksheetPractice(
      worksheetId: _worksheet.id,
      day: day.day,
      correct: correct,
      total: total,
      missedQuestions: missedQuestions,
    );
    await _tryGrantPerfectWorksheetDiamond();

    if (!mounted) return;
    setState(() {});
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_resultTitle(correct, total)),
          content: Text(
            total == 0
                ? '这一页暂时没有可自动批改的题目。'
                : '本页自动批改 $total 题，答对 $correct 题。错误题目已自动加入错题秘境。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  String _normalizeAnswer(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  String _resultTitle(int correct, int total) {
    if (total == 0) return '先完成可批改题目';
    if (correct == total) return '太棒了，全都答对！';
    if (correct >= total * 0.8) return '很接近满分啦';
    return '继续练习会更稳';
  }

  Future<void> _tryGrantPerfectWorksheetDiamond() async {
    final questions = _worksheet.days
        .expand((day) => day.questions)
        .where((question) => question.countsForProgress)
        .toList();
    final total = questions.length;
    final correct = questions
        .where((question) => _progress.correctQuestionIds.contains(question.id))
        .length;
    final granted = await widget.store.grantWorksheetDiamondIfPerfect(
      worksheetId: _worksheet.id,
      correct: correct,
      total: total,
    );
    if (!mounted || !granted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('整套试卷全部做对，获得1颗钻石！')));
  }

  Question _toWrongQuestion(WorksheetQuestion question) {
    return Question(
      id: 'worksheet_${question.id}_${DateTime.now().millisecondsSinceEpoch}',
      subject: '数学',
      knowledgePoint: '试卷练习',
      questionType: question.type,
      prompt: question.prompt,
      choices: const [],
      answer: question.answer ?? question.answerSource,
      hint: '回到试卷练习里再看一看这类题的条件。',
      explanation: (question.answer ?? '').isEmpty
          ? '试卷练习题'
          : '正确答案：${question.answer}',
      variantSeed: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class _WorksheetSidePanel extends StatelessWidget {
  const _WorksheetSidePanel({
    required this.worksheet,
    required this.progress,
    required this.selectedDayIndex,
    required this.pet,
    required this.isMathWorksheet,
    required this.onBack,
    required this.onSelectDay,
  });

  final WorksheetSet worksheet;
  final WorksheetProgress progress;
  final int selectedDayIndex;
  final PetDefinition pet;
  final bool isMathWorksheet;
  final VoidCallback onBack;
  final ValueChanged<int> onSelectDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 74,
          child: Row(
            children: [
              _CircleIconButton(icon: Icons.arrow_back, onTap: onBack),
              const SizedBox(width: 16),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD9B98B)),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  size: 30,
                  color: Color(0xFF2D91D0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '试卷练习',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF4B260F),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _PaperCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/pets/${pet.id}.png',
                      width: 86,
                      height: 86,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/pets/fifi.png',
                        width: 86,
                        height: 86,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            worksheet.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF402111),
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${worksheet.questionCount}题 · 每日更新',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7B5B43),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.separated(
                    itemCount: worksheet.days.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final day = worksheet.days[index];
                      final selected = selectedDayIndex == index;
                      final answered = progress.answeredCountFor(day.questions);
                      return _DayButton(
                        day: day,
                        answered: answered,
                        total: isMathWorksheet
                            ? day.autoQuestionCount
                            : day.practiceQuestionCount,
                        selected: selected,
                        onTap: () => onSelectDay(index),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE6C99E)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 35,
                        color: Color(0xFFC47C1A),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '完成整天试题可获得奖励，坚持练习效果更好哦！',
                          style: TextStyle(
                            height: 1.35,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6B4423),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WorksheetWorkArea extends StatelessWidget {
  const _WorksheetWorkArea({
    required this.day,
    required this.progress,
    required this.selectedQuestionId,
    required this.isMathWorksheet,
    required this.parentReviewMode,
    required this.questionKeyFor,
    required this.onSelectQuestion,
    required this.onDigit,
    required this.onBackspace,
    required this.onClearSelected,
    required this.onOpenHandwriting,
    required this.onPreviousQuestion,
    required this.onNextQuestion,
    required this.onMarkSelectedCorrect,
    required this.onMarkSelectedWrong,
    required this.onCheck,
    required this.onClearDay,
  });

  final WorksheetDay day;
  final WorksheetProgress progress;
  final String? selectedQuestionId;
  final bool isMathWorksheet;
  final bool parentReviewMode;
  final GlobalKey Function(String questionId) questionKeyFor;
  final ValueChanged<String> onSelectQuestion;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClearSelected;
  final ValueChanged<String> onOpenHandwriting;
  final VoidCallback onPreviousQuestion;
  final VoidCallback onNextQuestion;
  final VoidCallback onMarkSelectedCorrect;
  final VoidCallback onMarkSelectedWrong;
  final VoidCallback onCheck;
  final VoidCallback onClearDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _QuestionPaper(
            day: day,
            progress: progress,
            selectedQuestionId: selectedQuestionId,
            isMathWorksheet: isMathWorksheet,
            questionKeyFor: questionKeyFor,
            onSelectQuestion: onSelectQuestion,
            onOpenHandwriting: onOpenHandwriting,
            onCheck: onCheck,
            onClearDay: onClearDay,
          ),
        ),
        const SizedBox(height: 14),
        if (isMathWorksheet)
          _MathKeypad(
            onDigit: onDigit,
            onBackspace: onBackspace,
            onClear: onClearSelected,
            onNext: onNextQuestion,
          )
        else
          _ManualPracticeBar(
            onPrevious: onPreviousQuestion,
            onClear: onClearSelected,
            onNext: onNextQuestion,
            parentReviewMode: parentReviewMode,
            onCorrect: onMarkSelectedCorrect,
            onWrong: onMarkSelectedWrong,
          ),
      ],
    );
  }
}

class _QuestionPaper extends StatelessWidget {
  const _QuestionPaper({
    required this.day,
    required this.progress,
    required this.selectedQuestionId,
    required this.isMathWorksheet,
    required this.questionKeyFor,
    required this.onSelectQuestion,
    required this.onOpenHandwriting,
    required this.onCheck,
    required this.onClearDay,
  });

  final WorksheetDay day;
  final WorksheetProgress progress;
  final String? selectedQuestionId;
  final bool isMathWorksheet;
  final GlobalKey Function(String questionId) questionKeyFor;
  final ValueChanged<String> onSelectQuestion;
  final ValueChanged<String> onOpenHandwriting;
  final VoidCallback onCheck;
  final VoidCallback onClearDay;

  @override
  Widget build(BuildContext context) {
    final answered = progress.answeredCountFor(day.questions);
    final total = isMathWorksheet
        ? day.autoQuestionCount
        : day.practiceQuestionCount;
    final entries = _buildListEntries();
    return _PaperCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9B7CFF), Color(0xFF6E55E8)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6E55E8).withValues(alpha: .25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 18),
              Text(
                'Day ${day.day}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF3A1F0D),
                ),
              ),
              const SizedBox(width: 26),
              Text(
                '$answered/$total 已填写',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF7C4825),
                ),
              ),
              const Spacer(),
              _TopActionButton(
                label: '清空答题',
                icon: Icons.cleaning_services,
                onTap: onClearDay,
              ),
              const SizedBox(width: 12),
              _TopActionButton(
                label: isMathWorksheet ? '检查' : '完成本页',
                icon: isMathWorksheet
                    ? Icons.check_rounded
                    : Icons.task_alt_rounded,
                onTap: onCheck,
                filled: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = entries[index];
                if (entry is _QuestionSectionEntry) {
                  return _QuestionSectionHeader(
                    title: entry.title,
                    subtitle: entry.subtitle,
                  );
                }
                final questionEntry = entry as _QuestionItemEntry;
                final question = questionEntry.question;
                if (question.isDisplayOnly) {
                  return _QuestionExampleCard(question: question);
                }
                return KeyedSubtree(
                  key: questionKeyFor(question.id),
                  child: _QuestionRow(
                    index: questionEntry.index!,
                    question: question,
                    answer: progress.answers[question.id] ?? '',
                    checkedResult: progress.checkedResultFor(question.id),
                    manualMode: !isMathWorksheet,
                    selected: selectedQuestionId == question.id,
                    onTap: () => onSelectQuestion(question.id),
                    onAnswerTap: () {
                      onSelectQuestion(question.id);
                      if (!isMathWorksheet) {
                        onOpenHandwriting(question.id);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<_QuestionListEntry> _buildListEntries() {
    final entries = <_QuestionListEntry>[];
    var lastSection = '';
    var questionIndex = 0;
    for (final question in day.questions) {
      final section = question.sectionTitle.trim();
      if (!isMathWorksheet && section.isNotEmpty && section != lastSection) {
        entries.add(_QuestionSectionEntry(section, _sectionSubtitle(section)));
        lastSection = section;
      }
      final index = question.countsForProgress ? ++questionIndex : null;
      entries.add(_QuestionItemEntry(index, question));
    }
    return entries;
  }

  String _sectionSubtitle(String section) {
    final count = day.questions
        .where(
          (question) =>
              question.sectionTitle.trim() == section &&
              question.countsForProgress,
        )
        .length;
    if (count == 0) return '示例';
    return count <= 1 ? '1个练习' : '$count个练习';
  }
}

sealed class _QuestionListEntry {
  const _QuestionListEntry();
}

class _QuestionSectionEntry extends _QuestionListEntry {
  const _QuestionSectionEntry(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

class _QuestionItemEntry extends _QuestionListEntry {
  const _QuestionItemEntry(this.index, this.question);

  final int? index;
  final WorksheetQuestion question;
}

class _QuestionSectionHeader extends StatelessWidget {
  const _QuestionSectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDBD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5B155), width: 1.4),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.menu_book_rounded,
            color: Color(0xFF8B4B19),
            size: 24,
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF5B3216),
            ),
          ),
          const Spacer(),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF8A6544),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionExampleCard extends StatelessWidget {
  const _QuestionExampleCard({required this.question});

  final WorksheetQuestion question;

  @override
  Widget build(BuildContext context) {
    final label = question.type.trim().toLowerCase() == 'example'
        ? '看例子'
        : '提示';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7DF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9C57F), width: 1.3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE3A3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              color: Color(0xFF8B4B19),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF8B4B19),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  question.visiblePrompt,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 22,
                    height: 1.32,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF4A2C17),
                  ),
                ),
              ],
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
    required this.answer,
    required this.checkedResult,
    required this.manualMode,
    required this.selected,
    required this.onTap,
    required this.onAnswerTap,
  });

  final int index;
  final WorksheetQuestion question;
  final String answer;
  final bool? checkedResult;
  final bool manualMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onAnswerTap;

  @override
  Widget build(BuildContext context) {
    final stateColor = switch (checkedResult) {
      true => const Color(0xFFF1FAE8),
      false => const Color(0xFFFFD4D9),
      null when selected => const Color(0xFFFFF9D9),
      _ => const Color(0xFFFFFEFA),
    };
    final borderColor = switch (checkedResult) {
      true => const Color(0xFFC8DFA0),
      false => const Color(0xFFE5485C),
      null when selected => const Color(0xFF2E91FF),
      _ => const Color(0xFFE2D6C7),
    };
    final numberColor = switch (checkedResult) {
      true => const Color(0xFFDFF1C2),
      false => const Color(0xFFFF9FAB),
      null when selected => const Color(0xFFFFF4CA),
      _ => const Color(0xFFF8EEDB),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: stateColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: selected ? 2.2 : 1.2),
            boxShadow: checkedResult == false
                ? [
                    BoxShadow(
                      color: const Color(0xFFE5485C).withValues(alpha: .2),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2E91FF).withValues(alpha: .16),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: numberColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: checkedResult == false
                        ? const Color(0xFFE02020)
                        : const Color(0xFF3C2A1A),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      question.visiblePrompt,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: manualMode ? 24 : 18,
                        height: 1.28,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF27190F),
                      ),
                    ),
                    if (question.images.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: question.images
                            .map((image) => _QuestionImage(image: image))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _AnswerSlot(
                answer: answer,
                selected: selected,
                manualMode: manualMode,
                onTap: onAnswerTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerSlot extends StatelessWidget {
  const _AnswerSlot({
    required this.answer,
    required this.selected,
    required this.manualMode,
    required this.onTap,
  });

  final String answer;
  final bool selected;
  final bool manualMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (manualMode) {
      return _HandwritingPreview(ink: answer, selected: selected, onTap: onTap);
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 150,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected ? const Color(0xFF2E91FF) : const Color(0xFFC9AC8A),
          width: selected ? 1.8 : 1.2,
        ),
      ),
      child: answer.isEmpty && selected
          ? Container(width: 2, height: 24, color: const Color(0xFF1F1F1F))
          : Text(
              answer.isEmpty ? '' : answer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: checkedAnswerColor(answer),
              ),
            ),
    );
  }

  Color checkedAnswerColor(String value) {
    return value.isEmpty ? Colors.black38 : const Color(0xFF26190E);
  }
}

List<List<Offset>> _decodeInkStrokes(String ink) {
  if (!ink.startsWith('ink:')) return const [];
  try {
    final raw = jsonDecode(ink.substring(4)) as List<dynamic>;
    return raw
        .map((strokeRaw) {
          final points = <Offset>[];
          for (final pointRaw in strokeRaw as List<dynamic>) {
            final point = pointRaw as List<dynamic>;
            if (point.length < 2) continue;
            points.add(
              Offset(
                (point[0] as num).toDouble().clamp(0, 1),
                (point[1] as num).toDouble().clamp(0, 1),
              ),
            );
          }
          return points;
        })
        .where((stroke) => stroke.isNotEmpty)
        .toList();
  } catch (_) {
    return const [];
  }
}

class _HandwritingPreview extends StatelessWidget {
  const _HandwritingPreview({
    required this.ink,
    required this.selected,
    required this.onTap,
  });

  final String ink;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strokes = _decodeInkStrokes(ink);
    return Semantics(
      button: true,
      label: strokes.isEmpty ? '打开手写练习' : '查看并修改手写内容',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 168,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFEFA),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: selected
                    ? const Color(0xFF2E91FF)
                    : const Color(0xFFC9AC8A),
                width: selected ? 1.9 : 1.2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: CustomPaint(
                painter: _HandwritingPreviewPainter(strokes: strokes),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HandwritingPreviewPainter extends CustomPainter {
  const _HandwritingPreviewPainter({required this.strokes});

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFE9D6BE);
    final guide = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFDDBD94);
    final inkPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2.6
      ..color = const Color(0xFF1E5AAE);

    final cols = 4;
    final cellW = size.width / cols;
    for (var c = 1; c < cols; c++) {
      final x = c * cellW;
      canvas.drawLine(Offset(x, 4), Offset(x, size.height - 4), grid);
    }
    canvas.drawLine(
      Offset(4, size.height / 2),
      Offset(size.width - 4, size.height / 2),
      guide,
    );

    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(_denormalize(stroke.first, size), 1.8, inkPaint);
        continue;
      }
      final path = Path();
      for (var i = 0; i < stroke.length; i++) {
        final point = _denormalize(stroke[i], size);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(path, inkPaint);
    }
  }

  Offset _denormalize(Offset point, Size size) {
    return Offset(point.dx * size.width, point.dy * size.height);
  }

  @override
  bool shouldRepaint(covariant _HandwritingPreviewPainter oldDelegate) {
    return true;
  }
}

class _ManualPracticeBar extends StatelessWidget {
  const _ManualPracticeBar({
    required this.onPrevious,
    required this.onClear,
    required this.onNext,
    required this.parentReviewMode,
    required this.onCorrect,
    required this.onWrong,
  });

  final VoidCallback onPrevious;
  final VoidCallback onClear;
  final VoidCallback onNext;
  final bool parentReviewMode;
  final VoidCallback onCorrect;
  final VoidCallback onWrong;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ToolButton(
          label: '上一题',
          icon: Icons.arrow_back,
          onTap: onPrevious,
          compact: false,
        ),
        const SizedBox(width: 14),
        _ToolButton(
          label: '擦除',
          icon: Icons.delete_outline,
          onTap: onClear,
          compact: false,
        ),
        const SizedBox(width: 14),
        _PressableSurface(
          width: 150,
          height: 58,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFA83A), Color(0xFFFF7A18)],
          ),
          borderColor: const Color(0xFFB95410),
          onTap: onNext,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '下一题',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, color: Colors.white, size: 25),
            ],
          ),
        ),
        if (parentReviewMode) ...[
          const SizedBox(width: 24),
          _ReviewButton(
            label: '对',
            icon: Icons.check_rounded,
            color: const Color(0xFF4CAF50),
            onTap: onCorrect,
          ),
          const SizedBox(width: 12),
          _ReviewButton(
            label: '错',
            icon: Icons.close_rounded,
            color: const Color(0xFFE5485C),
            onTap: onWrong,
          ),
        ],
      ],
    );
  }
}

class _ReviewButton extends StatelessWidget {
  const _ReviewButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableSurface(
      width: 88,
      height: 58,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: .88), color],
      ),
      borderColor: Color.alphaBlend(Colors.black.withValues(alpha: .18), color),
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HandwritingPracticeDialog extends StatefulWidget {
  const _HandwritingPracticeDialog({
    required this.question,
    required this.initialInk,
  });

  final WorksheetQuestion question;
  final String initialInk;

  @override
  State<_HandwritingPracticeDialog> createState() =>
      _HandwritingPracticeDialogState();
}

class _HandwritingPracticeDialogState
    extends State<_HandwritingPracticeDialog> {
  final List<List<Offset>> _strokes = [];

  @override
  void initState() {
    super.initState();
    _loadInitialInk();
  }

  void _loadInitialInk() {
    _strokes.addAll(_decodeInkStrokes(widget.initialInk));
  }

  @override
  Widget build(BuildContext context) {
    final viewSize = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: viewSize.width * .92,
          maxHeight: viewSize.height * .9,
        ),
        child: _PaperCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE3A3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD59A3A)),
                    ),
                    child: const Icon(
                      Icons.draw_rounded,
                      color: Color(0xFF8B4B19),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '手写练习',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF4B260F),
                              ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '认真写一写，保存后这道题会记录为已书写。',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7B5B43),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: '关闭',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 110),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5C89E)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.question.visiblePrompt,
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D1B10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _HandwritingBoard(
                  strokes: _strokes,
                  onChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _ToolButton(
                    label: '撤销',
                    icon: Icons.undo,
                    compact: false,
                    onTap: _strokes.isEmpty
                        ? () {}
                        : () {
                            setState(() => _strokes.removeLast());
                          },
                  ),
                  const SizedBox(width: 12),
                  _ToolButton(
                    label: '清空',
                    icon: Icons.delete_outline,
                    compact: false,
                    onTap: () => setState(_strokes.clear),
                  ),
                  const Spacer(),
                  _PressableSurface(
                    width: 178,
                    height: 58,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF76C654), Color(0xFF3E9B31)],
                    ),
                    borderColor: const Color(0xFF2C7E22),
                    onTap: _saveInk,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '保存书写',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveInk() {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('先在田字格里写一写，再保存哦。')));
      return;
    }
    final encoded = jsonEncode(
      _strokes
          .map(
            (stroke) => stroke
                .map(
                  (point) => [
                    double.parse(point.dx.toStringAsFixed(4)),
                    double.parse(point.dy.toStringAsFixed(4)),
                  ],
                )
                .toList(),
          )
          .toList(),
    );
    Navigator.of(context).pop('ink:$encoded');
  }
}

class _HandwritingBoard extends StatelessWidget {
  const _HandwritingBoard({required this.strokes, required this.onChanged});

  final List<List<Offset>> strokes;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            strokes.add([_normalize(details.localPosition, constraints)]);
            onChanged();
          },
          onPanUpdate: (details) {
            if (strokes.isEmpty) {
              strokes.add([]);
            }
            strokes.last.add(_normalize(details.localPosition, constraints));
            onChanged();
          },
          onPanEnd: (_) => onChanged(),
          child: CustomPaint(
            painter: _HandwritingBoardPainter(strokes: strokes),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  Offset _normalize(Offset point, BoxConstraints constraints) {
    final width = constraints.maxWidth <= 0 ? 1.0 : constraints.maxWidth;
    final height = constraints.maxHeight <= 0 ? 1.0 : constraints.maxHeight;
    return Offset(
      (point.dx / width).clamp(0.0, 1.0),
      (point.dy / height).clamp(0.0, 1.0),
    );
  }
}

class _HandwritingBoardPainter extends CustomPainter {
  const _HandwritingBoardPainter({required this.strokes});

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..isAntiAlias = true
      ..color = const Color(0xFFFFFDF8);
    final border = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFC6A178);
    final grid = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFE6D4BE);
    final guide = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFFDAB88E);
    final ink = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 5.2
      ..color = const Color(0xFF2A211B);

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );
    canvas.drawRRect(rect, bg);

    final rows = size.height > 360 ? 3 : 2;
    final cols = size.width > 780 ? 6 : 4;
    final cellW = size.width / cols;
    final cellH = size.height / rows;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final left = c * cellW;
        final top = r * cellH;
        final cell = Rect.fromLTWH(left, top, cellW, cellH);
        canvas.drawRect(cell, grid);
        canvas.drawLine(
          Offset(left + cellW / 2, top),
          Offset(left + cellW / 2, top + cellH),
          guide,
        );
        canvas.drawLine(
          Offset(left, top + cellH / 2),
          Offset(left + cellW, top + cellH / 2),
          guide,
        );
      }
    }

    for (final stroke in strokes) {
      if (stroke.length == 1) {
        final p = _denormalize(stroke.first, size);
        canvas.drawCircle(p, 2.8, ink..style = PaintingStyle.fill);
        ink.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path();
      for (var i = 0; i < stroke.length; i++) {
        final p = _denormalize(stroke[i], size);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, ink);
    }
    canvas.drawRRect(rect.deflate(1), border);
  }

  Offset _denormalize(Offset point, Size size) {
    return Offset(point.dx * size.width, point.dy * size.height);
  }

  @override
  bool shouldRepaint(covariant _HandwritingBoardPainter oldDelegate) {
    return true;
  }
}

class _MathKeypad extends StatelessWidget {
  const _MathKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onNext,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 850;
        final digitSize = compact ? const Size(70, 50) : const Size(86, 56);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final digit in const ['1', '2', '3', '4', '5'])
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _DigitButton(
                          label: digit,
                          size: digitSize,
                          onTap: () => onDigit(digit),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final digit in const ['6', '7', '8', '9', '0'])
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _DigitButton(
                          label: digit,
                          size: digitSize,
                          onTap: () => onDigit(digit),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SizedBox(width: compact ? 10 : 20),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToolButton(
                  label: '擦除',
                  icon: Icons.backspace_outlined,
                  onTap: onBackspace,
                  compact: compact,
                ),
                const SizedBox(height: 12),
                _ToolButton(
                  label: '清空',
                  icon: Icons.delete_outline,
                  onTap: onClear,
                  compact: compact,
                ),
              ],
            ),
            SizedBox(width: compact ? 10 : 20),
            _NextButton(onTap: onNext, compact: compact),
          ],
        );
      },
    );
  }
}

class _DigitButton extends StatelessWidget {
  const _DigitButton({
    required this.label,
    required this.size,
    required this.onTap,
  });

  final String label;
  final Size size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableSurface(
      width: size.width,
      height: size.height,
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFA85E28), Color(0xFF7E3F16)],
      ),
      borderColor: const Color(0xFF6E3212),
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _PressableSurface(
      width: compact ? 116 : 138,
      height: compact ? 50 : 56,
      color: const Color(0xFFFFFCF6),
      borderColor: const Color(0xFFC8A887),
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF7C3E18), size: 22),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7C3E18),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.onTap, required this.compact});

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _PressableSurface(
      width: compact ? 138 : 170,
      height: compact ? 112 : 124,
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFA83A), Color(0xFFFF7A18)],
      ),
      borderColor: const Color(0xFFB95410),
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '下一题',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, color: Colors.white, size: 30),
        ],
      ),
    );
  }
}

class _PressableSurface extends StatelessWidget {
  const _PressableSurface({
    required this.width,
    required this.height,
    required this.borderColor,
    required this.onTap,
    required this.child,
    this.color,
    this.gradient,
  });

  final double width;
  final double height;
  final Color borderColor;
  final VoidCallback onTap;
  final Widget child;
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .16),
                blurRadius: 0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: .08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            gradient: filled
                ? const LinearGradient(
                    colors: [Color(0xFF76C654), Color(0xFF3E9B31)],
                  )
                : null,
            color: filled ? null : const Color(0xFFFFFCF8),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: filled ? const Color(0xFF2C7E22) : const Color(0xFFC8A887),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: filled ? Colors.white : const Color(0xFF7C3E18),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.white : const Color(0xFF7C3E18),
                  fontSize: 17,
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

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.day,
    required this.answered,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  final WorksheetDay day;
  final int answered;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFFFFEAAE), Color(0xFFFFD877)],
                  )
                : null,
            color: selected ? null : const Color(0xFFFFFCF7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFFC96D13)
                  : const Color(0xFFDCC19F),
              width: selected ? 1.7 : 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFFB96114).withValues(alpha: .2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                Icons.list_alt_rounded,
                color: selected
                    ? const Color(0xFF8E4A16)
                    : const Color(0xFFB69770),
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Day ${day.day}',
                  style: const TextStyle(
                    color: Color(0xFF3D2313),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$answered/$total',
                style: const TextStyle(
                  color: Color(0xFF6D421F),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF6),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC8A887), width: 1.3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 30, color: const Color(0xFF5B2D12)),
        ),
      ),
    );
  }
}

class _PaperCard extends StatelessWidget {
  const _PaperCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7).withValues(alpha: .94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD2A873), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B3D18).withValues(alpha: .13),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          const BoxShadow(
            color: Colors.white,
            blurRadius: 0,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _QuestionImage extends StatelessWidget {
  const _QuestionImage({required this.image});

  final String image;

  @override
  Widget build(BuildContext context) {
    try {
      final data = image.contains(',') ? image.split(',').last : image;
      final bytes = base64Decode(data);
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(
          bytes,
          width: 92,
          height: 92,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

class _WorksheetBackdrop extends StatelessWidget {
  const _WorksheetBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.18,
          colors: [Color(0xFFFFFDF8), Color(0xFFFFF4DC), Color(0xFFFFFAEF)],
        ),
      ),
      child: child,
    );
  }
}
