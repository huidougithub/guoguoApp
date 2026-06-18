import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_data.dart';
import '../models/app_models.dart';
import '../services/app_store.dart';
import '../services/audio_service.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/ui_components.dart';

class LeisurePlaygroundScreen extends StatefulWidget {
  const LeisurePlaygroundScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<LeisurePlaygroundScreen> createState() =>
      _LeisurePlaygroundScreenState();
}

class _LeisurePlaygroundScreenState extends State<LeisurePlaygroundScreen> {
  Future<void> _openGame(_LeisureGame game) async {
    await AudioService.playSfx(
      AppSound.tap,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _LeisureGameScreen(store: widget.store, game: game),
      ),
    );
    if (widget.store.progress.settings['music'] ?? false) {
      await AudioService.playBgm(AppMusicScene.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExplorerScaffold(
      title: '休闲乐园',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '选一个小游戏',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              '先选择小游戏，再进入对应玩法。观察、记忆和下棋，都可以轻松玩一局。',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < _games.length; i++) ...[
                    Expanded(
                      child: _GameMenuCard(
                        game: _games[i],
                        active: false,
                        onTap: () => _openGame(_games[i]),
                      ),
                    ),
                    if (i != _games.length - 1) const SizedBox(width: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeisureGameScreen extends StatefulWidget {
  const _LeisureGameScreen({required this.store, required this.game});

  final AppStore store;
  final _LeisureGame game;

  @override
  State<_LeisureGameScreen> createState() => _LeisureGameScreenState();
}

class _LeisureGameScreenState extends State<_LeisureGameScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.store.progress.settings['music'] ?? false) {
      AudioService.playBgm(widget.game.music);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExplorerScaffold(
      title: widget.game.title,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: switch (widget.game.id) {
          'spot' => _SpotDifferenceGame(store: widget.store),
          'memory' => _MemoryFlipGame(store: widget.store),
          'gomoku' => _GomokuGame(store: widget.store),
          _ => _SpotDifferenceGame(store: widget.store),
        },
      ),
    );
  }
}

class _SpotDifferenceGame extends StatefulWidget {
  const _SpotDifferenceGame({required this.store});

  final AppStore store;

  @override
  State<_SpotDifferenceGame> createState() => _SpotDifferenceGameState();
}

class _SpotDifferenceGameState extends State<_SpotDifferenceGame> {
  static const int _timeLimitSeconds = 90;

  late int levelIndex;
  final Set<int> found = {};
  final List<Offset> markedPoints = [];
  Timer? _timer;
  int _secondsLeft = _timeLimitSeconds;
  bool _isAdvancing = false;
  bool _showCelebration = false;
  bool _timeFailed = false;

  bool get _sfxEnabled => widget.store.progress.settings['sfx'] ?? true;
  bool get _markerEnabled =>
      widget.store.progress.settings['spotMarker'] ?? false;
  bool get _markerShowMarked =>
      widget.store.progress.settings['spotMarkerShowMarked'] ?? false;
  List<_SpotLevel> get _currentLevels {
    if (!_markerEnabled) return _playLevels;
    if (_markerShowMarked) return _spotLevels;
    return [
      for (final spotLevel in _spotLevels)
        if (!_hasSavedOverride(spotLevel)) spotLevel,
    ];
  }

  List<_SpotLevel> get _playLevels {
    final pending = [
      for (final spotLevel in _spotLevels)
        if (!_isCompleted(spotLevel)) spotLevel,
    ];
    return pending.isEmpty ? _spotLevels : pending;
  }

  _SpotLevel get level => _currentLevels[levelIndex];

  bool _hasSavedOverride(_SpotLevel spotLevel) {
    final points =
        widget.store.progress.spotDifferenceOverrides[spotLevel.rightAsset];
    return points != null && points.isNotEmpty;
  }

  bool _isCompleted(_SpotLevel spotLevel) {
    return widget.store.isSpotDifferenceCompleted(spotLevel.rightAsset);
  }

  List<Offset> get _savedPoints {
    final raw = widget.store.progress.spotDifferenceOverrides[level.rightAsset];
    if (raw == null) return const [];
    return [
      for (final point in raw)
        if (point.length >= 2) Offset(point[0], point[1]),
    ];
  }

  List<_SpotDifferenceMark> get _effectiveDifferences {
    final saved = _savedPoints;
    if (saved.isEmpty) return level.differences;
    return [for (final point in saved) _SpotDifferenceMark(target: point)];
  }

  @override
  void initState() {
    super.initState();
    levelIndex = 0;
    _loadSavedMarkers();
    if (widget.store.progress.settings['music'] ?? false) {
      AudioService.playBgm(AppMusicScene.spotDifference);
    }
    _initializeLevels();
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeLevels() async {
    if (_markerEnabled) return;
    final allCompleted = _spotLevels.every(_isCompleted);
    if (allCompleted) {
      await widget.store.resetSpotDifferenceCycle(
        _spotLevels.map((level) => level.rightAsset),
      );
    }
    if (!mounted) return;
    setState(() {
      levelIndex = 0;
      found.clear();
      _loadSavedMarkers();
    });
    _restartTimer();
  }

  void _loadSavedMarkers() {
    if (_currentLevels.isEmpty) {
      markedPoints.clear();
      return;
    }
    markedPoints
      ..clear()
      ..addAll(_savedPoints);
  }

  Future<void> _handleFound(int index) async {
    if (found.contains(index) || _isAdvancing || _timeFailed) return;
    await AudioService.playSfx(AppSound.spotCorrect, enabled: _sfxEnabled);
    if (!mounted) return;
    final completed = found.length + 1 >= _effectiveDifferences.length;
    setState(() => found.add(index));
    if (completed && !_markerEnabled) {
      await _completeCurrentLevel();
    }
  }

  Future<void> _handleMiss() async {
    if (_markerEnabled || _isAdvancing || _timeFailed) return;
    await AudioService.playSfx(AppSound.spotWrong, enabled: _sfxEnabled);
  }

  void _restartTimer() {
    _timer?.cancel();
    _secondsLeft = _timeLimitSeconds;
    _timeFailed = false;
    if (_markerEnabled) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isAdvancing || _showCelebration) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        _failByTimeout();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _failByTimeout() async {
    if (_timeFailed || _isAdvancing || _markerEnabled) return;
    setState(() {
      _secondsLeft = 0;
      _timeFailed = true;
    });
    await AudioService.playSfx(AppSound.gameFail, enabled: _sfxEnabled);
  }

  void _retryCurrentLevel() {
    setState(() {
      found.clear();
      _timeFailed = false;
    });
    _restartTimer();
  }

  Future<void> _completeCurrentLevel() async {
    _timer?.cancel();
    setState(() {
      _isAdvancing = true;
      _showCelebration = true;
    });
    final completedAsset = level.rightAsset;
    await AudioService.playOneShot(AppSound.spotComplete, enabled: _sfxEnabled);
    if (!mounted) return;
    await widget.store.completeSpotDifferenceLevel(completedAsset);
    var restartedCycle = false;
    if (_spotLevels.every(_isCompleted)) {
      await widget.store.resetSpotDifferenceCycle(
        _spotLevels.map((level) => level.rightAsset),
      );
      restartedCycle = true;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(restartedCycle ? '全部找完了，重新开始新一轮。' : '这一关完成，继续下一关。'),
      ),
    );
    setState(() {
      levelIndex = 0;
      found.clear();
      _isAdvancing = false;
      _showCelebration = false;
      _loadSavedMarkers();
    });
    _restartTimer();
  }

  void _nextLevel() {
    final levels = _currentLevels;
    if (levels.isEmpty) return;
    setState(() {
      levelIndex = (levelIndex + 1) % levels.length;
      found.clear();
      _loadSavedMarkers();
    });
    _restartTimer();
  }

  void _addMarkerPoint(Offset point) {
    setState(() => markedPoints.add(point));
  }

  void _undoMarkerPoint() {
    if (markedPoints.isEmpty) return;
    setState(() => markedPoints.removeLast());
  }

  void _clearMarkerPoints() {
    if (markedPoints.isEmpty) return;
    setState(markedPoints.clear);
  }

  Future<void> _saveMarkerPoints() async {
    await widget.store.setSpotDifferenceOverride(level.rightAsset, [
      for (final point in markedPoints) [point.dx, point.dy],
    ]);
    if (!mounted) return;
    setState(() {
      final levels = _currentLevels;
      if (levels.isEmpty || levelIndex >= levels.length) {
        levelIndex = 0;
      }
      found.clear();
      _loadSavedMarkers();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已保存 ${markedPoints.length} 个坐标，立即生效')),
    );
  }

  Future<void> _copyMarkerPoints() async {
    final levels = _currentLevels;
    final lines = [
      '// ${level.title} (${levelIndex + 1}/${levels.length})',
      'differences: [',
      for (final point in markedPoints)
        '  _SpotDifferenceMark(target: Offset(${point.dx.toStringAsFixed(3)}, ${point.dy.toStringAsFixed(3)})),',
      '],',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已复制 ${markedPoints.length} 个坐标')));
  }

  @override
  Widget build(BuildContext context) {
    final markerEnabled = _markerEnabled;
    final levels = _currentLevels;
    if (levels.isEmpty) {
      return const SoftCard(
        color: Color(0xFFFFF8E1),
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            '所有找不同图组都已手动标记完成',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF5B3416),
            ),
          ),
        ),
      );
    }
    if (levelIndex >= levels.length) {
      levelIndex = 0;
      _loadSavedMarkers();
    }
    final effectiveDifferences = _effectiveDifferences;
    final hasSavedOverride = _savedPoints.isNotEmpty;
    return SoftCard(
      color: const Color(0xFFFFF8E1),
      padding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _SpotImageCard(
                        asset: level.leftAsset,
                        referencePoints: markerEnabled
                            ? [
                                for (final difference in effectiveDifferences)
                                  difference.target,
                              ]
                            : const [],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SpotImageCard(
                        asset: level.rightAsset,
                        differences: effectiveDifferences,
                        found: found,
                        onFound: _handleFound,
                        onMiss: _handleMiss,
                        markerMode: markerEnabled,
                        markerPoints: markedPoints,
                        onMark: _addMarkerPoint,
                      ),
                    ),
                  ],
                ),
              ),
              if (markerEnabled) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _SpotMarkerToolbar(
                      label:
                          '第${levelIndex + 1}/${levels.length}张\n已标记${markedPoints.length}处',
                      onUndo: markedPoints.isEmpty ? null : _undoMarkerPoint,
                      onClear: markedPoints.isEmpty ? null : _clearMarkerPoints,
                      onSave: markedPoints.isEmpty && !hasSavedOverride
                          ? null
                          : _saveMarkerPoints,
                      onCopy: markedPoints.isEmpty ? null : _copyMarkerPoints,
                      onNext: _nextLevel,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (!markerEnabled)
            Positioned(
              left: 0,
              right: 0,
              top: 8,
              child: Center(
                child: _SpotCountdownBar(
                  secondsLeft: _secondsLeft,
                  totalSeconds: _timeLimitSeconds,
                  failed: _timeFailed,
                ),
              ),
            ),
          if (_showCelebration) const _CelebrationBurst(dense: true),
          if (_timeFailed)
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
                alignment: Alignment.center,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xEEFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFB45309),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x332D2A32),
                        offset: Offset(0, 5),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '时间到啦，再挑战一次吧',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF5B3416),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _retryCurrentLevel,
                          icon: const Icon(Icons.refresh),
                          label: const Text('重新开始'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpotCountdownBar extends StatelessWidget {
  const _SpotCountdownBar({
    required this.secondsLeft,
    required this.totalSeconds,
    required this.failed,
  });

  final int secondsLeft;
  final int totalSeconds;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final progress = (secondsLeft / totalSeconds).clamp(0.0, 1.0);
    final accent = failed
        ? const Color(0xFFB42318)
        : secondsLeft <= 10
        ? const Color(0xFFDC2626)
        : secondsLeft <= 30
        ? const Color(0xFFF59E0B)
        : const Color(0xFF16A34A);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF7C5B3A), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F2D2A32),
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_rounded, color: accent, size: 21),
            const SizedBox(width: 8),
            SizedBox(
              width: 118,
              height: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Color(0xFFFFF1D6)),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: ColoredBox(color: accent),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$secondsLeft秒',
              style: TextStyle(
                color: accent,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotImageCard extends StatelessWidget {
  const _SpotImageCard({
    required this.asset,
    this.differences = const [],
    this.found = const {},
    this.onFound,
    this.onMiss,
    this.markerMode = false,
    this.markerPoints = const [],
    this.referencePoints = const [],
    this.onMark,
  });

  final String asset;
  final List<_SpotDifferenceMark> differences;
  final Set<int> found;
  final ValueChanged<int>? onFound;
  final VoidCallback? onMiss;
  final bool markerMode;
  final List<Offset> markerPoints;
  final List<Offset> referencePoints;
  final ValueChanged<Offset>? onMark;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: Colors.white,
      padding: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final imageRect = _containedImageRect(outputSize: size);
            return Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: markerMode
                      ? HitTestBehavior.opaque
                      : HitTestBehavior.deferToChild,
                  onTapUp: markerMode
                      ? (details) {
                          if (!imageRect.contains(details.localPosition)) {
                            return;
                          }
                          onMark?.call(
                            Offset(
                              ((details.localPosition.dx - imageRect.left) /
                                      imageRect.width)
                                  .clamp(0.0, 1.0)
                                  .toDouble(),
                              ((details.localPosition.dy - imageRect.top) /
                                      imageRect.height)
                                  .clamp(0.0, 1.0)
                                  .toDouble(),
                            ),
                          );
                        }
                      : (details) {
                          if (!imageRect.contains(details.localPosition)) {
                            return;
                          }
                          onMiss?.call();
                        },
                  child: Container(
                    color: const Color(0xFFFFFBED),
                    alignment: Alignment.center,
                    child: Image.asset(
                      asset,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFFFF8E1),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(18),
                          child: const Text(
                            '本地图片资源加载失败',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF8A5A2B),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (markerMode)
                  for (var i = 0; i < markerPoints.length; i++)
                    _SpotMarkerDot(
                      index: i + 1,
                      target: markerPoints[i],
                      imageRect: imageRect,
                    )
                else ...[
                  for (var i = 0; i < referencePoints.length; i++)
                    _SpotReferenceDot(
                      target: referencePoints[i],
                      imageRect: imageRect,
                    ),
                  for (var i = 0; i < differences.length; i++)
                    _SpotHotspot(
                      target: differences[i].target,
                      imageRect: imageRect,
                      found: found.contains(i),
                      onTap: () => onFound?.call(i),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Rect _containedImageRect({required Size outputSize}) {
    final outputAspect = outputSize.width / outputSize.height;
    late final double width;
    late final double height;
    if (outputAspect > 1.0) {
      height = outputSize.height;
      width = height;
    } else {
      width = outputSize.width;
      height = width;
    }
    return Rect.fromLTWH(
      (outputSize.width - width) / 2,
      (outputSize.height - height) / 2,
      width,
      height,
    );
  }
}

class _SpotHotspot extends StatelessWidget {
  const _SpotHotspot({
    required this.target,
    required this.imageRect,
    required this.found,
    required this.onTap,
  });

  final Offset target;
  final Rect imageRect;
  final bool found;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const tapSize = 82.0;
    return Positioned(
      left: imageRect.left + target.dx * imageRect.width - tapSize / 2,
      top: imageRect.top + target.dy * imageRect.height - tapSize / 2,
      width: tapSize,
      height: tapSize,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: AnimatedScale(
          scale: found ? 1 : 0.72,
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutBack,
          child: Center(
            child: AnimatedOpacity(
              opacity: found ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7DD3A7).withValues(alpha: 0.38),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.94),
                    border: Border.all(
                      color: const Color(0xFFA7F3D0),
                      width: 1.4,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF16A34A),
                    size: 25,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotMarkerToolbar extends StatelessWidget {
  const _SpotMarkerToolbar({
    required this.label,
    required this.onUndo,
    required this.onClear,
    required this.onSave,
    required this.onCopy,
    required this.onNext,
  });

  final String label;
  final VoidCallback? onUndo;
  final VoidCallback? onClear;
  final VoidCallback? onSave;
  final VoidCallback? onCopy;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xEEFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2D2A32), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 76,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 6),
            _SpotMarkerToolButton(
              onPressed: onUndo,
              icon: const Icon(Icons.undo),
              label: '撤销',
            ),
            _SpotMarkerToolButton(
              onPressed: onClear,
              icon: const Icon(Icons.cleaning_services),
              label: '清空',
            ),
            _SpotMarkerToolButton(
              onPressed: onSave,
              icon: const Icon(Icons.save),
              label: '保存',
              filled: true,
            ),
            _SpotMarkerToolButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy),
              label: '复制',
            ),
            _SpotMarkerToolButton(
              onPressed: onNext,
              icon: const Icon(Icons.navigate_next),
              label: '下张',
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotMarkerToolButton extends StatelessWidget {
  const _SpotMarkerToolButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.filled = false,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: 66,
      height: 34,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconTheme.merge(data: const IconThemeData(size: 16), child: icon),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
    if (filled) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: FilledButton(
          style: FilledButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: onPressed,
          child: child,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}

class _SpotMarkerDot extends StatelessWidget {
  const _SpotMarkerDot({
    required this.index,
    required this.target,
    required this.imageRect,
  });

  final int index;
  final Offset target;
  final Rect imageRect;

  @override
  Widget build(BuildContext context) {
    const dotSize = 40.0;
    return Positioned(
      left: imageRect.left + target.dx * imageRect.width - dotSize / 2,
      top: imageRect.top + target.dy * imageRect.height - dotSize / 2,
      width: dotSize,
      height: dotSize,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE85D75),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x552D2A32),
                offset: Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotReferenceDot extends StatelessWidget {
  const _SpotReferenceDot({required this.target, required this.imageRect});

  final Offset target;
  final Rect imageRect;

  @override
  Widget build(BuildContext context) {
    const dotSize = 12.0;
    return Positioned(
      left: imageRect.left + target.dx * imageRect.width - dotSize / 2,
      top: imageRect.top + target.dy * imageRect.height - dotSize / 2,
      width: dotSize,
      height: dotSize,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFD84D),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x662D2A32),
                offset: Offset(0, 1),
                blurRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CelebrationBurst extends StatefulWidget {
  const _CelebrationBurst({this.dense = false});

  final bool dense;

  @override
  State<_CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<_CelebrationBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final List<_ConfettiPiece> pieces;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..forward();
    final random = Random(38);
    final count = widget.dense ? 120 : 80;
    pieces = [
      for (var i = 0; i < count; i++)
        _ConfettiPiece(
          startX: .18 + random.nextDouble() * .64,
          drift: (random.nextDouble() - .5) * .62,
          drop: .36 + random.nextDouble() * .62,
          size: 5 + random.nextDouble() * 8,
          rotation: random.nextDouble() * pi * 2,
          color: _confettiColors[i % _confettiColors.length],
          shape: i % 4,
          delay: random.nextDouble() * .24,
        ),
    ];
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _CelebrationPainter(
                progress: Curves.easeOutCubic.transform(controller.value),
                pieces: pieces,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConfettiPiece {
  const _ConfettiPiece({
    required this.startX,
    required this.drift,
    required this.drop,
    required this.size,
    required this.rotation,
    required this.color,
    required this.shape,
    required this.delay,
  });

  final double startX;
  final double drift;
  final double drop;
  final double size;
  final double rotation;
  final Color color;
  final int shape;
  final double delay;
}

const _confettiColors = [
  Color(0xFFFF6B6B),
  Color(0xFFFFD166),
  Color(0xFF4ECDC4),
  Color(0xFF5B8DEF),
  Color(0xFFFF8C42),
  Color(0xFF8BD450),
];

class _CelebrationPainter extends CustomPainter {
  const _CelebrationPainter({required this.progress, required this.pieces});

  final double progress;
  final List<_ConfettiPiece> pieces;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final piece in pieces) {
      final local = ((progress - piece.delay) / (1 - piece.delay)).clamp(
        0.0,
        1.0,
      );
      if (local <= 0) continue;
      final fade = local < .82 ? 1.0 : (1 - local) / .18;
      paint.color = piece.color.withValues(alpha: fade.clamp(0.0, 1.0));
      final x = (piece.startX + piece.drift * local) * size.width;
      final y = (-.05 + piece.drop * local) * size.height;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.rotation + local * pi * 2.4);
      if (piece.shape == 0) {
        canvas.drawCircle(Offset.zero, piece.size * .42, paint);
      } else if (piece.shape == 1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: piece.size * 1.4,
              height: piece.size * .46,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      } else {
        _drawStar(canvas, paint, piece.size);
      }
      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Paint paint, double size) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? size * .56 : size * .24;
      final angle = -pi / 2 + i * pi / 5;
      final point = Offset(cos(angle) * radius, sin(angle) * radius);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.pieces != pieces;
  }
}

class _MemoryFlipGame extends StatefulWidget {
  const _MemoryFlipGame({required this.store});

  final AppStore store;

  @override
  State<_MemoryFlipGame> createState() => _MemoryFlipGameState();
}

class _MemoryFlipGameState extends State<_MemoryFlipGame> {
  static const int pairCount = 10;
  static const int maxMoves = pairCount * 3;

  late List<_MemoryCardData> cards;
  List<String> assetPool = _defaultMemoryAssets;
  final List<int> opened = [];
  int moves = 0;
  bool waiting = false;
  bool celebrating = false;
  bool showCelebration = false;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    _reset();
    _loadAssetPool();
  }

  void _reset() {
    final selected = List<String>.of(assetPool)..shuffle(Random());
    final picked = selected.take(min(pairCount, selected.length)).toList();
    cards = [
      for (var i = 0; i < picked.length; i++)
        _MemoryCardData(pairId: i, asset: picked[i]),
      for (var i = 0; i < picked.length; i++)
        _MemoryCardData(pairId: i, asset: picked[i]),
    ]..shuffle(Random());
    opened.clear();
    moves = 0;
    waiting = false;
    celebrating = false;
    showCelebration = false;
    failed = false;
  }

  Future<void> _loadAssetPool() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final imageAssets =
        manifest.listAssets().where(_isMemoryCandidate).toSet().toList()
          ..sort();
    if (!mounted || imageAssets.length < pairCount) return;
    setState(() {
      assetPool = imageAssets;
      _reset();
    });
  }

  bool _isMemoryCandidate(String asset) {
    final lower = asset.toLowerCase();
    if (!lower.endsWith('.png') &&
        !lower.endsWith('.jpg') &&
        !lower.endsWith('.jpeg') &&
        !lower.endsWith('.webp')) {
      return false;
    }
    final inAllowedFolder =
        lower.startsWith('assets/pets/') ||
        lower.startsWith('assets/pets/cosmetics/') ||
        lower.startsWith('assets/bosses/') ||
        lower.startsWith('assets/money/');
    if (!inAllowedFolder) return false;
    const excludedParts = [
      '_sheet',
      'sheet_',
      'preview',
      'concept',
      'lineup',
      'source',
    ];
    return !excludedParts.any(lower.contains);
  }

  Future<void> _tapCard(int index) async {
    if (waiting ||
        failed ||
        celebrating ||
        cards[index].matched ||
        opened.contains(index)) {
      return;
    }
    await AudioService.playSfx(
      AppSound.tap,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
    setState(() => opened.add(index));
    if (opened.length < 2) return;
    setState(() => moves++);
    final first = opened[0];
    final second = opened[1];
    if (cards[first].pairId == cards[second].pairId) {
      await AudioService.playSfx(
        AppSound.correct,
        enabled: widget.store.progress.settings['sfx'] ?? true,
      );
      setState(() {
        cards[first] = cards[first].copyWith(matched: true);
        cards[second] = cards[second].copyWith(matched: true);
        opened.clear();
      });
      if (cards.every((card) => card.matched)) {
        await _celebrateComplete();
      } else {
        await _checkMoveLimit();
      }
      return;
    }
    await AudioService.playSfx(
      AppSound.wrong,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
    waiting = true;
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      opened.clear();
      waiting = false;
    });
    await _checkMoveLimit();
  }

  Future<void> _checkMoveLimit() async {
    if (failed || celebrating || cards.every((card) => card.matched)) return;
    if (moves < maxMoves) return;
    setState(() => failed = true);
    await AudioService.playSfx(
      AppSound.gameFail,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
  }

  Future<void> _celebrateComplete() async {
    if (celebrating) return;
    setState(() {
      celebrating = true;
      showCelebration = true;
    });
    await AudioService.playOneShot(
      AppSound.gameComplete,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
    if (!mounted) return;
    setState(() {
      celebrating = false;
      showCelebration = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _GameShell(
      title: '记忆翻牌',
      subtitle: '翻开两张一样的卡通图片，配成一对就留下来。',
      color: const Color(0xFFE3F2FD),
      actionLabel: null,
      onAction: null,
      trailing: _MemoryGameToolbar(
        moves: moves,
        maxMoves: maxMoves,
        failed: failed,
        onRestart: () => setState(_reset),
      ),
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const columns = 5;
              const rows = 4;
              const gap = 8.0;
              final tileWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              final tileHeight =
                  (constraints.maxHeight - gap * (rows - 1)) / rows;
              final aspectRatio = tileWidth / tileHeight;
              return GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                  childAspectRatio: aspectRatio,
                ),
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  final card = cards[index];
                  return _MemoryTile(
                    card: card,
                    visible: card.matched || opened.contains(index),
                    locked: failed,
                    onTap: () => _tapCard(index),
                  );
                },
              );
            },
          ),
          if (showCelebration) const _CelebrationBurst(dense: true),
          if (failed)
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xEEFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF7C5B3A),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x332D2A32),
                      offset: Offset(0, 5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  child: Text(
                    '步数用完啦，再试一局吧',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF5B3416),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemoryGameToolbar extends StatelessWidget {
  const _MemoryGameToolbar({
    required this.moves,
    required this.maxMoves,
    required this.failed,
    required this.onRestart,
  });

  final int moves;
  final int maxMoves;
  final bool failed;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final nearLimit = moves >= maxMoves - 5 && !failed;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: failed
                ? const Color(0xFFFFE0E0)
                : nearLimit
                ? const Color(0xFFFFF3CD)
                : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: failed ? const Color(0xFFD9534F) : const Color(0xFF7C5B3A),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              '步数 $moves/$maxMoves',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: failed
                    ? const Color(0xFFB42318)
                    : const Color(0xFF5B3416),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: onRestart,
          icon: const Icon(Icons.refresh),
          label: const Text('重新开始'),
        ),
      ],
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({
    required this.card,
    required this.visible,
    required this.locked,
    required this.onTap,
  });

  final _MemoryCardData card;
  final bool visible;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: card.matched
          ? const Color(0xFFA7F3D0)
          : visible
          ? const Color(0xFFFFF8E1)
          : locked
          ? const Color(0xFFE8E8E8)
          : const Color(0xFFFFC6D9),
      padding: const EdgeInsets.all(8),
      onTap: locked ? null : onTap,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: visible
              ? ClipRRect(
                  key: ValueKey(card.asset),
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(card.asset, fit: BoxFit.contain),
                )
              : const Icon(
                  Icons.auto_awesome,
                  key: ValueKey('back'),
                  size: 44,
                  color: Color(0xFF2D2A32),
                ),
        ),
      ),
    );
  }
}

