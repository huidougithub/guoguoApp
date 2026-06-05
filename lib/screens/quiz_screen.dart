import 'dart:math';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/app_store.dart';
import '../services/audio_service.dart';
import '../services/question_factory.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/ui_components.dart';
import '../data/app_data.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.store,
    required this.level,
    required this.questions,
    this.onComplete,
  });

  final AppStore store;
  final LevelDefinition level;
  final List<Question> questions;
  final Future<void> Function({
    required int correct,
    required int total,
    required int seconds,
  })?
  onComplete;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final missed = <Question>[];
  final startedAt = DateTime.now();
  int index = 0;
  int correct = 0;
  String? selected;
  List<String> verticalDigits = const [];
  int verticalFocus = 0;
  String feedback = '仔细观察，勇敢选择。';
  bool answered = false;
  bool advancing = false;
  late int bossHp;
  late int petHp;
  late final String bossAsset;
  String battleState = 'idle';
  BossEscapeOutcome? escapeOutcome;

  @override
  void initState() {
    super.initState();
    bossHp = widget.questions.length;
    petHp = widget.questions.length;
    bossAsset = bossAssetForLevel(widget.level);
    _resetVerticalDigits(widget.questions[index]);
    if (widget.store.progress.settings['music'] ?? false) {
      AudioService.playBgm(_sceneForLevel(widget.level));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrentEnglish());
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[index];
    final pet = petById(widget.store.progress.selectedPet);
    final verticalMode = question.inputMode == QuestionInputMode.vertical;
    return ExplorerScaffold(
      title: widget.level.title,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SoftCard(
                    color: const Color(0xFFFFF8E1),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BattleArena(
                          pet: pet,
                          bossKind: widget.level.bossKind,
                          bossAsset: bossAsset,
                          petLevel: widget.store.progress.petLevel,
                          petCosmetics: widget.store.equippedCosmeticsForPet(
                            widget.store.progress.selectedPet,
                          ),
                          petHp: petHp,
                          bossHp: bossHp,
                          maxHp: widget.questions.length,
                          state: battleState,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          feedback,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        LinearProgressIndicator(
                          value: (index + 1) / widget.questions.length,
                          minHeight: 12,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        const SizedBox(height: 8),
                        Text('第${index + 1}/${widget.questions.length}题'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 148,
                    height: 44,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.lightbulb, size: 20),
                      label: const Text(
                        '分步提示',
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                      ),
                      onPressed: answered
                          ? null
                          : () => _showStepHint(question),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 8,
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Expanded(
                    child: SoftCard(
                      color: question.isBoss
                          ? const Color(0xFFFFE8A3)
                          : const Color(0xFFFFFBEB),
                      child: Center(
                        child: verticalMode
                            ? _VerticalQuestionPrompt(
                                question: question,
                                digits: verticalDigits,
                                focusedIndex: verticalFocus,
                                onFocus: answered
                                    ? null
                                    : (digitIndex) => setState(
                                        () => verticalFocus = digitIndex,
                                      ),
                              )
                            : _QuestionPrompt(question: question),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  verticalMode
                      ? _VerticalAnswerControls(
                          answered: answered,
                          onDigit: _enterVerticalDigit,
                          onBackspace: _backspaceVerticalDigit,
                          onSubmit: _submitVerticalAnswer,
                        )
                      : GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 5.2,
                          children: question.choices.map((choice) {
                            final isSelected = selected == choice;
                            final isRight =
                                answered && choice == question.answer;
                            final isWrong = answered && isSelected && !isRight;
                            return FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: isRight
                                    ? const Color(0xFF4CAF50)
                                    : isWrong
                                    ? const Color(0xFFE57373)
                                    : isSelected
                                    ? const Color(0xFF42A5F5)
                                    : Colors.white,
                                foregroundColor:
                                    isRight || isWrong || isSelected
                                    ? Colors.white
                                    : const Color(0xFF2D2A32),
                                side: const BorderSide(
                                  color: Color(0xFF2D2A32),
                                  width: 1.4,
                                ),
                              ),
                              onPressed: answered
                                  ? null
                                  : () => _answer(choice),
                              child: Text(
                                choice,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 22),
                              ),
                            );
                          }).toList(),
                        ),
                  if (question.subject == '英语') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.volume_up),
                      label: const Text('朗读英文'),
                      onPressed: () => _speakEnglish(question),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStepHint(Question question) {
    AudioService.playSfx(
      AppSound.hint,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
    setState(() {
      feedback = question.hint.isEmpty ? '再读一遍题目，圈出关键数字。' : question.hint;
    });
  }

  void _resetVerticalDigits(Question question) {
    final length = question.inputMode == QuestionInputMode.vertical
        ? question.answer.length
        : 0;
    verticalDigits = List.filled(length, '');
    verticalFocus = length > 0 ? length - 1 : 0;
  }

  void _enterVerticalDigit(String digit) {
    if (answered || verticalDigits.isEmpty) return;
    setState(() {
      verticalDigits[verticalFocus] = digit;
      if (verticalFocus > 0) {
        verticalFocus -= 1;
      }
    });
  }

  void _backspaceVerticalDigit() {
    if (answered || verticalDigits.isEmpty) return;
    setState(() {
      if (verticalDigits[verticalFocus].isNotEmpty) {
        verticalDigits[verticalFocus] = '';
      } else if (verticalFocus < verticalDigits.length - 1) {
        verticalFocus += 1;
        verticalDigits[verticalFocus] = '';
      }
    });
  }

  Future<void> _submitVerticalAnswer() async {
    if (answered || advancing) return;
    if (verticalDigits.any((digit) => digit.isEmpty)) {
      await AudioService.playSfx(
        AppSound.hint,
        enabled: widget.store.progress.settings['sfx'] ?? true,
      );
      if (!mounted) return;
      setState(() {
        feedback = '把横线下面的每一格都填好，再提交。';
      });
      return;
    }
    await _answer(verticalDigits.join());
  }

  Future<void> _answer(String choice) async {
    if (answered || advancing) return;
    final question = widget.questions[index];
    final isCorrect = choice == question.answer;
    final sfxEnabled = widget.store.progress.settings['sfx'] ?? true;
    setState(() {
      selected = choice;
      answered = true;
      battleState = isCorrect ? 'petCharge' : 'bossCharge';
      feedback = isCorrect ? '答对啦，宠物正在蓄力！' : 'Boss准备反击，撑住护盾！';
    });
    await AudioService.playSfx(
      isCorrect ? AppSound.petCharge : AppSound.bossCharge,
      enabled: sfxEnabled,
    );
    await Future<void>.delayed(const Duration(milliseconds: 75));
    if (!mounted) return;
    setState(() {
      battleState = isCorrect ? 'petProjectile' : 'bossProjectile';
    });
    await AudioService.playSfx(
      isCorrect ? AppSound.petProjectile : AppSound.bossAttack,
      enabled: sfxEnabled,
    );
    await Future<void>.delayed(const Duration(milliseconds: 95));
    if (!mounted) return;
    setState(() {
      battleState = isCorrect ? 'petImpact' : 'bossImpact';
      if (isCorrect) {
        correct += 1;
        bossHp = max(0, bossHp - 1);
        feedback = question.isBoss ? 'Boss题也拿下啦，重重一击！' : '答对啦，知识光球命中Boss！';
      } else {
        missed.add(question);
        petHp = max(0, petHp - 1);
        feedback = 'Boss反击了！${question.explanation}';
      }
    });
    await AudioService.playSfx(
      isCorrect ? AppSound.magicImpact : AppSound.shieldHit,
      enabled: sfxEnabled,
    );
    if (!isCorrect) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      await AudioService.playSfx(AppSound.dizzy, enabled: sfxEnabled);
    }
    advancing = true;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    advancing = false;
    await _next();
  }

  Future<void> _next() async {
    if (index < widget.questions.length - 1) {
      if (!mounted) return;
      setState(() {
        index += 1;
        selected = null;
        answered = false;
        feedback = '仔细观察，勇敢选择。';
        battleState = 'idle';
        _resetVerticalDigits(widget.questions[index]);
      });
      _speakCurrentEnglish();
      return;
    }
    final seconds = DateTime.now().difference(startedAt).inSeconds;
    if (widget.onComplete == null) {
      await widget.store.completeLevel(
        level: widget.level,
        correct: correct,
        total: widget.questions.length,
        seconds: seconds,
        missedQuestions: missed,
      );
      if (correct == widget.questions.length) {
        if (mounted) setState(() => battleState = 'bossDown');
        await AudioService.playSfx(
          AppSound.bossDown,
          enabled: widget.store.progress.settings['sfx'] ?? true,
        );
      } else {
        if (mounted) setState(() => battleState = 'bossEscape');
        await AudioService.playSfx(
          AppSound.bossEscape,
          enabled: widget.store.progress.settings['sfx'] ?? true,
        );
        escapeOutcome = await widget.store.resolveBossEscape(
          remainingHp: bossHp,
          totalHp: widget.questions.length,
        );
        if ((escapeOutcome?.stolenAmount ?? 0) > 0) {
          await AudioService.playSfx(
            AppSound.steal,
            enabled: widget.store.progress.settings['sfx'] ?? true,
          );
        }
      }
    } else {
      await widget.onComplete!(
        correct: correct,
        total: widget.questions.length,
        seconds: seconds,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 360));
    if (correct != widget.questions.length) {
      await AudioService.playSfx(
        AppSound.reward,
        enabled: widget.store.progress.settings['sfx'] ?? true,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          correct: correct,
          total: widget.questions.length,
          seconds: seconds,
          level: widget.level,
          store: widget.store,
          onComplete: widget.onComplete,
          escapeOutcome: escapeOutcome,
        ),
      ),
    );
  }

  void _speakCurrentEnglish() {
    if (!mounted) return;
    _speakEnglish(widget.questions[index]);
  }

  Future<void> _speakEnglish(Question question) async {
    if (question.subject != '英语') return;
    await AudioService.speakEnglish(
      _speechTextFor(question),
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
  }

  String _speechTextFor(Question question) {
    final englishInPrompt = RegExp(r"[A-Za-z][A-Za-z\s'.,!?-]*")
        .allMatches(question.prompt)
        .map((match) => match.group(0)!.trim())
        .where((text) => text.length > 1);
    if (englishInPrompt.isNotEmpty) return englishInPrompt.join('. ');
    return question.choices
        .where((choice) => RegExp(r'[A-Za-z]').hasMatch(choice))
        .join('. ');
  }
}

class _QuestionPrompt extends StatelessWidget {
  const _QuestionPrompt({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    final visual = question.visual;
    final prompt = Text(
      question.prompt,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: visual == null ? 32 : 25,
        fontWeight: FontWeight.w900,
        height: 1.16,
      ),
    );
    if (visual == null) return prompt;

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: AspectRatio(
              aspectRatio: 2.35,
              child: visual['kind'] == 'money'
                  ? _MoneyVisual(items: visual['items'] ?? '')
                  : CustomPaint(painter: _QuestionVisualPainter(visual)),
            ),
          ),
          const SizedBox(height: 14),
          prompt,
        ],
      ),
    );
  }
}

