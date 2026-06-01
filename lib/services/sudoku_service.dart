import '../models/app_models.dart';

class SudokuBoardState {
  SudokuBoardState(SudokuPuzzle puzzle)
    : puzzle = puzzle,
      values = List.generate(
        puzzle.size,
        (r) => List.generate(puzzle.size, (c) => puzzle.givens[r][c]),
      ),
      notes = List.generate(
        puzzle.size,
        (_) => List.generate(puzzle.size, (_) => <int>{}),
      );

  final SudokuPuzzle puzzle;
  final List<List<int>> values;
  final List<List<Set<int>>> notes;
  int hintsLeft = 3;

  bool isGiven(int row, int col) => puzzle.givens[row][col] != 0;

  bool canPlace(int row, int col, int value) {
    if (isGiven(row, col)) return false;
    return puzzle.solution[row][col] == value;
  }

  bool hasConflict(int row, int col, int value) {
    for (var c = 0; c < puzzle.size; c++) {
      if (c != col && values[row][c] == value) return true;
    }
    for (var r = 0; r < puzzle.size; r++) {
      if (r != row && values[r][col] == value) return true;
    }
    final br = row ~/ puzzle.boxRows * puzzle.boxRows;
    final bc = col ~/ puzzle.boxCols * puzzle.boxCols;
    for (var r = br; r < br + puzzle.boxRows; r++) {
      for (var c = bc; c < bc + puzzle.boxCols; c++) {
        if ((r != row || c != col) && values[r][c] == value) return true;
      }
    }
    return false;
  }

  void place(int row, int col, int value) {
    if (!isGiven(row, col)) {
      values[row][col] = value;
      notes[row][col].clear();
    }
  }

  void erase(int row, int col) {
    if (!isGiven(row, col)) {
      values[row][col] = 0;
      notes[row][col].clear();
    }
  }

  void toggleNote(int row, int col, int value) {
    if (isGiven(row, col) || values[row][col] != 0) return;
    if (!notes[row][col].remove(value)) {
      notes[row][col].add(value);
    }
  }

  ({int row, int col})? useHint() {
    if (hintsLeft <= 0) return null;
    for (var r = 0; r < puzzle.size; r++) {
      for (var c = 0; c < puzzle.size; c++) {
        if (!isGiven(r, c) && values[r][c] == 0) {
          hintsLeft -= 1;
          return (row: r, col: c);
        }
      }
    }
    return null;
  }

  bool get isComplete {
    for (var r = 0; r < puzzle.size; r++) {
      for (var c = 0; c < puzzle.size; c++) {
        if (values[r][c] == 0) return false;
      }
    }
    return true;
  }

  bool get isSolved {
    if (!isComplete) return false;
    final expected = {for (var i = 1; i <= puzzle.size; i++) i};

    for (var r = 0; r < puzzle.size; r++) {
      if (values[r].toSet().length != puzzle.size ||
          !values[r].toSet().containsAll(expected)) {
        return false;
      }
    }

    for (var c = 0; c < puzzle.size; c++) {
      final column = {for (var r = 0; r < puzzle.size; r++) values[r][c]};
      if (column.length != puzzle.size || !column.containsAll(expected)) {
        return false;
      }
    }

    for (var br = 0; br < puzzle.size; br += puzzle.boxRows) {
      for (var bc = 0; bc < puzzle.size; bc += puzzle.boxCols) {
        final box = <int>{};
        for (var r = br; r < br + puzzle.boxRows; r++) {
          for (var c = bc; c < bc + puzzle.boxCols; c++) {
            box.add(values[r][c]);
          }
        }
        if (box.length != puzzle.size || !box.containsAll(expected)) {
          return false;
        }
      }
    }
    return true;
  }
}