class _GomokuGame extends StatefulWidget {
  const _GomokuGame({required this.store});

  final AppStore store;

  @override
  State<_GomokuGame> createState() => _GomokuGameState();
}

class _GomokuGameState extends State<_GomokuGame> {
  static const int size = 13;
  late List<int> board;
  _GomokuDifficulty? difficulty;
  int turn = 1;
  int winner = 0;
  bool celebrating = false;
  bool showCelebration = false;
  String message = '你先下黑棋，连成五颗就胜利。';

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    board = List.filled(size * size, 0);
    turn = 1;
    winner = 0;
    celebrating = false;
    showCelebration = false;
    message = '你先下黑棋，连成五颗就胜利。';
  }

  void _startDifficulty(_GomokuDifficulty value) {
    setState(() {
      difficulty = value;
      _reset();
      message = '${value.label}模式：你先下黑棋，连成五颗就胜利。';
    });
  }

  Future<void> _tapCell(int index) async {
    if (winner != 0 || board[index] != 0 || turn != 1) return;
    await AudioService.playSfx(
      AppSound.gomokuPlayerStone,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
    if (!mounted) return;
    setState(() {
      board[index] = 1;
      winner = _winnerAt(index, 1) ? 1 : 0;
      if (winner == 1) {
        message = '黑棋胜利！这一手很漂亮。';
      } else if (!board.contains(0)) {
        winner = 3;
        message = '平局，也是一场认真思考的对局。';
      } else {
        turn = 2;
        message = '果果正在思考白棋。';
      }
    });
    if (winner == 1) {
      await _celebrateWin();
    } else if (winner == 0) {
      Future<void>.delayed(const Duration(milliseconds: 260), _aiMove);
    }
  }

  Future<void> _aiMove() async {
    if (!mounted || winner != 0 || turn != 2) return;
    final move = _bestAiMove();
    await AudioService.playSfx(
      AppSound.gomokuAiStone,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
    if (!mounted || winner != 0 || turn != 2) return;
    setState(() {
      board[move] = 2;
      winner = _winnerAt(move, 2) ? 2 : 0;
      if (winner == 2) {
        message = '白棋连成五颗，再挑战一次吧。';
      } else if (!board.contains(0)) {
        winner = 3;
        message = '平局，双方都很稳。';
      } else {
        turn = 1;
        message = '轮到你下黑棋。';
      }
    });
    if (winner == 2) {
      await _playFailSound();
    }
  }

  Future<void> _playFailSound() async {
    await AudioService.playSfx(
      AppSound.gameFail,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
  }

  Future<void> _celebrateWin() async {
    if (celebrating) return;
    setState(() {
      celebrating = true;
      showCelebration = true;
    });
    await AudioService.playOneShot(
      AppSound.gameComplete,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
    if (!mounted) return;
    setState(() {
      celebrating = false;
      showCelebration = false;
    });
  }

  int _bestAiMove() {
    final empty = [
      for (var i = 0; i < board.length; i++)
        if (board[i] == 0) i,
    ];

    final mode = difficulty ?? _GomokuDifficulty.normal;
    if (mode == _GomokuDifficulty.easy && Random().nextDouble() < .35) {
      empty.sort((a, b) => _centerScore(b).compareTo(_centerScore(a)));
      final top = empty.take(min(10, empty.length)).toList()..shuffle(Random());
      return top.first;
    }

    for (final index in empty) {
      if (_wouldWin(index, 2)) return index;
    }
    if (mode != _GomokuDifficulty.easy || Random().nextDouble() < .7) {
      for (final index in empty) {
        if (_wouldWin(index, 1)) return index;
      }
    }

    empty.sort((a, b) => _moveScore(b).compareTo(_moveScore(a)));
    if (mode == _GomokuDifficulty.normal) {
      final top = empty.take(min(3, empty.length)).toList();
      return top[Random().nextInt(top.length)];
    }
    if (mode == _GomokuDifficulty.easy) {
      final top = empty.take(min(8, empty.length)).toList();
      return top[Random().nextInt(top.length)];
    }
    return empty.first;
  }

  bool _wouldWin(int index, int player) {
    board[index] = player;
    final win = _winnerAt(index, player);
    board[index] = 0;
    return win;
  }

  int _moveScore(int index) {
    final centerScore = _centerScore(index);
    final attack = _scoreAs(index, 2);
    final defense = _scoreAs(index, 1);
    return attack * 2 + (defense * 1.65).round() + centerScore;
  }

  int _centerScore(int index) {
    final row = index ~/ size;
    final col = index % size;
    final center = size ~/ 2;
    return 30 - ((row - center).abs() + (col - center).abs());
  }

  int _scoreAs(int index, int player) {
    board[index] = player;
    var score = 0;
    const dirs = [
      [1, 0],
      [0, 1],
      [1, 1],
      [1, -1],
    ];
    for (final dir in dirs) {
      final a = _ray(index, dir[0], dir[1], player);
      final b = _ray(index, -dir[0], -dir[1], player);
      final count = 1 + a.count + b.count;
      final openEnds = (a.open ? 1 : 0) + (b.open ? 1 : 0);
      score += _patternScore(count, openEnds);
    }
    board[index] = 0;
    return score;
  }

  int _patternScore(int count, int openEnds) {
    if (count >= 5) return 1000000;
    if (count == 4 && openEnds == 2) return 260000;
    if (count == 4 && openEnds == 1) return 90000;
    if (count == 3 && openEnds == 2) return 42000;
    if (count == 3 && openEnds == 1) return 9000;
    if (count == 2 && openEnds == 2) return 2800;
    if (count == 2 && openEnds == 1) return 800;
    if (count == 1 && openEnds == 2) return 120;
    return 20;
  }

  ({int count, bool open}) _ray(int index, int dr, int dc, int player) {
    var row = index ~/ size + dr;
    var col = index % size + dc;
    var count = 0;
    while (_inside(row, col) && board[row * size + col] == player) {
      count++;
      row += dr;
      col += dc;
    }
    return (
      count: count,
      open: _inside(row, col) && board[row * size + col] == 0,
    );
  }

  bool _inside(int row, int col) {
    return row >= 0 && row < size && col >= 0 && col < size;
  }

  bool _winnerAt(int index, int player) {
    const dirs = [
      [1, 0],
      [0, 1],
      [1, 1],
      [1, -1],
    ];
    return dirs.any((dir) {
      final a = _ray(index, dir[0], dir[1], player).count;
      final b = _ray(index, -dir[0], -dir[1], player).count;
      return 1 + a + b >= 5;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (difficulty == null) {
      return _GomokuDifficultyPicker(onSelect: _startDifficulty);
    }
    final pet = petById(widget.store.progress.selectedPet);
    return _GomokuDesignedScene(
      board: board,
      size: size,
      winner: winner,
      difficulty: difficulty!,
      pet: pet,
      level: widget.store.progress.petLevel,
      cosmetics: widget.store.equippedCosmeticsForPet(pet.id),
      turn: turn,
      message: message,
      showCelebration: showCelebration,
      onTapIndex: _tapCell,
      onRestart: () => setState(_reset),
      onChangeDifficulty: () => setState(() => difficulty = null),
    );
  }
}

class _GomokuDesignedScene extends StatelessWidget {
  const _GomokuDesignedScene({
    required this.board,
    required this.size,
    required this.winner,
    required this.difficulty,
    required this.pet,
    required this.level,
    required this.cosmetics,
    required this.turn,
    required this.message,
    required this.showCelebration,
    required this.onTapIndex,
    required this.onRestart,
    required this.onChangeDifficulty,
  });

  final List<int> board;
  final int size;
  final int winner;
  final _GomokuDifficulty difficulty;
  final PetDefinition pet;
  final int level;
  final Set<String> cosmetics;
  final int turn;
  final String message;
  final bool showCelebration;
  final ValueChanged<int> onTapIndex;
  final VoidCallback onRestart;
  final VoidCallback onChangeDifficulty;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFD36B), Color(0xFFC47A36), Color(0xFFFFF3D2)],
            stops: [0, .18, 1],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(left: -18, top: 24, child: _GomokuPlantAccent()),
            const Positioned(
              right: -18,
              bottom: -10,
              child: _GomokuLeafCluster(),
            ),
            const Positioned(
              left: 18,
              bottom: 18,
              child: _GomokuNotebookAccent(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _GomokuBoardShell(
                      board: board,
                      size: size,
                      winner: winner,
                      onTapIndex: onTapIndex,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 266,
                    child: _GomokuDesignedStatusPanel(
                      difficulty: difficulty,
                      pet: pet,
                      level: level,
                      cosmetics: cosmetics,
                      turn: turn,
                      winner: winner,
                      message: message,
                      onRestart: onRestart,
                      onChangeDifficulty: onChangeDifficulty,
                    ),
                  ),
                ],
              ),
            ),
            if (winner != 0) Center(child: _GomokuResultNotice(winner: winner)),
            if (showCelebration) const _CelebrationBurst(dense: true),
          ],
        ),
      ),
    );
  }
}