class _VerticalQuestionPrompt extends StatelessWidget {
  const _VerticalQuestionPrompt({
    required this.question,
    required this.digits,
    required this.focusedIndex,
    required this.onFocus,
  });

  final Question question;
  final List<String> digits;
  final int focusedIndex;
  final ValueChanged<int>? onFocus;

  static const _line = Color(0xFF2D2A32);

  @override
  Widget build(BuildContext context) {
    final visual = question.visual ?? const <String, String>{};
    final op = visual['op'] ?? '+';
    final top = visual['top'] ?? '0';
    final bottom = visual['bottom'] ?? '0';
    final width = max(question.answer.length, max(top.length, bottom.length));
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            question.prompt,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.16,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .74),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _line.withValues(alpha: .18), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _VerticalNumberRow(value: top, width: width),
                const SizedBox(height: 8),
                _VerticalNumberRow(value: bottom, width: width, op: op),
                Container(
                  width: width * 58 + 34,
                  height: 3,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  color: _line,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 34),
                    for (var i = 0; i < width; i++)
                      _DigitBox(
                        value: i < digits.length ? digits[i] : '',
                        focused: i == focusedIndex,
                        onTap: onFocus == null ? null : () => onFocus!(i),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalNumberRow extends StatelessWidget {
  const _VerticalNumberRow({required this.value, required this.width, this.op});

  final String value;
  final int width;
  final String? op;

  @override
  Widget build(BuildContext context) {
    final padded = value.padLeft(width);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 34,
          child: Text(
            op ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
          ),
        ),
        for (final char in padded.characters)
          SizedBox(
            width: 58,
            child: Text(
              char.trim(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }
}

class _DigitBox extends StatelessWidget {
  const _DigitBox({required this.value, required this.focused, this.onTap});

  final String value;
  final bool focused;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = focused
        ? const Color(0xFF42A5F5)
        : const Color(0xFF2D2A32);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 48,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: focused ? const Color(0xFFE0F2FE) : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: focused ? 3 : 2),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _VerticalAnswerControls extends StatelessWidget {
  const _VerticalAnswerControls({
    required this.answered,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
  });

  final bool answered;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i <= 9; i++)
              SizedBox(
                width: 58,
                height: 46,
                child: FilledButton(
                  onPressed: answered ? null : () => onDigit('$i'),
                  child: Text(
                    '$i',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 116,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: answered ? null : onBackspace,
                icon: const Icon(Icons.backspace_outlined, size: 20),
                label: const Text(
                  '擦除',
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 116,
              height: 46,
              child: FilledButton.icon(
                onPressed: answered ? null : onSubmit,
                icon: const Icon(Icons.check, size: 20),
                label: const Text(
                  '提交',
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MoneyVisual extends StatelessWidget {
  const _MoneyVisual({required this.items});

  final String items;

  static const _line = Color(0xFF2D2A32);

  @override
  Widget build(BuildContext context) {
    final labels = items
        .split(RegExp(r'[,;]'))
        .map((raw) => raw.trim())
        .where((raw) => raw.isNotEmpty)
        .toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .74),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line.withValues(alpha: .18), width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: labels.expand(_buildPieces).toList(growable: false),
        ),
      ),
    );
  }

  Iterable<Widget> _buildPieces(String label) {
    final payment = RegExp(r'^付(.+)$').firstMatch(label);
    if (payment != null) {
      return [_textTag('付'), ..._buildMoneyPieces(payment.group(1)!)];
    }
    final exact = _assetFor(label);
    if (exact != null) return [_moneyImage(exact, _isCoin(label))];
    final yuan = RegExp(r'^(\d+)元$').firstMatch(label);
    if (yuan != null) {
      final count = int.tryParse(yuan.group(1)!) ?? 0;
      if (count > 0 && count <= 4) {
        return List.generate(
          count,
          (_) => _moneyImage(_assetFor('1元')!, false, compact: true),
        );
      }
    }
    return [_textTag(label)];
  }

  Iterable<Widget> _buildMoneyPieces(String label) {
    final exact = _assetFor(label);
    if (exact != null) return [_moneyImage(exact, _isCoin(label))];
    return _buildPieces(label);
  }

  Widget _moneyImage(String asset, bool coin, {bool compact = false}) {
    return Container(
      width: coin ? 76 : (compact ? 94 : 134),
      height: coin ? 76 : (compact ? 52 : 72),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(coin ? 38 : 7),
        boxShadow: const [
          BoxShadow(
            color: Color(0x17000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }

  Widget _textTag(String text) {
    return Container(
      constraints: const BoxConstraints(minWidth: 76, minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0A8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _line,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }

  bool _isCoin(String label) => label == '1角' || label == '5角';

  String? _assetFor(String label) {
    return switch (label) {
      '1元' => 'assets/money/rmb_1_yuan.png',
      '5元' => 'assets/money/rmb_5_yuan.png',
      '10元' => 'assets/money/rmb_10_yuan.png',
      '1角' => 'assets/money/rmb_1_jiao.png',
      '5角' => 'assets/money/rmb_5_jiao.png',
      _ => null,
    };
  }
}

class _QuestionVisualPainter extends CustomPainter {
  _QuestionVisualPainter(this.visual);

  final Map<String, String> visual;

  static const _triangle = Color(0xFFFF8C42);
  static const _circle = Color(0xFF42A5F5);
  static const _square = Color(0xFFFFD166);
  static const _rectangle = Color(0xFF34D399);
  static const _line = Color(0xFF2D2A32);

  @override
  void paint(Canvas canvas, Size size) {
    final board = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );
    canvas.drawRRect(
      board,
      Paint()
        ..isAntiAlias = true
        ..color = Colors.white.withValues(alpha: .74),
    );
    canvas.drawRRect(
      board,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _line.withValues(alpha: .18),
    );

    switch (visual['kind']) {
      case 'shape':
        _drawShape(
          canvas,
          size.center(Offset.zero),
          min(size.width, size.height) * .33,
          visual['shape'] ?? 'square',
        );
      case 'shapeSet':
        _drawShapeSet(canvas, size, visual['highlight'] ?? '');
      case 'composition':
        _drawComposition(canvas, size, visual['scene'] ?? '');
      case 'classification':
        _drawClassification(canvas, size, visual['items'] ?? '');
      case 'money':
        _drawMoney(canvas, size, visual['items'] ?? '');
      case 'pattern':
        _drawPattern(canvas, size, visual['items'] ?? '');
      default:
        _drawShapeSet(canvas, size, '');
    }
  }

  void _drawShapeSet(Canvas canvas, Size size, String highlight) {
    final centers = [
      Offset(size.width * .18, size.height * .5),
      Offset(size.width * .39, size.height * .5),
      Offset(size.width * .61, size.height * .5),
      Offset(size.width * .82, size.height * .5),
    ];
    final shapes = ['triangle', 'circle', 'square', 'rectangle'];
    for (var i = 0; i < shapes.length; i++) {
      if (highlight == shapes[i]) {
        canvas.drawCircle(
          centers[i],
          min(size.width, size.height) * .24,
          Paint()
            ..isAntiAlias = true
            ..color = const Color(0xFFFFF3B0),
        );
      }
      _drawShape(
        canvas,
        centers[i],
        min(size.width, size.height) * .2,
        shapes[i],
      );
    }
  }

  void _drawComposition(Canvas canvas, Size size, String scene) {
    switch (scene) {
      case 'twoTrianglesSquare':
        _drawSplitSquare(canvas, size, diagonal: true);
      case 'twoTrianglesRectangle':
        _drawSplitRectangle(canvas, size, diagonal: true);
      case 'twoTrianglesBigTriangle':
        _drawBigTrianglePair(canvas, size);
      case 'twoSquaresRectangleHorizontal':
        _drawSquareTiles(canvas, size, cols: 2, rows: 1);
      case 'twoSquaresRectangleVertical':
        _drawSquareTiles(canvas, size, cols: 1, rows: 2);
      case 'fourSquaresBigSquare':
        _drawSquareTiles(canvas, size, cols: 2, rows: 2);
      case 'threeSquaresRow':
        _drawSquareTiles(canvas, size, cols: 3, rows: 1);
      case 'squareSplitTriangles':
        _drawSplitSquare(canvas, size, diagonal: true);
      case 'rectangleSplitSquares':
        _drawSquareTiles(canvas, size, cols: 2, rows: 1);
      case 'twoCircles':
        _drawTwoCircles(canvas, size);
      case 'tangramBoat':
        _drawBoat(canvas, size);
      case 'house':
        _drawHouse(canvas, size);
      case 'car':
        _drawCar(canvas, size);
      case 'twoTrianglesOneSquare':
        _drawTwoTrianglesOneSquare(canvas, size);
      case 'twoTrianglesSquareCircle':
        _drawTwoTrianglesSquareCircle(canvas, size);
      case 'sun':
        _drawSun(canvas, size);
      default:
        _drawShapeSet(canvas, size, '');
    }
  }

  void _drawClassification(Canvas canvas, Size size, String encodedItems) {
    final items = encodedItems
        .split(RegExp(r'[,;]'))
        .map((raw) => raw.trim())
        .where((raw) => raw.isNotEmpty)
        .toList();
    if (items.isEmpty) {
      _drawShapeSet(canvas, size, '');
      return;
    }

    final cols = items.length <= 4
        ? items.length
        : min(5, (items.length + 1) ~/ 2);
    final rows = (items.length / cols).ceil();
    final cellW = size.width / (cols + .8);
    final cellH = size.height / (rows + .8);
    final baseRadius = min(cellW, cellH) * .34;
    final startX = (size.width - cellW * (cols - 1)) / 2;
    final startY = (size.height - cellH * (rows - 1)) / 2;

    for (var i = 0; i < items.length; i++) {
      final parts = items[i].split(':');
      final colorCode = parts.isNotEmpty ? parts[0] : 'r';
      final shapeCode = parts.length > 1 ? parts[1] : 'c';
      final scale = parts.length > 2 ? double.tryParse(parts[2]) ?? 1 : 1.0;
      final center = Offset(
        startX + (i % cols) * cellW,
        startY + (i ~/ cols) * cellH,
      );
      _drawShape(
        canvas,
        center,
        baseRadius * scale.clamp(.62, 1.35),
        _shapeFromCode(shapeCode),
        overrideColor: _colorFromCode(colorCode),
      );
    }
  }

  void _drawMoney(Canvas canvas, Size size, String encodedItems) {
    final items = encodedItems
        .split(RegExp(r'[,;]'))
        .map((raw) => raw.trim())
        .where((raw) => raw.isNotEmpty)
        .toList();
    if (items.isEmpty) return;
    final cols = min(3, items.length);
    final rows = (items.length / cols).ceil();
    final cellW = size.width / (cols + .7);
    final cellH = size.height / (rows + .7);
    final startX = (size.width - cellW * (cols - 1)) / 2;
    final startY = (size.height - cellH * (rows - 1)) / 2;
    for (var i = 0; i < items.length; i++) {
      final center = Offset(
        startX + (i % cols) * cellW,
        startY + (i ~/ cols) * cellH,
      );
      _drawMoneyItem(canvas, center, min(cellW, cellH), items[i]);
    }
  }

  void _drawMoneyItem(Canvas canvas, Offset center, double cell, String label) {
    final isCoin = label.contains('角') || label.contains('分');
    final isCash = RegExp(r'^[0-9]+元$').hasMatch(label);
    if (isCoin) {
      final radius = cell * .24;
      canvas.drawCircle(center, radius, _fill(const Color(0xFFFFD166)));
      canvas.drawCircle(center, radius, _stroke(width: 2));
      _drawCenteredLabel(canvas, center, label, cell * .16);
      return;
    }
    final rect = Rect.fromCenter(
      center: center,
      width: cell * (isCash ? .92 : 1.05),
      height: cell * .42,
    );
    final color = isCash ? const Color(0xFFA7F3D0) : const Color(0xFFFFF0A8);
    _drawRect(canvas, rect, color);
    _drawCenteredLabel(canvas, center, label, cell * (isCash ? .16 : .13));
  }

  void _drawCenteredLabel(
    Canvas canvas,
    Offset center,
    String label,
    double fontSize,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: _line,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: fontSize * max(4, label.length));
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _drawPattern(Canvas canvas, Size size, String encodedItems) {
    final separator = encodedItems.indexOf(':');
    if (separator <= 0) return;
    final type = encodedItems.substring(0, separator);
    final values = encodedItems
        .substring(separator + 1)
        .split(',')
        .map((raw) => raw.trim())
        .where((raw) => raw.isNotEmpty)
        .toList();
    if (values.isEmpty) return;

    if (type == 'count') {
      _drawCountPattern(canvas, size, values);
      return;
    }

    final cellW = size.width / (values.length + .9);
    final centerY = size.height * .5;
    final startX = (size.width - cellW * (values.length - 1)) / 2;
    for (var i = 0; i < values.length; i++) {
      final center = Offset(startX + i * cellW, centerY);
      if (type == 'shape') {
        _drawShape(
          canvas,
          center,
          min(cellW, size.height) * .24,
          _shapeFromCode(values[i]),
        );
      } else {
        final rect = Rect.fromCenter(
          center: center,
          width: cellW * .52,
          height: min(size.height * .42, cellW * .52),
        );
        _drawRect(canvas, rect, _colorFromCode(values[i]));
      }
    }
    _drawQuestionMark(
      canvas,
      Offset(size.width - cellW * .38, centerY),
      cellW * .3,
    );
  }

  void _drawCountPattern(Canvas canvas, Size size, List<String> values) {
    final groupW = size.width / (values.length + .8);
    final startX = (size.width - groupW * (values.length - 1)) / 2;
    for (var i = 0; i < values.length; i++) {
      final count = int.tryParse(values[i]) ?? 1;
      final origin = Offset(startX + i * groupW, size.height * .5);
      final cols = min(5, max(1, sqrt(count).ceil()));
      final rows = (count / cols).ceil();
      final gap = min(groupW * .16, size.height * .1);
      final dot = gap * .34;
      final totalW = (cols - 1) * gap;
      final totalH = (rows - 1) * gap;
      for (var n = 0; n < count; n++) {
        final point =
            origin +
            Offset(
              (n % cols) * gap - totalW / 2,
              (n ~/ cols) * gap - totalH / 2,
            );
        canvas.drawCircle(point, dot, _fill(const Color(0xFF42A5F5)));
        canvas.drawCircle(point, dot, _stroke(width: 1.2));
      }
    }
    _drawQuestionMark(
      canvas,
      Offset(size.width - groupW * .35, size.height * .5),
      groupW * .28,
    );
  }

  void _drawQuestionMark(Canvas canvas, Offset center, double fontSize) {
    _drawCenteredLabel(canvas, center, '?', fontSize);
  }

  void _drawShape(
    Canvas canvas,
    Offset center,
    double radius,
    String shape, {
    Color? overrideColor,
  }) {
    switch (shape) {
      case 'triangle':
        final path = Path()
          ..moveTo(center.dx, center.dy - radius)
          ..lineTo(center.dx - radius * .92, center.dy + radius * .78)
          ..lineTo(center.dx + radius * .92, center.dy + radius * .78)
          ..close();
        _fillPath(canvas, path, overrideColor ?? _triangle);
      case 'circle':
        canvas.drawCircle(
          center,
          radius * .86,
          _fill(overrideColor ?? _circle),
        );
        canvas.drawCircle(center, radius * .86, _stroke());
      case 'rectangle':
        final rect = Rect.fromCenter(
          center: center,
          width: radius * 2.3,
          height: radius * 1.22,
        );
        _drawRect(canvas, rect, overrideColor ?? _rectangle);
      case 'square':
      default:
        final rect = Rect.fromCenter(
          center: center,
          width: radius * 1.62,
          height: radius * 1.62,
        );
        _drawRect(canvas, rect, overrideColor ?? _square);
    }
  }

  String _shapeFromCode(String code) {
    return switch (code) {
      't' => 'triangle',
      's' => 'square',
      'r' => 'rectangle',
      _ => 'circle',
    };
  }

  Color _colorFromCode(String code) {
    return switch (code) {
      'b' => _circle,
      'y' => _square,
      'g' => _rectangle,
      _ => _triangle,
    };
  }

  void _drawSplitSquare(Canvas canvas, Size size, {required bool diagonal}) {
    final side = min(size.width, size.height) * .58;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );
    _drawRect(canvas, rect, _square);
    canvas.drawLine(rect.topLeft, rect.bottomRight, _stroke(width: 3));
  }

  void _drawSplitRectangle(Canvas canvas, Size size, {required bool diagonal}) {
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * .52,
      height: size.height * .48,
    );
    _drawRect(canvas, rect, _rectangle);
    canvas.drawLine(rect.topLeft, rect.bottomRight, _stroke(width: 3));
  }

  void _drawBigTrianglePair(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final w = size.width * .44;
    final h = size.height * .64;
    final left = Path()
      ..moveTo(center.dx, center.dy - h / 2)
      ..lineTo(center.dx - w / 2, center.dy + h / 2)
      ..lineTo(center.dx, center.dy + h / 2)
      ..close();
    final right = Path()
      ..moveTo(center.dx, center.dy - h / 2)
      ..lineTo(center.dx, center.dy + h / 2)
      ..lineTo(center.dx + w / 2, center.dy + h / 2)
      ..close();
    _fillPath(canvas, left, _triangle);
    _fillPath(canvas, right, const Color(0xFFFFB86B));
  }

  void _drawSquareTiles(
    Canvas canvas,
    Size size, {
    required int cols,
    required int rows,
  }) {
    final tile = min(size.width / (cols + 1.4), size.height / (rows + .9));
    final totalW = tile * cols;
    final totalH = tile * rows;
    final start = Offset((size.width - totalW) / 2, (size.height - totalH) / 2);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(
          start.dx + c * tile,
          start.dy + r * tile,
          tile,
          tile,
        );
        _drawRect(
          canvas,
          rect.deflate(2),
          c.isEven ? _square : const Color(0xFFFFE29A),
        );
      }
    }
  }

  void _drawTwoCircles(Canvas canvas, Size size) {
    _drawShape(
      canvas,
      Offset(size.width * .43, size.height * .5),
      min(size.width, size.height) * .2,
      'circle',
    );
    _drawShape(
      canvas,
      Offset(size.width * .57, size.height * .5),
      min(size.width, size.height) * .2,
      'circle',
    );
  }

  void _drawHouse(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final body = Rect.fromCenter(
      center: center + Offset(0, size.height * .12),
      width: size.width * .28,
      height: size.height * .36,
    );
    _drawRect(canvas, body, _square);
    final roof = Path()
      ..moveTo(center.dx, size.height * .18)
      ..lineTo(center.dx - size.width * .18, size.height * .43)
      ..lineTo(center.dx + size.width * .18, size.height * .43)
      ..close();
    _fillPath(canvas, roof, _triangle);
  }

  void _drawCar(Canvas canvas, Size size) {
    final body = Rect.fromCenter(
      center: Offset(size.width * .5, size.height * .5),
      width: size.width * .46,
      height: size.height * .28,
    );
    _drawRect(canvas, body, _rectangle);
    _drawShape(
      canvas,
      Offset(size.width * .39, size.height * .68),
      size.height * .11,
      'circle',
    );
    _drawShape(
      canvas,
      Offset(size.width * .61, size.height * .68),
      size.height * .11,
      'circle',
    );
  }

  void _drawBoat(Canvas canvas, Size size) {
    final hull = Path()
      ..moveTo(size.width * .28, size.height * .62)
      ..lineTo(size.width * .72, size.height * .62)
      ..lineTo(size.width * .62, size.height * .76)
      ..lineTo(size.width * .38, size.height * .76)
      ..close();
    _fillPath(canvas, hull, _rectangle);
    final sail = Path()
      ..moveTo(size.width * .5, size.height * .22)
      ..lineTo(size.width * .5, size.height * .62)
      ..lineTo(size.width * .32, size.height * .62)
      ..close();
    _fillPath(canvas, sail, _triangle);
    _drawShape(
      canvas,
      Offset(size.width * .59, size.height * .45),
      size.height * .16,
      'triangle',
    );
  }

  void _drawTwoTrianglesOneSquare(Canvas canvas, Size size) {
    _drawShape(
      canvas,
      Offset(size.width * .35, size.height * .46),
      size.height * .18,
      'triangle',
    );
    _drawShape(
      canvas,
      Offset(size.width * .5, size.height * .56),
      size.height * .18,
      'square',
    );
    _drawShape(
      canvas,
      Offset(size.width * .66, size.height * .46),
      size.height * .18,
      'triangle',
    );
  }

  void _drawTwoTrianglesSquareCircle(Canvas canvas, Size size) {
    _drawShape(
      canvas,
      Offset(size.width * .32, size.height * .46),
      size.height * .16,
      'triangle',
    );
    _drawShape(
      canvas,
      Offset(size.width * .48, size.height * .56),
      size.height * .16,
      'square',
    );
    _drawShape(
      canvas,
      Offset(size.width * .63, size.height * .46),
      size.height * .16,
      'triangle',
    );
    _drawShape(
      canvas,
      Offset(size.width * .76, size.height * .58),
      size.height * .13,
      'circle',
    );
  }

  void _drawSun(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < 12; i++) {
      final angle = i * pi / 6;
      canvas.drawLine(
        center + Offset(cos(angle), sin(angle)) * size.height * .2,
        center + Offset(cos(angle), sin(angle)) * size.height * .32,
        _stroke(width: 4),
      );
    }
    _drawShape(canvas, center, size.height * .22, 'circle');
  }

  void _drawRect(Canvas canvas, Rect rect, Color color) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(rrect, _fill(color));
    canvas.drawRRect(rrect, _stroke());
  }

  void _fillPath(Canvas canvas, Path path, Color color) {
    canvas.drawPath(path, _fill(color));
    canvas.drawPath(path, _stroke());
  }

  Paint _fill(Color color) => Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.fill
    ..color = color;

  Paint _stroke({double width = 2.4}) => Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..color = _line;

  @override
  bool shouldRepaint(covariant _QuestionVisualPainter oldDelegate) {
    return oldDelegate.visual.toString() != visual.toString();
  }
}

AppMusicScene _sceneForLevel(LevelDefinition level) {
  return switch (level.island) {
    Island.math => AppMusicScene.math,
    Island.chinese => AppMusicScene.chinese,
    Island.english => AppMusicScene.english,
    Island.sudoku => AppMusicScene.sudoku,
  };
}

class _BattleArena extends StatefulWidget {
  const _BattleArena({
    required this.pet,
    required this.bossKind,
    required this.bossAsset,
    required this.petLevel,
    required this.petCosmetics,
    required this.petHp,
    required this.bossHp,
    required this.maxHp,
    required this.state,
  });

  final PetDefinition pet;
  final String bossKind;
  final String bossAsset;
  final int petLevel;
  final Set<String> petCosmetics;
  final int petHp;
  final int bossHp;
  final int maxHp;
  final String state;

  @override
  State<_BattleArena> createState() => _BattleArenaState();
}

class _BattleArenaState extends State<_BattleArena>
    with SingleTickerProviderStateMixin {
  late final AnimationController _effectController;

  bool get _petCharging => widget.state == 'petCharge';
  bool get _petProjectile => widget.state == 'petProjectile';
  bool get _petImpact => widget.state == 'petImpact';
  bool get _bossCharging => widget.state == 'bossCharge';
  bool get _bossProjectile => widget.state == 'bossProjectile';
  bool get _bossImpact => widget.state == 'bossImpact';
  bool get _petActing => _petCharging || _petProjectile || _petImpact;

  @override
  void initState() {
    super.initState();
    _effectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _runEffect();
  }

  @override
  void didUpdateWidget(covariant _BattleArena oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _runEffect();
  }

  void _runEffect() {
    final active =
        _petCharging ||
        _petProjectile ||
        _petImpact ||
        _bossCharging ||
        _bossProjectile ||
        _bossImpact ||
        widget.state == 'bossDown' ||
        widget.state == 'bossEscape';
    if (active) {
      _effectController.forward(from: 0);
    } else {
      _effectController.value = 0;
    }
  }

  @override
  void dispose() {
    _effectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final petOffset = _petCharging
        ? const Offset(-8, -4)
        : _petProjectile
        ? const Offset(20, -8)
        : _bossImpact
        ? const Offset(-12, 10)
        : Offset.zero;
    final bossOffset = _bossCharging
        ? const Offset(8, -4)
        : _bossProjectile
        ? const Offset(-18, -6)
        : _petImpact
        ? const Offset(14, 8)
        : widget.state == 'bossEscape'
        ? const Offset(52, -16)
        : Offset.zero;
    final bossOpacity = widget.state == 'bossDown'
        ? .35
        : widget.state == 'bossEscape'
        ? .55
        : 1.0;
    final petScale = _petCharging
        ? 1.08
        : _bossImpact
        ? .93
        : 1.0;
    final bossScale = _bossCharging
        ? 1.06
        : _petImpact
        ? .9
        : 1.0;
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _HpBar(
                          value: widget.petHp / widget.maxHp,
                          label: '宠物体力 ${widget.petHp}/${widget.maxHp}',
                          color: const Color(0xFF4CAF50),
                        ),
                        const SizedBox(height: 8),
                        AnimatedSlide(
                          duration: const Duration(milliseconds: 70),
                          offset: petOffset / 100,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 65),
                            scale: petScale,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                if (_bossImpact)
                                  const Positioned.fill(child: _ShieldRing()),
                                PetAvatar(
                                  pet: widget.pet,
                                  level: widget.petLevel,
                                  size: 116,
                                  cheering:
                                      _petActing || widget.state == 'bossDown',
                                  cosmeticIds: widget.petCosmetics,
                                ),
                                if (_petCharging)
                                  Positioned(
                                    top: -8,
                                    right: 8,
                                    child: _ChargeGlow(
                                      animation: _effectController,
                                      color: const Color(0xFFFFD166),
                                    ),
                                  ),
                                if (_bossImpact)
                                  const Positioned(
                                    top: 0,
                                    right: 2,
                                    child: _ReactionBadge(text: '晕'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        _HpBar(
                          value: widget.bossHp / widget.maxHp,
                          label: 'Boss血量 ${widget.bossHp}/${widget.maxHp}',
                          color: const Color(0xFFE57373),
                        ),
                        const SizedBox(height: 8),
                        AnimatedSlide(
                          duration: const Duration(milliseconds: 75),
                          offset: bossOffset / 100,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 80),
                            opacity: bossOpacity,
                            child: Transform.rotate(
                              angle: widget.state == 'bossDown' ? pi / 2.8 : 0,
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 65),
                                scale: bossScale,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    _BossAvatar(
                                      kind: widget.bossKind,
                                      asset: widget.bossAsset,
                                      size: 112,
                                      defeated: widget.state == 'bossDown',
                                      hurt: _petImpact,
                                      attacking:
                                          _bossCharging || _bossProjectile,
                                    ),
                                    if (_bossCharging)
                                      Positioned(
                                        top: -8,
                                        left: 8,
                                        child: _ChargeGlow(
                                          animation: _effectController,
                                          color: const Color(0xFF8B5CF6),
                                        ),
                                      ),
                                    if (_petImpact)
                                      const Positioned(
                                        top: -4,
                                        left: 0,
                                        child: _ReactionBadge(text: '痛'),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_petCharging ||
                  _petProjectile ||
                  _petImpact ||
                  _bossCharging ||
                  _bossProjectile ||
                  _bossImpact)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _effectController,
                      builder: (context, child) => CustomPaint(
                        painter: _BattleEffectPainter(
                          state: widget.state,
                          progress: _effectController.value,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.state == 'bossDown'
              ? 'Boss倒下了！'
              : widget.state == 'bossEscape'
              ? 'Boss准备逃走！'
              : _petCharging
              ? '宠物蓄力中'
              : _petProjectile
              ? '知识光球出击'
              : _petImpact
              ? '命中Boss'
              : _bossCharging
              ? 'Boss蓄力中'
              : _bossProjectile
              ? 'Boss反击'
              : _bossImpact
              ? '护盾受击'
              : '答题决定战斗走向',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _HpBar extends StatelessWidget {
  const _HpBar({required this.value, required this.label, required this.color});

  final double value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1).toDouble(),
            minHeight: 9,
            color: color,
            backgroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _ReactionBadge extends StatelessWidget {
  const _ReactionBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE08A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2D2A32), width: 1.2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Color(0xFFC2410C),
        ),
      ),
    );
  }
}

class _ChargeGlow extends StatelessWidget {
  const _ChargeGlow({required this.animation, required this.color});

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return Transform.scale(
          scale: 1 + sin(t * pi) * .18,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: .28),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: .55),
                  blurRadius: 12 + t * 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(Icons.auto_awesome, color: color, size: 20),
          ),
        );
      },
    );
  }
}

