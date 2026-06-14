import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/ui_components.dart';

class LeisurePlaygroundScreen extends StatefulWidget {
  const LeisurePlaygroundScreen({super.key});

  @override
  State<LeisurePlaygroundScreen> createState() =>
      _LeisurePlaygroundScreenState();
}

class _LeisurePlaygroundScreenState extends State<LeisurePlaygroundScreen> {
  _LeisureGame selected = _games.first;

  @override
  Widget build(BuildContext context) {
    return ExplorerScaffold(
      title: '休闲乐园',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 290,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '选一个小游戏',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '观察、记忆和下棋，轻松玩一局。',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _games.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final game = _games[index];
                        return _GameMenuCard(
                          game: game,
                          active: game.id == selected.id,
                          onTap: () => setState(() => selected = game),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: KeyedSubtree(
                  key: ValueKey(selected.id),
                  child: switch (selected.id) {
                    'spot' => const _SpotDifferenceGame(),
                    'memory' => const _MemoryFlipGame(),
                    'gomoku' => const _GomokuGame(),
                    _ => const _SpotDifferenceGame(),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotDifferenceGame extends StatefulWidget {
  const _SpotDifferenceGame();

  @override
  State<_SpotDifferenceGame> createState() => _SpotDifferenceGameState();
}

class _SpotDifferenceGameState extends State<_SpotDifferenceGame> {
  int levelIndex = 0;
  final Set<int> found = {};

  _SpotLevel get level => _spotLevels[levelIndex];

  void _nextLevel() {
    setState(() {
      levelIndex = (levelIndex + 1) % _spotLevels.length;
      found.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final done = found.length == level.differences.length;
    return _GameShell(
      title: '找不同',
      subtitle: '${level.title}：点右图里不一样的位置。',
      color: const Color(0xFFFFF8E1),
      actionLabel: done ? '下一关' : '换一关',
      onAction: _nextLevel,
      child: Column(
        children: [
          _GameStatusBar(
            leading: '第 ${levelIndex + 1}/${_spotLevels.length} 关',
            trailing: '已找到 ${found.length}/${level.differences.length}',
            color: done ? const Color(0xFFA7F3D0) : const Color(0xFFFFE08A),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _SpotImageCard(title: '左图', asset: level.leftAsset),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _SpotImageCard(
                    title: '右图',
                    asset: level.rightAsset,
                    differences: level.differences,
                    found: found,
                    onFound: (index) => setState(() => found.add(index)),
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

class _SpotImageCard extends StatelessWidget {
  const _SpotImageCard({
    required this.title,
    required this.asset,
    this.differences = const [],
    this.found = const {},
    this.onFound,
  });

  final String title;
  final String asset;
  final List<_SpotDifferenceMark> differences;
  final Set<int> found;
  final ValueChanged<int>? onFound;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        asset,
                        fit: BoxFit.cover,
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
                      for (var i = 0; i < differences.length; i++)
                        _SpotHotspot(
                          target: differences[i].target,
                          size: size,
                          found: found.contains(i),
                          onTap: () => onFound?.call(i),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotHotspot extends StatelessWidget {
  const _SpotHotspot({
    required this.target,
    required this.size,
    required this.found,
    required this.onTap,
  });

  final Offset target;
  final Size size;
  final bool found;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const tapSize = 82.0;
    return Positioned(
      left: target.dx * size.width - tapSize / 2,
      top: target.dy * size.height - tapSize / 2,
      width: tapSize,
      height: tapSize,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: found ? const Color(0x55A7F3D0) : Colors.transparent,
            border: found
                ? Border.all(color: const Color(0xFF16A34A), width: 3)
                : null,
          ),
          child: found
              ? const Icon(Icons.check, color: Color(0xFF15803D), size: 32)
              : null,
        ),
      ),
    );
  }
}

class _MemoryFlipGame extends StatefulWidget {
  const _MemoryFlipGame();

  @override
  State<_MemoryFlipGame> createState() => _MemoryFlipGameState();
}

class _MemoryFlipGameState extends State<_MemoryFlipGame> {
  static const int pairCount = 8;

  late List<_MemoryCardData> cards;
  List<String> assetPool = _defaultMemoryAssets;
  final List<int> opened = [];
  int moves = 0;
  bool waiting = false;

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
    if (waiting || cards[index].matched || opened.contains(index)) return;
    setState(() => opened.add(index));
    if (opened.length < 2) return;
    setState(() => moves++);
    final first = opened[0];
    final second = opened[1];
    if (cards[first].pairId == cards[second].pairId) {
      setState(() {
        cards[first] = cards[first].copyWith(matched: true);
        cards[second] = cards[second].copyWith(matched: true);
        opened.clear();
      });
      return;
    }
    waiting = true;
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      opened.clear();
      waiting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final matched = cards.where((card) => card.matched).length ~/ 2;
    final totalPairs = cards.length ~/ 2;
    return _GameShell(
      title: '记忆翻牌',
      subtitle: '翻开两张一样的卡通图片，配成一对就留下来。',
      color: const Color(0xFFE3F2FD),
      actionLabel: '洗牌',
      onAction: () => setState(_reset),
      child: Column(
        children: [
          _GameStatusBar(
            leading: '配对 $matched/$totalPairs',
            trailing: '步数 $moves · ${assetPool.length} 张素材',
            color: matched == totalPairs
                ? const Color(0xFFA7F3D0)
                : const Color(0xFFFFE08A),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const columns = 4;
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
                      onTap: () => _tapCard(index),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({
    required this.card,
    required this.visible,
    required this.onTap,
  });

  final _MemoryCardData card;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: card.matched
          ? const Color(0xFFA7F3D0)
          : visible
          ? const Color(0xFFFFF8E1)
          : const Color(0xFFFFC6D9),
      padding: const EdgeInsets.all(8),
      onTap: onTap,
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
  const _GomokuGame();

  @override
  State<_GomokuGame> createState() => _GomokuGameState();
}

class _GomokuGameState extends State<_GomokuGame> {
  static const int size = 13;
  late List<int> board;
  int turn = 1;
  int winner = 0;
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
    message = '你先下黑棋，连成五颗就胜利。';
  }

  void _tapCell(int index) {
    if (winner != 0 || board[index] != 0 || turn != 1) return;
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
    if (winner == 0) {
      Future<void>.delayed(const Duration(milliseconds: 260), _aiMove);
    }
  }

  void _aiMove() {
    if (!mounted || winner != 0 || turn != 2) return;
    final move = _bestAiMove();
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
  }

  int _bestAiMove() {
    final empty = [
      for (var i = 0; i < board.length; i++)
        if (board[i] == 0) i,
    ];

    for (final index in empty) {
      if (_wouldWin(index, 2)) return index;
    }
    for (final index in empty) {
      if (_wouldWin(index, 1)) return index;
    }

    empty.sort((a, b) => _moveScore(b).compareTo(_moveScore(a)));
    return empty.first;
  }

  bool _wouldWin(int index, int player) {
    board[index] = player;
    final win = _winnerAt(index, player);
    board[index] = 0;
    return win;
  }

  int _moveScore(int index) {
    final row = index ~/ size;
    final col = index % size;
    final center = size ~/ 2;
    final centerScore = 30 - ((row - center).abs() + (col - center).abs());
    final attack = _scoreAs(index, 2);
    final defense = _scoreAs(index, 1);
    return attack * 2 + (defense * 1.65).round() + centerScore;
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
    return SoftCard(
      color: const Color(0xFFFFE4B5),
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: _GomokuBoard(
                board: board,
                size: size,
                winner: winner,
                onTapIndex: _tapCell,
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Tooltip(
              message: '新一局',
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF9A5A2D),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => setState(_reset),
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          if (winner != 0)
            Positioned(
              left: 18,
              right: 18,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xEFFFFFF8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF2D2A32),
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
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
  });

  final String title;
  final String subtitle;
  final Color color;
  final Widget child;
  final String actionLabel;
  final VoidCallback onAction;

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
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel),
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

class _GameStatusBar extends StatelessWidget {
  const _GameStatusBar({
    required this.leading,
    required this.trailing,
    required this.color,
  });

  final String leading;
  final String trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2D2A32), width: 1.2),
      ),
      child: Row(
        children: [
          Text(
            leading,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          Text(
            trailing,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
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
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: Colors.white,
            child: Icon(game.icon, color: game.accent, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  game.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          Icon(active ? Icons.play_circle_fill : Icons.chevron_right),
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
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color accent;
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
  ),
  _LeisureGame(
    id: 'memory',
    title: '记忆翻牌',
    subtitle: '彩色卡通图片配对，练记忆力。',
    icon: Icons.style,
    color: Color(0xFFE3F2FD),
    accent: Color(0xFF2563EB),
  ),
  _LeisureGame(
    id: 'gomoku',
    title: '五子棋',
    subtitle: '更聪明的果果，会进攻也会防守。',
    icon: Icons.grid_on,
    color: Color(0xFFFFE4B5),
    accent: Color(0xFFFF8C42),
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
      _SpotDifferenceMark(target: Offset(.08, .67)),
      _SpotDifferenceMark(target: Offset(.33, .70)),
      _SpotDifferenceMark(target: Offset(.79, .48)),
      _SpotDifferenceMark(target: Offset(.88, .77)),
      _SpotDifferenceMark(target: Offset(.41, .52)),
    ],
  ),
  _SpotLevel(
    title: '野餐草地',
    leftAsset: 'assets/leisure/spot/ai/level_3_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_3_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.17, .54)),
      _SpotDifferenceMark(target: Offset(.39, .72)),
      _SpotDifferenceMark(target: Offset(.78, .50)),
      _SpotDifferenceMark(target: Offset(.84, .38)),
      _SpotDifferenceMark(target: Offset(.84, .86)),
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
      _SpotDifferenceMark(target: Offset(.35, .42)),
      _SpotDifferenceMark(target: Offset(.72, .77)),
      _SpotDifferenceMark(target: Offset(.58, .72)),
      _SpotDifferenceMark(target: Offset(.50, .34)),
      _SpotDifferenceMark(target: Offset(.25, .76)),
    ],
  ),
  _SpotLevel(
    title: '课堂书桌',
    leftAsset: 'assets/leisure/spot/ai/level_6_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_6_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.30, .67)),
      _SpotDifferenceMark(target: Offset(.55, .45)),
      _SpotDifferenceMark(target: Offset(.45, .72)),
      _SpotDifferenceMark(target: Offset(.70, .40)),
      _SpotDifferenceMark(target: Offset(.20, .55)),
    ],
  ),
  _SpotLevel(
    title: '农场小院',
    leftAsset: 'assets/leisure/spot/ai/level_7_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_7_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.50, .42)),
      _SpotDifferenceMark(target: Offset(.72, .62)),
      _SpotDifferenceMark(target: Offset(.35, .72)),
      _SpotDifferenceMark(target: Offset(.62, .78)),
      _SpotDifferenceMark(target: Offset(.82, .52)),
    ],
  ),
  _SpotLevel(
    title: '森林小路',
    leftAsset: 'assets/leisure/spot/ai/level_8_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_8_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.25, .36)),
      _SpotDifferenceMark(target: Offset(.40, .68)),
      _SpotDifferenceMark(target: Offset(.60, .50)),
      _SpotDifferenceMark(target: Offset(.70, .30)),
      _SpotDifferenceMark(target: Offset(.18, .78)),
    ],
  ),
  _SpotLevel(
    title: '烘焙厨房',
    leftAsset: 'assets/leisure/spot/ai/level_9_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_9_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.58, .48)),
      _SpotDifferenceMark(target: Offset(.35, .42)),
      _SpotDifferenceMark(target: Offset(.65, .70)),
      _SpotDifferenceMark(target: Offset(.46, .76)),
      _SpotDifferenceMark(target: Offset(.80, .55)),
    ],
  ),
  _SpotLevel(
    title: '海底水族箱',
    leftAsset: 'assets/leisure/spot/ai/level_10_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_10_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.30, .35)),
      _SpotDifferenceMark(target: Offset(.58, .62)),
      _SpotDifferenceMark(target: Offset(.76, .30)),
      _SpotDifferenceMark(target: Offset(.46, .48)),
      _SpotDifferenceMark(target: Offset(.68, .76)),
    ],
  ),
  _SpotLevel(
    title: '花园茶会',
    leftAsset: 'assets/leisure/spot/ai/level_11_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_11_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.36, .55)),
      _SpotDifferenceMark(target: Offset(.54, .62)),
      _SpotDifferenceMark(target: Offset(.64, .38)),
      _SpotDifferenceMark(target: Offset(.74, .70)),
      _SpotDifferenceMark(target: Offset(.82, .25)),
    ],
  ),
  _SpotLevel(
    title: '恐龙玩具岛',
    leftAsset: 'assets/leisure/spot/ai/level_12_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_12_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.45, .74)),
      _SpotDifferenceMark(target: Offset(.72, .30)),
      _SpotDifferenceMark(target: Offset(.60, .48)),
      _SpotDifferenceMark(target: Offset(.38, .42)),
      _SpotDifferenceMark(target: Offset(.28, .68)),
    ],
  ),
  _SpotLevel(
    title: '睡前小屋',
    leftAsset: 'assets/leisure/spot/ai/level_13_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_13_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.62, .58)),
      _SpotDifferenceMark(target: Offset(.78, .46)),
      _SpotDifferenceMark(target: Offset(.34, .72)),
      _SpotDifferenceMark(target: Offset(.44, .38)),
      _SpotDifferenceMark(target: Offset(.70, .24)),
    ],
  ),
  _SpotLevel(
    title: '糖果小店',
    leftAsset: 'assets/leisure/spot/ai/level_14_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_14_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.36, .42)),
      _SpotDifferenceMark(target: Offset(.55, .30)),
      _SpotDifferenceMark(target: Offset(.65, .60)),
      _SpotDifferenceMark(target: Offset(.78, .72)),
      _SpotDifferenceMark(target: Offset(.25, .66)),
    ],
  ),
  _SpotLevel(
    title: '雨天窗边',
    leftAsset: 'assets/leisure/spot/ai/level_15_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_15_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.40, .46)),
      _SpotDifferenceMark(target: Offset(.55, .75)),
      _SpotDifferenceMark(target: Offset(.70, .66)),
      _SpotDifferenceMark(target: Offset(.30, .30)),
      _SpotDifferenceMark(target: Offset(.75, .38)),
    ],
  ),
  _SpotLevel(
    title: '雪地院子',
    leftAsset: 'assets/leisure/spot/ai/level_16_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_16_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.50, .45)),
      _SpotDifferenceMark(target: Offset(.35, .68)),
      _SpotDifferenceMark(target: Offset(.70, .72)),
      _SpotDifferenceMark(target: Offset(.62, .32)),
      _SpotDifferenceMark(target: Offset(.28, .56)),
    ],
  ),
  _SpotLevel(
    title: '音乐角落',
    leftAsset: 'assets/leisure/spot/ai/level_17_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_17_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.34, .48)),
      _SpotDifferenceMark(target: Offset(.50, .65)),
      _SpotDifferenceMark(target: Offset(.62, .42)),
      _SpotDifferenceMark(target: Offset(.74, .55)),
      _SpotDifferenceMark(target: Offset(.42, .80)),
    ],
  ),
  _SpotLevel(
    title: '太空书桌',
    leftAsset: 'assets/leisure/spot/ai/level_18_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_18_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.42, .48)),
      _SpotDifferenceMark(target: Offset(.66, .28)),
      _SpotDifferenceMark(target: Offset(.55, .62)),
      _SpotDifferenceMark(target: Offset(.72, .72)),
      _SpotDifferenceMark(target: Offset(.30, .66)),
    ],
  ),
  _SpotLevel(
    title: '绘画桌面',
    leftAsset: 'assets/leisure/spot/ai/level_19_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_19_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.38, .52)),
      _SpotDifferenceMark(target: Offset(.52, .42)),
      _SpotDifferenceMark(target: Offset(.65, .68)),
      _SpotDifferenceMark(target: Offset(.75, .56)),
      _SpotDifferenceMark(target: Offset(.45, .78)),
    ],
  ),
  _SpotLevel(
    title: '蔬菜小园',
    leftAsset: 'assets/leisure/spot/ai/level_20_left.jpg',
    rightAsset: 'assets/leisure/spot/ai/level_20_right.jpg',
    differences: [
      _SpotDifferenceMark(target: Offset(.42, .42)),
      _SpotDifferenceMark(target: Offset(.60, .56)),
      _SpotDifferenceMark(target: Offset(.34, .70)),
      _SpotDifferenceMark(target: Offset(.72, .68)),
      _SpotDifferenceMark(target: Offset(.55, .30)),
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
