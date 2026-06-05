import 'dart:math';

import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../models/app_models.dart';
import '../services/app_store.dart';
import '../services/audio_service.dart';
import '../services/sudoku_service.dart';
import '../widgets/ui_components.dart';

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key, required this.store, required this.puzzle});

  final AppStore store;
  final SudokuPuzzle puzzle;

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  late SudokuPuzzle puzzle = widget.puzzle;
  late SudokuBoardState board = SudokuBoardState(puzzle);
  late DateTime startedAt = DateTime.now();
  int selectedRow = 0;
  int selectedCol = 0;
  bool cleanRun = true;
  String message = '选择空格填入数字，填满后点击提交检查。';

  @override
  void initState() {
    super.initState();
    if (widget.store.progress.settings['music'] ?? false) {
      AudioService.playBgm(AppMusicScene.sudoku);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExplorerScaffold(
      title: puzzle.title,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final boardSize = min(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return Center(
                    child: SizedBox.square(
                      dimension: boardSize,
                      child: SoftCard(
                        color: const Color(0xFFFFFBEB),
                        padding: const EdgeInsets.all(8),
                        child: _SudokuGrid(
                          board: board,
                          selectedRow: selectedRow,
                          selectedCol: selectedCol,
                          onSelect: (r, c) {
                            setState(() {
                              selectedRow = r;
                              selectedCol = c;
                            });
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SoftCard(
                      color: const Color(0xFFEDE7F6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            puzzle.difficulty,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            message,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '重置次数：${widget.store.progress.sudokuResets[puzzle.id] ?? 0}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount: puzzle.size <= 6 ? puzzle.size : 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: puzzle.size <= 6 ? 1.25 : 2.2,
                      children: List.generate(puzzle.size, (index) {
                        final number = index + 1;
                        return FilledButton(
                          onPressed: () => _place(number),
                          child: Text(
                            '$number',
                            style: const TextStyle(fontSize: 22),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _SudokuToolButton(
                          icon: const Icon(Icons.backspace),
                          label: '橡皮擦',
                          color: const Color(0xFF9A5A2C),
                          onPressed: _erase,
                        ),
                        _SudokuToolButton(
                          icon: const Icon(Icons.check_circle),
                          label: '提交',
                          color: const Color(0xFF2E7D32),
                          onPressed: _submit,
                        ),
                        _SudokuToolButton(
                          icon: const Icon(Icons.restart_alt),
                          label: '重置',
                          color: const Color(0xFF8B5CF6),
                          onPressed: _reset,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SoftCard(
                      color: const Color(0xFFFFF8E1),
                      child: Text(
                        '限时一次通过奖励：4×4在1分钟内得能量果，6×6在3分钟内得星星，9×9在10分钟内得勋章。\n本案线索：${puzzle.caseClue}',
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _place(int number) async {
    if (board.isGiven(selectedRow, selectedCol)) {
      AudioService.playSfx(
        AppSound.wrong,
        enabled: widget.store.progress.settings['sfx'] ?? true,
      );
      setState(() => message = '这是案件线索，不能修改。');
      return;
    }
    setState(() {
      board.place(selectedRow, selectedCol, number);
      message = board.isComplete ? '全部填满了，点击提交公布结果。' : '已填入数字，继续观察全盘。';
    });
    await AudioService.playSfx(
      AppSound.tap,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
  }

  void _erase() {
    AudioService.playSfx(
      AppSound.erase,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
    setState(() {
      board.erase(selectedRow, selectedCol);
      message = '已经擦掉这个格子的尝试。';
    });
  }

  Future<void> _reset() async {
    await widget.store.recordSudokuReset(puzzle.id);
    await AudioService.playSfx(
      AppSound.erase,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
    setState(() {
      cleanRun = false;
      board = SudokuBoardState(puzzle);
      message = '棋盘已重置，再侦查一次。';
    });
  }

  Future<void> _submit() async {
    if (!board.isComplete) {
      await AudioService.playSfx(
        AppSound.hint,
        enabled: widget.store.progress.settings['sfx'] ?? true,
      );
      if (!mounted) return;
      setState(() => message = '还有格子没填完，全部填写后再提交。');
      return;
    }
    await _checkBoard();
  }

  Future<void> _checkBoard() async {
    if (!board.isSolved) {
      await AudioService.playSfx(
        AppSound.wrong,
        enabled: widget.store.progress.settings['sfx'] ?? true,
      );
      if (!mounted) return;
      setState(() {
        cleanRun = false;
        message = '还有行或列出现重复数字，擦掉可疑格子再试试。';
      });
      return;
    }

    final seconds = DateTime.now().difference(startedAt).inSeconds;
    final reward = await widget.store.completeSudoku(
      puzzle,
      seconds: seconds,
      cleanRun: cleanRun,
    );
    await AudioService.playOneShot(
      AppSound.sudokuVictory,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('案件侦破！'),
        content: Text('${puzzle.caseClue}\n$reward'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('继续下一盘'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      puzzle = buildRandomSudoku(puzzle.size);
      board = SudokuBoardState(puzzle);
      startedAt = DateTime.now();
      cleanRun = true;
      selectedRow = 0;
      selectedCol = 0;
      message = '新案件已生成，填满后点击提交检查。';
    });
  }
}

class _SudokuToolButton extends StatelessWidget {
  const _SudokuToolButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 48,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: const Color(0x552D2A32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF2D2A32), width: 1.3),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        icon: icon,
        label: Text(label, overflow: TextOverflow.ellipsis),
        onPressed: onPressed,
      ),
    );
  }
}

class _SudokuGrid extends StatelessWidget {
  const _SudokuGrid({
    required this.board,
    required this.selectedRow,
    required this.selectedCol,
    required this.onSelect,
  });

  final SudokuBoardState board;
  final int selectedRow;
  final int selectedCol;
  final void Function(int row, int col) onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: board.puzzle.size,
      ),
      itemCount: board.puzzle.size * board.puzzle.size,
      itemBuilder: (context, index) {
        final row = index ~/ board.puzzle.size;
        final col = index % board.puzzle.size;
        final selected = row == selectedRow && col == selectedCol;
        final value = board.values[row][col];
        final given = board.isGiven(row, col);
        final boxTint =
            ((row ~/ board.puzzle.boxRows) + (col ~/ board.puzzle.boxCols))
                .isEven;
        return GestureDetector(
          onTap: () => onSelect(row, col),
          onLongPress: () => onSelect(row, col),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFB3E5FC)
                  : boxTint
                  ? const Color(0xFFE3F2FD)
                  : const Color(0xFFFFF9C4),
              border: Border.all(
                color: given ? const Color(0xFF2D2A32) : Colors.grey.shade600,
                width: given ? 2.4 : 1.2,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: value == 0
                  ? const SizedBox.shrink()
                  : Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: given
                            ? const Color(0xFF2D2A32)
                            : const Color(0xFF1976D2),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