class _ShieldRing extends StatelessWidget {
  const _ShieldRing();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 122,
        height: 122,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF60A5FA), width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF60A5FA).withValues(alpha: .35),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _BattleEffectPainter extends CustomPainter {
  _BattleEffectPainter({required this.state, required this.progress});

  final String state;
  final double progress;

  bool get petSide =>
      state == 'petCharge' || state == 'petProjectile' || state == 'petImpact';

  @override
  void paint(Canvas canvas, Size size) {
    final petAttacking = petSide;
    final start = Offset(
      size.width * (petAttacking ? .31 : .69),
      size.height * .62,
    );
    final end = Offset(
      size.width * (petAttacking ? .69 : .31),
      size.height * .62,
    );
    final isCharge = state.endsWith('Charge');
    final isProjectile = state.endsWith('Projectile');
    final isImpact = state.endsWith('Impact');
    final t = Curves.easeOutCubic.transform(progress.clamp(0, 1));
    final baseColor = petAttacking
        ? const Color(0xFFFFD166)
        : const Color(0xFF8B5CF6);
    final paint = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeWidth = petAttacking ? 5 : 7
      ..color = baseColor;
    if (isCharge) {
      final center = start + Offset(petAttacking ? 28 : -28, -48);
      final r = 12 + 14 * sin(progress * pi).abs();
      canvas.drawCircle(
        center,
        r,
        paint..color = baseColor.withValues(alpha: .38),
      );
      canvas.drawCircle(center, 7 + 4 * progress, paint..color = baseColor);
      _drawSparkles(canvas, center, baseColor, 6, 18 + progress * 10);
      return;
    }

    final glow = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: .9);
    if (isProjectile) {
      final control = Offset(size.width * .5, size.height * .26);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      final metric = path.computeMetrics().first;
      final head =
          metric.getTangentForOffset(metric.length * t)?.position ?? end;
      final trailStart = max(0.0, t - .28) * metric.length;
      final trailEnd = t * metric.length;
      canvas.drawPath(metric.extractPath(trailStart, trailEnd), paint);
      canvas.drawPath(
        metric.extractPath(max(0, trailStart - 12), trailEnd),
        glow,
      );
      canvas.drawCircle(
        head,
        petAttacking ? 10 : 12,
        Paint()
          ..isAntiAlias = true
          ..color = petAttacking
              ? const Color(0xFFFFF3B0)
              : const Color(0xFFC4B5FD),
      );
      _drawSparkles(canvas, head, baseColor, petAttacking ? 5 : 4, 20);
      return;
    }

    final impact = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..color = petAttacking
          ? const Color(0xFFFF8C42)
          : const Color(0xFF60A5FA);
    if (!isImpact) return;
    for (var i = 0; i < 8; i++) {
      final angle = i * pi / 4;
      final p1 = end + Offset(cos(angle), sin(angle)) * (8 + progress * 3);
      final p2 = end + Offset(cos(angle), sin(angle)) * (20 + progress * 14);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..isAntiAlias = true
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = impact.color,
      );
    }
    canvas.drawCircle(end, 10 + sin(progress * pi) * 6, impact);
    canvas.drawCircle(
      end,
      22 + progress * 18,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - progress).clamp(0, 1)
        ..color = impact.color.withValues(alpha: .55 * (1 - progress)),
    );
  }

  void _drawSparkles(
    Canvas canvas,
    Offset center,
    Color color,
    int count,
    double radius,
  ) {
    final sparkle = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: .92);
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * pi * 2 + progress * pi;
      final p = center + Offset(cos(angle), sin(angle)) * radius;
      canvas.drawLine(p + const Offset(-3, 0), p + const Offset(3, 0), sparkle);
      canvas.drawLine(p + const Offset(0, -3), p + const Offset(0, 3), sparkle);
    }
    canvas.drawCircle(
      center,
      3,
      Paint()
        ..isAntiAlias = true
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _BattleEffectPainter oldDelegate) {
    return oldDelegate.state != state || oldDelegate.progress != progress;
  }
}

