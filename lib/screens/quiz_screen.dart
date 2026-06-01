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
  String feedback = '仔细观察，勇敢选择。';
  bool answered = false;
  bool advancing = false;
  late int bossHp;
  late int petHp;
  String battleState = 'idle';
  BossEscapeOutcome? escapeOutcome;

  @override
  void initState() {
    super.initState();
    bossHp = widget.questions.length;
    petHp = widget.questions.length;
    if (widget.store.progress.settings['music'] ?? false) {
      AudioService.playBgm(_sceneForLevel(widget.level));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrentEnglish());
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[index];
    final pet = petById(widget.store.progress.selectedPet);
    return ExplorerScaffold(
      title: widget.level.title,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: SoftCard(
                color: const Color(0xFFFFF8E1),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BattleArena(
                        pet: pet,
                        bossKind: widget.level.bossKind,
                        bossAsset: bossAssetForLevel(widget.level),
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
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 8,
              child: Column(
                children: [
                  Expanded(
                    child: SoftCard(
                      color: question.isBoss
                          ? const Color(0xFFFFE8A3)
                          : const Color(0xFFFFFBEB),
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
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 5.2,
                    children: question.choices.map((choice) {
                      final isSelected = selected == choice;
                      final isRight = answered && choice == question.answer;
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
                          foregroundColor: isRight || isWrong || isSelected
                              ? Colors.white
                              : const Color(0xFF2D2A32),
                          side: const BorderSide(
                            color: Color(0xFF2D2A32),
                            width: 1.4,
                          ),
                        ),
                        onPressed: answered ? null : () => _answer(choice),
                        child: Text(
                          choice,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 22),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lightbulb),
                        label: const Text('分步提示'),
                        onPressed: answered
                            ? null
                            : () {
                                AudioService.playSfx(
                                  AppSound.hint,
                                  enabled:
                                      widget.store.progress.settings['sfx'] ??
                                      true,
                                );
                                setState(() {
                                  feedback = question.hint.isEmpty
                                      ? '再读一遍题目，圈出关键数字。'
                                      : question.hint;
                                });
                              },
                      ),
                      if (question.subject == '英语')
                        OutlinedButton.icon(
                          icon: const Icon(Icons.volume_up),
                          label: const Text('朗读英文'),
                          onPressed: () => _speakEnglish(question),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    setState(() {
      battleState = isCorrect ? 'petProjectile' : 'bossProjectile';
    });
    await AudioService.playSfx(
      isCorrect ? AppSound.petProjectile : AppSound.bossAttack,
      enabled: sfxEnabled,
    );
    await Future<void>.delayed(const Duration(milliseconds: 330));
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
      await Future<void>.delayed(const Duration(milliseconds: 90));
      await AudioService.playSfx(AppSound.dizzy, enabled: sfxEnabled);
    }
    advancing = true;
    await Future<void>.delayed(const Duration(milliseconds: 560));
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
    await Future<void>.delayed(const Duration(milliseconds: 650));
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
      duration: const Duration(milliseconds: 520),
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
                          duration: const Duration(milliseconds: 220),
                          offset: petOffset / 100,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 180),
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
                          duration: const Duration(milliseconds: 260),
                          offset: bossOffset / 100,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 260),
                            opacity: bossOpacity,
                            child: Transform.rotate(
                              angle: widget.state == 'bossDown' ? pi / 2.8 : 0,
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 180),
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
      'fifi' => won
          ? 'assets/pets/fifi_result_happy.png'
          : 'assets/pets/fifi_result_sad.png',
      'magic_star' => won
          ? 'assets/pets/magic_star_result_happy.png'
          : 'assets/pets/magic_star_result_sad.png',
      'magic_moon' => won
          ? 'assets/pets/magic_moon_result_happy.png'
          : 'assets/pets/magic_moon_result_sad.png',
      'magic_flower' => won
          ? 'assets/pets/magic_flower_result_happy.png'
          : 'assets/pets/magic_flower_result_sad.png',
      _ => null,
    };
  }
}