class _GomokuResultNotice extends StatelessWidget {
  const _GomokuResultNotice({required this.winner});

  final int winner;

  @override
  Widget build(BuildContext context) {
    final text = winner == 1
        ? '哇~真厉害！'
        : winner == 2
        ? '你输了，下次加油'
        : '平局啦，再来一局！';
    final color = winner == 1
        ? const Color(0xFF16A34A)
        : winner == 2
        ? const Color(0xFFDC2626)
        : const Color(0xFFF59E0B);
    final icon = winner == 1
        ? Icons.emoji_events_rounded
        : winner == 2
        ? Icons.favorite_rounded
        : Icons.handshake_rounded;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x552D2A32),
            offset: Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFF5B3416),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GomokuBoardShell extends StatelessWidget {
  const _GomokuBoardShell({
    required this.board,
    required this.size,
    required this.winner,
    required this.onTapIndex,
  });

  final List<int> board;
  final int size;
  final int winner;
  final ValueChanged<int> onTapIndex;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF9D5E2A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6F3D16), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x553D210A),
            offset: Offset(0, 9),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFD3B985),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF91A069), width: 6),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC97A35), Color(0xFF8E4F22)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x443D210A),
                    offset: Offset(0, 6),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6C477),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF6F3D16),
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: _GomokuBoard(
                      board: board,
                      size: size,
                      winner: winner,
                      onTapIndex: onTapIndex,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GomokuPlantAccent extends StatelessWidget {
  const _GomokuPlantAccent();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 150,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 70,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFFD9A45C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF8A5A2B), width: 2),
            ),
          ),
          for (final item in const [
            (Offset(30, 28), -0.6, 38.0),
            (Offset(56, 12), -0.25, 44.0),
            (Offset(78, 28), 0.45, 38.0),
            (Offset(46, 54), -0.9, 34.0),
            (Offset(86, 58), 0.75, 32.0),
          ])
            Positioned(
              left: item.$1.dx,
              top: item.$1.dy,
              child: Transform.rotate(
                angle: item.$2,
                child: Icon(
                  Icons.eco,
                  color: const Color(0xFF5FA843),
                  size: item.$3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GomokuLeafCluster extends StatelessWidget {
  const _GomokuLeafCluster();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 110,
      child: Stack(
        children: [
          for (final item in const [
            (Offset(18, 38), -0.7, 42.0),
            (Offset(48, 20), -0.25, 48.0),
            (Offset(74, 42), 0.45, 44.0),
            (Offset(36, 66), -1.0, 38.0),
          ])
            Positioned(
              left: item.$1.dx,
              top: item.$1.dy,
              child: Transform.rotate(
                angle: item.$2,
                child: Icon(
                  Icons.eco,
                  color: const Color(0xFF4F9A37).withValues(alpha: .9),
                  size: item.$3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GomokuNotebookAccent extends StatelessWidget {
  const _GomokuNotebookAccent();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -.18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1D6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFC28A4F), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x443D210A),
              offset: Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: const SizedBox(
          width: 88,
          height: 112,
          child: Center(
            child: Icon(
              Icons.edit_note_rounded,
              color: Color(0xFF8A8F3D),
              size: 52,
            ),
          ),
        ),
      ),
    );
  }
}

class _GomokuDesignedStatusPanel extends StatelessWidget {
  const _GomokuDesignedStatusPanel({
    required this.difficulty,
    required this.pet,
    required this.level,
    required this.cosmetics,
    required this.turn,
    required this.winner,
    required this.message,
    required this.onRestart,
    required this.onChangeDifficulty,
  });

  final _GomokuDifficulty difficulty;
  final PetDefinition pet;
  final int level;
  final Set<String> cosmetics;
  final int turn;
  final int winner;
  final String message;
  final VoidCallback onRestart;
  final VoidCallback onChangeDifficulty;

  @override
  Widget build(BuildContext context) {
    final status = switch (winner) {
      1 => '你赢啦',
      2 => '再试一次',
      3 => '平局',
      _ => turn == 1 ? '轮到你下黑棋' : '果果思考中',
    };
    final statusColor = switch (winner) {
      1 => const Color(0xFF16A34A),
      2 => const Color(0xFFDC2626),
      3 => const Color(0xFFF59E0B),
      _ => const Color(0xFF6B3A18),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE09B48), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x553D210A),
            offset: Offset(0, 7),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            return Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E8),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFF0C780)),
                    ),
                  ),
                ),
                const Positioned(
                  left: 20,
                  top: 18,
                  child: Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFD36B),
                    size: 28,
                  ),
                ),
                const Positioned(
                  right: 20,
                  top: 18,
                  child: Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFD36B),
                    size: 28,
                  ),
                ),
                Positioned(
                  left: 56,
                  right: 56,
                  top: h * .035,
                  height: h * .085,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8BC34A), Color(0xFF4D9A2A)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF3E7C20)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x332D2A32),
                          offset: Offset(0, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        difficulty.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: Color(0x66000000),
                              offset: Offset(0, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  top: h * .16,
                  height: h * .105,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF6DD).withValues(alpha: .96),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFE5C58F),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        const _GomokuStoneDot(
                          color: Colors.black,
                          border: Colors.black,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 32,
                  right: 32,
                  top: h * .28,
                  height: h * .32,
                  child: _GomokuPetResultView(
                    pet: pet,
                    level: level,
                    cosmetics: cosmetics,
                    winner: winner,
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  top: h * .61,
                  height: h * .075,
                  child: Center(
                    child: Text(
                      winner == 0 ? '连成五颗就胜利' : message,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF6B3A18),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: h * .15,
                  height: h * .11,
                  child: FilledButton.icon(
                    onPressed: onRestart,
                    icon: const Icon(Icons.refresh, size: 30),
                    label: const Text('重新开始'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C22),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: const BorderSide(
                          color: Color(0xFFB95E12),
                          width: 2,
                        ),
                      ),
                      elevation: 5,
                    ),
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: h * .025,
                  height: h * .11,
                  child: FilledButton.icon(
                    onPressed: onChangeDifficulty,
                    icon: const Icon(Icons.casino, size: 28),
                    label: const Text('换难度'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF67B63A),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: const BorderSide(
                          color: Color(0xFF3E7C20),
                          width: 2,
                        ),
                      ),
                      elevation: 5,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GomokuPetResultView extends StatelessWidget {
  const _GomokuPetResultView({
    required this.pet,
    required this.level,
    required this.cosmetics,
    required this.winner,
  });

  final PetDefinition pet;
  final int level;
  final Set<String> cosmetics;
  final int winner;

  @override
  Widget build(BuildContext context) {
    final resultAsset = _resultAssetFor(pet.id, winner == 1);
    if (winner != 0 && resultAsset != null) {
      return Image.asset(resultAsset, fit: BoxFit.contain);
    }
    return PetAvatar(
      pet: pet,
      level: level,
      size: 210,
      cosmeticIds: cosmetics,
      cheering: winner == 1,
      mood: winner == 2 ? PetMood.sad : PetMood.normal,
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

class _GomokuStoneDot extends StatelessWidget {
  const _GomokuStoneDot({required this.color, required this.border});

  final Color color;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: border, width: 1.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332D2A32),
            offset: Offset(0, 2),
            blurRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _GomokuBoard extends StatelessWidget {
  const _GomokuBoard({
    required this.board,
    required this.size,
    required this.winner,
    required this.onTapIndex,
  });

  final List<int> board;
  final int size;
  final int winner;
  final ValueChanged<int> onTapIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: SizedBox.square(
            dimension: side,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final index = _indexFromPosition(details.localPosition, side);
                if (index != null) onTapIndex(index);
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE0A3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF8A5A2B), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x332D2A32),
                      offset: Offset(0, 5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: _GomokuBoardPainter(
                    board: List<int>.of(board),
                    boardSize: size,
                    winner: winner,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int? _indexFromPosition(Offset position, double side) {
    final padding = side * .07;
    final gridSide = side - padding * 2;
    final cell = gridSide / (size - 1);
    final col = ((position.dx - padding) / cell).round();
    final row = ((position.dy - padding) / cell).round();
    if (row < 0 || row >= size || col < 0 || col >= size) return null;
    final point = Offset(padding + col * cell, padding + row * cell);
    if ((position - point).distance > cell * .48) return null;
    return row * size + col;
  }
}

class _GomokuDifficultyPicker extends StatelessWidget {
  const _GomokuDifficultyPicker({required this.onSelect});

  final ValueChanged<_GomokuDifficulty> onSelect;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: const Color(0xFFFFE4B5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '选择五子棋难度',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            '简单更适合练习落子，普通会认真防守，困难会尽量寻找最佳位置。',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < _GomokuDifficulty.values.length; i++) ...[
                  Expanded(
                    child: SoftCard(
                      color: _GomokuDifficulty.values[i].color,
                      onTap: () => onSelect(_GomokuDifficulty.values[i]),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _GomokuDifficulty.values[i].icon,
                            size: 54,
                            color: const Color(0xFF2D2A32),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _GomokuDifficulty.values[i].label,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _GomokuDifficulty.values[i].description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i != _GomokuDifficulty.values.length - 1)
                    const SizedBox(width: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GomokuBoardPainter extends CustomPainter {
  const _GomokuBoardPainter({
    required this.board,
    required this.boardSize,
    required this.winner,
  });

  final List<int> board;
  final int boardSize;
  final int winner;

  @override
  void paint(Canvas canvas, Size size) {
    final side = min(size.width, size.height);
    final padding = side * .07;
    final gridSide = side - padding * 2;
    final cell = gridSide / (boardSize - 1);
    final boardRect = Offset.zero & size;

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFE9B7), Color(0xFFEFB669)],
      ).createShader(boardRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect.deflate(4), const Radius.circular(8)),
      bgPaint,
    );

    final linePaint = Paint()
      ..color = const Color(0xAA5C371A)
      ..strokeWidth = max(1.0, side * .0024)
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < boardSize; i++) {
      final p = padding + i * cell;
      canvas.drawLine(
        Offset(padding, p),
        Offset(padding + gridSide, p),
        linePaint,
      );
      canvas.drawLine(
        Offset(p, padding),
        Offset(p, padding + gridSide),
        linePaint,
      );
    }

    final starPaint = Paint()..color = const Color(0xCC5C371A);
    for (final point in _starPoints()) {
      canvas.drawCircle(
        Offset(padding + point.dx * cell, padding + point.dy * cell),
        side * .0065,
        starPaint,
      );
    }

    for (var index = 0; index < board.length; index++) {
      final value = board[index];
      if (value == 0) continue;
      final row = index ~/ boardSize;
      final col = index % boardSize;
      final center = Offset(padding + col * cell, padding + row * cell);
      _paintStone(canvas, center, cell * .36, value);
    }
  }

  List<Offset> _starPoints() {
    if (boardSize < 9) return const [];
    final low = boardSize == 13 ? 3.0 : 2.0;
    final mid = (boardSize - 1) / 2;
    final high = boardSize - 1 - low;
    return [
      Offset(low, low),
      Offset(mid, low),
      Offset(high, low),
      Offset(low, mid),
      Offset(mid, mid),
      Offset(high, mid),
      Offset(low, high),
      Offset(mid, high),
      Offset(high, high),
    ];
  }

  void _paintStone(Canvas canvas, Offset center, double radius, int value) {
    final shadow = Paint()..color = const Color(0x442D2A32);
    canvas.drawCircle(
      center.translate(radius * .13, radius * .18),
      radius,
      shadow,
    );
    final rect = Rect.fromCircle(center: center, radius: radius);
    final stonePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.35, -.45),
        radius: .95,
        colors: value == 1
            ? const [Color(0xFF77717B), Color(0xFF2D2A32), Color(0xFF111111)]
            : const [Colors.white, Color(0xFFF7F0E0), Color(0xFFD8C9B3)],
      ).createShader(rect);
    canvas.drawCircle(center, radius, stonePaint);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = value == 1 ? const Color(0xFF1A171C) : const Color(0xFF9F8D73)
        ..strokeWidth = max(1.0, radius * .08)
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      center.translate(-radius * .28, -radius * .34),
      radius * .16,
      Paint()
        ..color = value == 1
            ? const Color(0x55FFFFFF)
            : const Color(0xCCFFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _GomokuBoardPainter oldDelegate) {
    return oldDelegate.board != board ||
        oldDelegate.boardSize != boardSize ||
        oldDelegate.winner != winner;
  }
}

class _GameShell extends StatelessWidget {
  const _GameShell({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.child,
    required this.actionLabel,
    required this.onAction,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Color color;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: color,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (actionLabel != null && onAction != null)
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh),
                  label: Text(actionLabel!),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _GameMenuCard extends StatelessWidget {
  const _GameMenuCard({
    required this.game,
    required this.active,
    required this.onTap,
  });

  final _LeisureGame game;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: active ? game.color : Colors.white,
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(game.imageAsset, fit: BoxFit.cover),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: .48),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: game.color,
                child: Icon(game.icon, color: game.accent, size: 27),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      game.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeisureGame {
  const _LeisureGame({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.accent,
    required this.music,
    required this.imageAsset,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color accent;
  final AppMusicScene music;
  final String imageAsset;
}

enum _GomokuDifficulty {
  easy('简单', '轻松练习，白棋会留出机会。', Icons.sentiment_satisfied_alt, Color(0xFFE3F2FD)),
  normal('普通', '会进攻也会防守，适合认真对局。', Icons.psychology, Color(0xFFFFF8E1)),
  hard('困难', '更会计算连线，挑战感更强。', Icons.local_fire_department, Color(0xFFFFD6D6));

  const _GomokuDifficulty(this.label, this.description, this.icon, this.color);

  final String label;
  final String description;
  final IconData icon;
  final Color color;
}

class _SpotLevel {
  const _SpotLevel({
    required this.title,
    required this.leftAsset,
    required this.rightAsset,
    required this.differences,
  });

  final String title;
  final String leftAsset;
  final String rightAsset;
  final List<_SpotDifferenceMark> differences;
}

class _SpotDifferenceMark {
  const _SpotDifferenceMark({required this.target});

  final Offset target;
}

class _MemoryCardData {
  const _MemoryCardData({
    required this.pairId,
    required this.asset,
    this.matched = false,
  });

  final int pairId;
  final String asset;
  final bool matched;

  _MemoryCardData copyWith({bool? matched}) {
    return _MemoryCardData(
      pairId: pairId,
      asset: asset,
      matched: matched ?? this.matched,
    );
  }
}

const _games = [
  _LeisureGame(
    id: 'spot',
    title: '找不同',
    subtitle: '多张图片关卡，找出右图的小变化。',
    icon: Icons.travel_explore,
    color: Color(0xFFFFF8E1),
    accent: Color(0xFFE85D75),
    music: AppMusicScene.spotDifference,
    imageAsset: 'assets/leisure/cards/spot_difference_card.png',
  ),
  _LeisureGame(
    id: 'memory',
    title: '记忆翻牌',
    subtitle: '彩色卡通图片配对，练记忆力。',
    icon: Icons.style,
    color: Color(0xFFE3F2FD),
    accent: Color(0xFF2563EB),
    music: AppMusicScene.memoryFlip,
    imageAsset: 'assets/leisure/cards/memory_flip_card.png',
  ),
  _LeisureGame(
    id: 'gomoku',
    title: '五子棋',
    subtitle: '更聪明的果果，会进攻也会防守。',
    icon: Icons.grid_on,
    color: Color(0xFFFFE4B5),
    accent: Color(0xFFFF8C42),
    music: AppMusicScene.gomoku,
    imageAsset: 'assets/leisure/cards/gomoku_card.png',
  ),
];

const _spotLevels = [
  _SpotLevel(
    title: '小狗草地',
    leftAsset: 'assets/leisure/spot/ai/level_1_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_1_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.42, .44)),
      _SpotDifferenceMark(target: Offset(.64, .50)),
      _SpotDifferenceMark(target: Offset(.79, .15)),
      _SpotDifferenceMark(target: Offset(.60, .88)),
      _SpotDifferenceMark(target: Offset(.86, .56)),
    ],
  ),
  _SpotLevel(
    title: '快乐伙伴',
    leftAsset: 'assets/leisure/spot/ai/level_2_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_2_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.097, 0.672)),
      _SpotDifferenceMark(target: Offset(0.370, 0.703)),
      _SpotDifferenceMark(target: Offset(0.854, 0.498)),
      _SpotDifferenceMark(target: Offset(0.760, 0.762)),
      _SpotDifferenceMark(target: Offset(0.913, 0.758)),
    ],
  ),
  _SpotLevel(
    title: '野餐草地',
    leftAsset: 'assets/leisure/spot/ai/level_3_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_3_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.854, 0.420)),
      _SpotDifferenceMark(target: Offset(0.124, 0.561)),
      _SpotDifferenceMark(target: Offset(0.417, 0.730)),
      _SpotDifferenceMark(target: Offset(0.881, 0.885)),
      _SpotDifferenceMark(target: Offset(0.786, 0.518)),
    ],
  ),
  _SpotLevel(
    title: '沙滩城堡',
    leftAsset: 'assets/leisure/spot/ai/level_4_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_4_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.13, .52)),
      _SpotDifferenceMark(target: Offset(.54, .13)),
      _SpotDifferenceMark(target: Offset(.82, .55)),
      _SpotDifferenceMark(target: Offset(.66, .76)),
      _SpotDifferenceMark(target: Offset(.82, .81)),
    ],
  ),
  _SpotLevel(
    title: '阳光游乐场',
    leftAsset: 'assets/leisure/spot/ai/level_5_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_5_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.778, 0.346)),
      _SpotDifferenceMark(target: Offset(0.680, 0.324)),
      _SpotDifferenceMark(target: Offset(0.251, 0.424)),
      _SpotDifferenceMark(target: Offset(0.284, 0.754)),
      _SpotDifferenceMark(target: Offset(0.118, 0.894)),
    ],
  ),
  _SpotLevel(
    title: '课堂书桌',
    leftAsset: 'assets/leisure/spot/ai/level_6_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_6_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.674, 0.812)),
      _SpotDifferenceMark(target: Offset(0.382, 0.883)),
      _SpotDifferenceMark(target: Offset(0.128, 0.395)),
      _SpotDifferenceMark(target: Offset(0.346, 0.504)),
      _SpotDifferenceMark(target: Offset(0.844, 0.559)),
    ],
  ),
  _SpotLevel(
    title: '农场小院',
    leftAsset: 'assets/leisure/spot/ai/level_7_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_7_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.067, 0.816)),
      _SpotDifferenceMark(target: Offset(0.485, 0.717)),
      _SpotDifferenceMark(target: Offset(0.874, 0.785)),
      _SpotDifferenceMark(target: Offset(0.614, 0.441)),
      _SpotDifferenceMark(target: Offset(0.032, 0.408)),
    ],
  ),
  _SpotLevel(
    title: '森林小路',
    leftAsset: 'assets/leisure/spot/ai/level_8_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_8_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.686, 0.867)),
      _SpotDifferenceMark(target: Offset(0.325, 0.887)),
      _SpotDifferenceMark(target: Offset(0.335, 0.604)),
      _SpotDifferenceMark(target: Offset(0.225, 0.732)),
    ],
  ),
  _SpotLevel(
    title: '烘焙厨房',
    leftAsset: 'assets/leisure/spot/ai/level_9_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_9_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.493, 0.754)),
      _SpotDifferenceMark(target: Offset(0.821, 0.873)),
      _SpotDifferenceMark(target: Offset(0.813, 0.500)),
      _SpotDifferenceMark(target: Offset(0.507, 0.475)),
      _SpotDifferenceMark(target: Offset(0.335, 0.186)),
      _SpotDifferenceMark(target: Offset(0.186, 0.557)),
    ],
  ),
  _SpotLevel(
    title: '海底水族箱',
    leftAsset: 'assets/leisure/spot/ai/level_10_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_10_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.378, 0.338)),
      _SpotDifferenceMark(target: Offset(0.364, 0.648)),
      _SpotDifferenceMark(target: Offset(0.091, 0.607)),
      _SpotDifferenceMark(target: Offset(0.932, 0.512)),
      _SpotDifferenceMark(target: Offset(0.846, 0.703)),
    ],
  ),
  _SpotLevel(
    title: '花园茶会',
    leftAsset: 'assets/leisure/spot/ai/level_11_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_11_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.809, 0.838)),
      _SpotDifferenceMark(target: Offset(0.846, 0.611)),
      _SpotDifferenceMark(target: Offset(0.645, 0.504)),
      _SpotDifferenceMark(target: Offset(0.428, 0.153)),
      _SpotDifferenceMark(target: Offset(0.145, 0.192)),
    ],
  ),
  _SpotLevel(
    title: '恐龙玩具岛',
    leftAsset: 'assets/leisure/spot/ai/level_12_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_12_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.346, 0.182)),
      _SpotDifferenceMark(target: Offset(0.905, 0.221)),
      _SpotDifferenceMark(target: Offset(0.842, 0.740)),
      _SpotDifferenceMark(target: Offset(0.167, 0.894)),
      _SpotDifferenceMark(target: Offset(0.085, 0.199)),
    ],
  ),
  _SpotLevel(
    title: '睡前小屋',
    leftAsset: 'assets/leisure/spot/ai/level_13_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_13_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.130, 0.461)),
      _SpotDifferenceMark(target: Offset(0.883, 0.623)),
      _SpotDifferenceMark(target: Offset(0.120, 0.863)),
      _SpotDifferenceMark(target: Offset(0.778, 0.170)),
      _SpotDifferenceMark(target: Offset(0.335, 0.484)),
    ],
  ),
  _SpotLevel(
    title: '糖果小店',
    leftAsset: 'assets/leisure/spot/ai/level_14_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_14_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.583, 0.586)),
      _SpotDifferenceMark(target: Offset(0.331, 0.287)),
      _SpotDifferenceMark(target: Offset(0.124, 0.373)),
      _SpotDifferenceMark(target: Offset(0.155, 0.732)),
      _SpotDifferenceMark(target: Offset(0.835, 0.738)),
    ],
  ),
  _SpotLevel(
    title: '雨天窗边',
    leftAsset: 'assets/leisure/spot/ai/level_15_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_15_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.167, 0.475)),
      _SpotDifferenceMark(target: Offset(0.440, 0.199)),
      _SpotDifferenceMark(target: Offset(0.856, 0.506)),
      _SpotDifferenceMark(target: Offset(0.376, 0.795)),
      _SpotDifferenceMark(target: Offset(0.606, 0.473)),
    ],
  ),
  _SpotLevel(
    title: '雪地院子',
    leftAsset: 'assets/leisure/spot/ai/level_16_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_16_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.649, 0.408)),
      _SpotDifferenceMark(target: Offset(0.544, 0.859)),
      _SpotDifferenceMark(target: Offset(0.838, 0.793)),
      _SpotDifferenceMark(target: Offset(0.372, 0.773)),
      _SpotDifferenceMark(target: Offset(0.604, 0.182)),
    ],
  ),
  _SpotLevel(
    title: '音乐角落',
    leftAsset: 'assets/leisure/spot/ai/level_17_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_17_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.296, 0.404)),
      _SpotDifferenceMark(target: Offset(0.776, 0.578)),
      _SpotDifferenceMark(target: Offset(0.860, 0.799)),
      _SpotDifferenceMark(target: Offset(0.471, 0.648)),
      _SpotDifferenceMark(target: Offset(0.725, 0.344)),
    ],
  ),
  _SpotLevel(
    title: '太空书桌',
    leftAsset: 'assets/leisure/spot/ai/level_18_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_18_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.337, 0.518)),
      _SpotDifferenceMark(target: Offset(0.218, 0.818)),
      _SpotDifferenceMark(target: Offset(0.881, 0.533)),
      _SpotDifferenceMark(target: Offset(0.497, 0.231)),
      _SpotDifferenceMark(target: Offset(0.298, 0.145)),
    ],
  ),
  _SpotLevel(
    title: '绘画桌面',
    leftAsset: 'assets/leisure/spot/ai/level_19_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_19_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.442, 0.365)),
      _SpotDifferenceMark(target: Offset(0.243, 0.771)),
      _SpotDifferenceMark(target: Offset(0.854, 0.887)),
      _SpotDifferenceMark(target: Offset(0.817, 0.557)),
      _SpotDifferenceMark(target: Offset(0.606, 0.719)),
    ],
  ),
  _SpotLevel(
    title: '蔬菜小园',
    leftAsset: 'assets/leisure/spot/ai/level_20_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_20_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.641, 0.859)),
      _SpotDifferenceMark(target: Offset(0.518, 0.705)),
      _SpotDifferenceMark(target: Offset(0.337, 0.467)),
      _SpotDifferenceMark(target: Offset(0.145, 0.727)),
      _SpotDifferenceMark(target: Offset(0.413, 0.311)),
    ],
  ),
  _SpotLevel(
    title: '魔法教室',
    leftAsset: 'assets/leisure/spot/ai/level_21_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_21_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.844, 0.898)),
      _SpotDifferenceMark(target: Offset(0.854, 0.637)),
      _SpotDifferenceMark(target: Offset(0.899, 0.295)),
      _SpotDifferenceMark(target: Offset(0.186, 0.395)),
      _SpotDifferenceMark(target: Offset(0.567, 0.668)),
    ],
  ),
  _SpotLevel(
    title: '森林茶会',
    leftAsset: 'assets/leisure/spot/ai/level_22_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_22_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.503, 0.682)),
      _SpotDifferenceMark(target: Offset(0.497, 0.129)),
      _SpotDifferenceMark(target: Offset(0.647, 0.566)),
      _SpotDifferenceMark(target: Offset(0.087, 0.838)),
      _SpotDifferenceMark(target: Offset(0.212, 0.988)),
    ],
  ),
  _SpotLevel(
    title: '海边沙堡',
    leftAsset: 'assets/leisure/spot/ai/level_23_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_23_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.805, 0.604)),
      _SpotDifferenceMark(target: Offset(0.534, 0.160)),
      _SpotDifferenceMark(target: Offset(0.126, 0.248)),
      _SpotDifferenceMark(target: Offset(0.155, 0.705)),
      _SpotDifferenceMark(target: Offset(0.407, 0.846)),
    ],
  ),
  _SpotLevel(
    title: '果香小铺',
    leftAsset: 'assets/leisure/spot/ai/level_24_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_24_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.835, 0.299)),
      _SpotDifferenceMark(target: Offset(0.565, 0.092)),
      _SpotDifferenceMark(target: Offset(0.569, 0.809)),
      _SpotDifferenceMark(target: Offset(0.432, 0.670)),
      _SpotDifferenceMark(target: Offset(0.842, 0.629)),
    ],
  ),
  _SpotLevel(
    title: '玩具工坊',
    leftAsset: 'assets/leisure/spot/ai/level_25_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_25_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.454, .867)),
      _SpotDifferenceMark(target: Offset(.479, .465)),
      _SpotDifferenceMark(target: Offset(.649, .151)),
      _SpotDifferenceMark(target: Offset(.481, .549)),
      _SpotDifferenceMark(target: Offset(.770, .301)),
    ],
  ),
  _SpotLevel(
    title: '雪镇广场',
    leftAsset: 'assets/leisure/spot/ai/level_26_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_26_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.245, .807)),
      _SpotDifferenceMark(target: Offset(.282, .369)),
      _SpotDifferenceMark(target: Offset(.907, .615)),
      _SpotDifferenceMark(target: Offset(.534, .477)),
      _SpotDifferenceMark(target: Offset(.628, .330)),
    ],
  ),
  _SpotLevel(
    title: '花房园丁',
    leftAsset: 'assets/leisure/spot/ai/level_27_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_27_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.897, .371)),
      _SpotDifferenceMark(target: Offset(.753, .773)),
      _SpotDifferenceMark(target: Offset(.495, .842)),
      _SpotDifferenceMark(target: Offset(.735, .256)),
      _SpotDifferenceMark(target: Offset(.784, .133)),
    ],
  ),
  _SpotLevel(
    title: '甜点厨房',
    leftAsset: 'assets/leisure/spot/ai/level_28_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_28_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.684, 0.873)),
      _SpotDifferenceMark(target: Offset(0.821, 0.551)),
      _SpotDifferenceMark(target: Offset(0.491, 0.188)),
      _SpotDifferenceMark(target: Offset(0.077, 0.563)),
      _SpotDifferenceMark(target: Offset(0.366, 0.937)),
    ],
  ),
  _SpotLevel(
    title: '星夜卧室',
    leftAsset: 'assets/leisure/spot/ai/level_29_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_29_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.563, .166)),
      _SpotDifferenceMark(target: Offset(.114, .834)),
      _SpotDifferenceMark(target: Offset(.302, .840)),
      _SpotDifferenceMark(target: Offset(.786, .338)),
      _SpotDifferenceMark(target: Offset(.190, .520)),
    ],
  ),
  _SpotLevel(
    title: '森林书屋',
    leftAsset: 'assets/leisure/spot/ai/level_30_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_30_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.270, .590)),
      _SpotDifferenceMark(target: Offset(.477, .889)),
      _SpotDifferenceMark(target: Offset(.169, .408)),
      _SpotDifferenceMark(target: Offset(.565, .160)),
      _SpotDifferenceMark(target: Offset(.190, .748)),
    ],
  ),
  _SpotLevel(
    title: '海底宝藏',
    leftAsset: 'assets/leisure/spot/ai/level_31_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_31_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.206, .291)),
      _SpotDifferenceMark(target: Offset(.602, .557)),
      _SpotDifferenceMark(target: Offset(.493, .768)),
      _SpotDifferenceMark(target: Offset(.184, .736)),
      _SpotDifferenceMark(target: Offset(.104, .576)),
    ],
  ),
  _SpotLevel(
    title: '湖边露营',
    leftAsset: 'assets/leisure/spot/ai/level_32_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_32_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.592, .709)),
      _SpotDifferenceMark(target: Offset(.823, .611)),
      _SpotDifferenceMark(target: Offset(.733, .933)),
      _SpotDifferenceMark(target: Offset(.124, .916)),
      _SpotDifferenceMark(target: Offset(.268, .850)),
    ],
  ),
  _SpotLevel(
    title: '花市小巷',
    leftAsset: 'assets/leisure/spot/ai/level_33_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_33_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.622, .865)),
      _SpotDifferenceMark(target: Offset(.514, .385)),
      _SpotDifferenceMark(target: Offset(.544, .129)),
      _SpotDifferenceMark(target: Offset(.922, .404)),
      _SpotDifferenceMark(target: Offset(.784, .830)),
    ],
  ),
  _SpotLevel(
    title: '雨夜书店',
    leftAsset: 'assets/leisure/spot/ai/level_34_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_34_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.850, .607)),
      _SpotDifferenceMark(target: Offset(.702, .371)),
      _SpotDifferenceMark(target: Offset(.237, .496)),
      _SpotDifferenceMark(target: Offset(.665, .682)),
      _SpotDifferenceMark(target: Offset(.083, .910)),
    ],
  ),
  _SpotLevel(
    title: '秋日野餐',
    leftAsset: 'assets/leisure/spot/ai/level_35_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_35_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.657, .188)),
      _SpotDifferenceMark(target: Offset(.089, .857)),
      _SpotDifferenceMark(target: Offset(.698, .633)),
      _SpotDifferenceMark(target: Offset(.462, .699)),
      _SpotDifferenceMark(target: Offset(.237, .676)),
    ],
  ),
  _SpotLevel(
    title: '魔法烘焙屋',
    leftAsset: 'assets/leisure/spot/ai/level_36_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_36_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.510, .859)),
      _SpotDifferenceMark(target: Offset(.732, .733)),
      _SpotDifferenceMark(target: Offset(.366, .781)),
      _SpotDifferenceMark(target: Offset(.312, .103)),
      _SpotDifferenceMark(target: Offset(.817, .307)),
    ],
  ),
  _SpotLevel(
    title: '玻璃花房',
    leftAsset: 'assets/leisure/spot/ai/level_37_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_37_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.274, 0.787)),
      _SpotDifferenceMark(target: Offset(0.450, 0.713)),
      _SpotDifferenceMark(target: Offset(0.501, 0.937)),
      _SpotDifferenceMark(target: Offset(0.778, 0.928)),
      _SpotDifferenceMark(target: Offset(0.538, 0.227)),
    ],
  ),
  _SpotLevel(
    title: '玩具阅读角',
    leftAsset: 'assets/leisure/spot/ai/level_38_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_38_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.243, 0.777)),
      _SpotDifferenceMark(target: Offset(0.852, 0.859)),
      _SpotDifferenceMark(target: Offset(0.774, 0.705)),
      _SpotDifferenceMark(target: Offset(0.844, 0.324)),
      _SpotDifferenceMark(target: Offset(0.561, 0.707)),
    ],
  ),
  _SpotLevel(
    title: '清澈潮池',
    leftAsset: 'assets/leisure/spot/ai/level_39_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_39_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.807, 0.707)),
      _SpotDifferenceMark(target: Offset(0.581, 0.580)),
      _SpotDifferenceMark(target: Offset(0.179, 0.518)),
      _SpotDifferenceMark(target: Offset(0.495, 0.221)),
      _SpotDifferenceMark(target: Offset(0.510, 0.752)),
    ],
  ),
  _SpotLevel(
    title: '森林故事角',
    leftAsset: 'assets/leisure/spot/ai/level_40_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_40_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.861, .620)),
      _SpotDifferenceMark(target: Offset(.104, .391)),
      _SpotDifferenceMark(target: Offset(.763, .875)),
      _SpotDifferenceMark(target: Offset(.648, .729)),
      _SpotDifferenceMark(target: Offset(.284, .255)),
    ],
  ),
  _SpotLevel(
    title: '星光书桌',
    leftAsset: 'assets/leisure/spot/ai/level_41_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_41_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.143, 0.879)),
      _SpotDifferenceMark(target: Offset(0.528, 0.381)),
      _SpotDifferenceMark(target: Offset(0.920, 0.432)),
      _SpotDifferenceMark(target: Offset(0.721, 0.121)),
      _SpotDifferenceMark(target: Offset(0.378, 0.377)),
    ],
  ),
  _SpotLevel(
    title: '夜窗甜品屋',
    leftAsset: 'assets/leisure/spot/ai/level_42_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_42_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.730, .735)),
      _SpotDifferenceMark(target: Offset(.489, .855)),
      _SpotDifferenceMark(target: Offset(.362, .781)),
      _SpotDifferenceMark(target: Offset(.820, .308)),
      _SpotDifferenceMark(target: Offset(.489, .099)),
    ],
  ),
  _SpotLevel(
    title: '蘑菇花园',
    leftAsset: 'assets/leisure/spot/ai/level_43_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_43_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(0.671, 0.274)),
      _SpotDifferenceMark(target: Offset(0.883, 0.147)),
      _SpotDifferenceMark(target: Offset(0.341, 0.252)),
      _SpotDifferenceMark(target: Offset(0.434, 0.967)),
      _SpotDifferenceMark(target: Offset(0.216, 0.814)),
    ],
  ),
  _SpotLevel(
    title: '烛光甜点柜',
    leftAsset: 'assets/leisure/spot/ai/level_44_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_44_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.499, .874)),
      _SpotDifferenceMark(target: Offset(.318, .120)),
      _SpotDifferenceMark(target: Offset(.420, .501)),
      _SpotDifferenceMark(target: Offset(.209, .475)),
      _SpotDifferenceMark(target: Offset(.385, .394)),
    ],
  ),
  _SpotLevel(
    title: '阳光花房',
    leftAsset: 'assets/leisure/spot/ai/level_45_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_45_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.793, .559)),
      _SpotDifferenceMark(target: Offset(.875, .661)),
      _SpotDifferenceMark(target: Offset(.290, .088)),
      _SpotDifferenceMark(target: Offset(.383, .192)),
      _SpotDifferenceMark(target: Offset(.616, .616)),
    ],
  ),
];

const _defaultMemoryAssets = [
  'assets/pets/fifi.png',
  'assets/pets/fifi_result_happy.png',
  'assets/pets/magic_star.png',
  'assets/pets/magic_moon.png',
  'assets/pets/magic_flower.png',
  'assets/pets/dino.png',
  'assets/bosses/boss_chinese_01.png',
  'assets/bosses/boss_e2_3.png',
];