class _BossAvatar extends StatelessWidget {
  const _BossAvatar({
    required this.kind,
    required this.asset,
    required this.size,
    required this.defeated,
    required this.hurt,
    required this.attacking,
  });

  final String kind;
  final String asset;
  final double size;
  final bool defeated;
  final bool hurt;
  final bool attacking;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ColorFiltered(
        colorFilter: hurt
            ? const ColorFilter.mode(Color(0xFFFF8A80), BlendMode.modulate)
            : attacking
            ? const ColorFilter.mode(Color(0xFFE9D5FF), BlendMode.modulate)
            : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => CustomPaint(
            painter: _BossPainter(
              kind: kind,
              defeated: defeated,
              hurt: hurt,
              attacking: attacking,
            ),
          ),
        ),
      ),
    );
  }
}

class _BossPainter extends CustomPainter {
  _BossPainter({
    required this.kind,
    required this.defeated,
    required this.hurt,
    required this.attacking,
  });

  final String kind;
  final bool defeated;
  final bool hurt;
  final bool attacking;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()..isAntiAlias = true;
    final color = switch (kind) {
      'stone' => const Color(0xFF8D8A86),
      'clock' => const Color(0xFF8B5CF6),
      'shadow' => const Color(0xFF374151),
      'sound' => const Color(0xFF06B6D4),
      'book' => const Color(0xFFEF4444),
      'ink' => const Color(0xFF111827),
      'shell' => const Color(0xFFF59E0B),
      'snow' => const Color(0xFF60A5FA),
      'cloud' => const Color(0xFF94A3B8),
      _ => const Color(0xFF84CC16),
    };

    paint.color = color;
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(s * .5, s * .55),
        width: s * .72,
        height: s * .62,
      ),
      Radius.circular(s * .2),
    );
    canvas.drawRRect(body, paint);

    paint.color = color.withValues(alpha: .75);
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(s * (.22 + i * .18), s * (.22 + (i.isEven ? .03 : 0))),
        s * .08,
        paint,
      );
    }

    paint.color = Colors.white;
    canvas.drawCircle(Offset(s * .38, s * .48), s * .07, paint);
    canvas.drawCircle(Offset(s * .62, s * .48), s * .07, paint);
    paint.color = defeated ? const Color(0xFF2D2A32) : Colors.black;
    paint.strokeWidth = s * .025;
    if (defeated || hurt) {
      canvas.drawLine(
        Offset(s * .35, s * .45),
        Offset(s * .41, s * .51),
        paint,
      );
      canvas.drawLine(
        Offset(s * .41, s * .45),
        Offset(s * .35, s * .51),
        paint,
      );
      canvas.drawLine(
        Offset(s * .59, s * .45),
        Offset(s * .65, s * .51),
        paint,
      );
      canvas.drawLine(
        Offset(s * .65, s * .45),
        Offset(s * .59, s * .51),
        paint,
      );
    } else {
      canvas.drawCircle(Offset(s * .39, s * .49), s * .03, paint);
      canvas.drawCircle(Offset(s * .61, s * .49), s * .03, paint);
    }

    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * .035
      ..color = const Color(0xFF2D2A32);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s * .5, s * .67),
        width: s * .22,
        height: s * .12,
      ),
      defeated || hurt ? 0 : pi,
      pi,
      false,
      paint,
    );
    paint.style = PaintingStyle.fill;

    if (kind == 'book') {
      paint.color = const Color(0xFFFFF8E1);
      canvas.drawRect(Rect.fromLTWH(s * .28, s * .2, s * .44, s * .13), paint);
    } else if (kind == 'clock') {
      paint.color = const Color(0xFFFFD166);
      canvas.drawCircle(Offset(s * .5, s * .24), s * .12, paint);
      paint.color = const Color(0xFF2D2A32);
      canvas.drawRect(Rect.fromLTWH(s * .49, s * .17, s * .02, s * .07), paint);
      canvas.drawRect(Rect.fromLTWH(s * .5, s * .24, s * .08, s * .02), paint);
    } else if (kind == 'sound') {
      paint.color = const Color(0xFFFFF8E1);
      canvas.drawCircle(Offset(s * .72, s * .25), s * .045, paint);
      canvas.drawCircle(Offset(s * .8, s * .17), s * .035, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BossPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.defeated != defeated;
  }
}

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.correct,
    required this.total,
    required this.seconds,
    required this.level,
    required this.store,
    this.onComplete,
    this.escapeOutcome,
  });

  final int correct;
  final int total;
  final int seconds;
  final LevelDefinition level;
  final AppStore store;
  final BossEscapeOutcome? escapeOutcome;
  final Future<void> Function({
    required int correct,
    required int total,
    required int seconds,
  })?
  onComplete;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playVictorySound());
  }

  Future<void> _playVictorySound() async {
    if (!mounted || widget.correct != widget.total) return;
    await AudioService.playOneShot(
      AppSound.victory,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stars = widget.store.progress.levelStars[widget.level.id] ?? 0;
    final won = widget.correct == widget.total;
    final pet = petById(widget.store.progress.selectedPet);
    return ExplorerScaffold(
      title: '通关结果',
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SoftCard(
            color: const Color(0xFFFFF8E1),
            child: SizedBox(
              width: 620,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ResultPetPortrait(
                    pet: pet,
                    level: widget.store.progress.petLevel,
                    cosmetics: widget.store.equippedCosmeticsForPet(pet.id),
                    won: won,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.correct} / ${widget.total}',
                    style: const TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  StarRow(count: stars, size: 42),
                  const SizedBox(height: 10),
                  Text(
                    '用时 ${widget.seconds} 秒，本次获得 $stars 颗星。',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                  ),
                  if (widget.escapeOutcome != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.escapeOutcome!.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: widget.escapeOutcome!.stolenAmount > 0
                            ? const Color(0xFFC2410C)
                            : const Color(0xFF2D2A32),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.replay),
                        label: const Text('再试一次'),
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => QuizScreen(
                                store: widget.store,
                                level: widget.level,
                                questions: QuestionFactory().buildForLevel(
                                  widget.level,
                                ),
                                onComplete: widget.onComplete,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.map),
                        label: const Text('回到地图'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultPetPortrait extends StatelessWidget {
  const _ResultPetPortrait({
    required this.pet,
    required this.level,
    required this.cosmetics,
    required this.won,
  });

  final PetDefinition pet;
  final int level;
  final Set<String> cosmetics;
  final bool won;

  @override
  Widget build(BuildContext context) {
    final color = won ? const Color(0xFFFFD166) : const Color(0xFFBEE9FF);
    final resultAsset = _resultAssetFor(pet.id, won);
    return SizedBox(
      width: 170,
      height: 156,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 142,
            height: 122,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .42),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: const Color(0xFF2D2A32), width: 1.4),
            ),
          ),
          Positioned(
            top: resultAsset == null ? -4 : -18,
            child: resultAsset == null
                ? PetAvatar(
                    pet: pet,
                    level: level,
                    size: 122,
                    cheering: won,
                    mood: won ? PetMood.happy : PetMood.sad,
                    cosmeticIds: cosmetics,
                  )
                : Image.asset(
                    resultAsset,
                    width: 156,
                    height: 156,
                    fit: BoxFit.contain,
                  ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Icon(
              won ? Icons.auto_awesome : Icons.water_drop,
              size: 24,
              color: won ? const Color(0xFFFF8C42) : const Color(0xFF42A5F5),
            ),
          ),
        ],
      ),
    );
  }

  String? _resultAssetFor(String petId, bool won) {
    return switch (petId) {
      'fifi' =>
        won
            ? 'assets/pets/fifi_result_happy.png'
            : 'assets/pets/fifi_result_sad.png',
      'magic_star' =>
        won
            ? 'assets/pets/magic_star_result_happy.png'
            : 'assets/pets/magic_star_result_sad.png',
      'magic_moon' =>
        won
            ? 'assets/pets/magic_moon_result_happy.png'
            : 'assets/pets/magic_moon_result_sad.png',
      'magic_flower' =>
        won
            ? 'assets/pets/magic_flower_result_happy.png'
            : 'assets/pets/magic_flower_result_sad.png',
      _ => null,
    };
  }
}
