import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final practiceScreen = File('lib/screens/worksheet_practice_screen.dart');
  final morningCalc = File('assets/worksheets/generated/morning_calc_7.json');

  test('compact compare answers use the parent save callback', () {
    final source = practiceScreen.readAsStringSync();

    expect(source, isNot(contains('progress.answers[questionId] = value;')));
    expect(source, contains('await onSetAnswer(question.id, result);'));
  });

  test('vertical calculation digit slots preserve leading empty places', () {
    final source = practiceScreen.readAsStringSync();

    expect(source, contains('current.padLeft(answerWidth, \' \')'));
    expect(source, contains('trim: false'));
    expect(source, contains('final answerSlots = answer.padLeft(width);'));
    expect(source, contains('int.tryParse(digit) == null'));
  });

  test('math keypad puts expression symbols before digits', () {
    final source = practiceScreen.readAsStringSync();

    expect(source, contains("for (final symbol in const ['+', '-'])"));
    expect(source, contains('onTap: () => onDigit(symbol)'));
    expect(
      source.indexOf("const ['+', '-']"),
      lessThan(source.indexOf("const ['1', '2', '3', '4', '5']")),
    );
  });

  test('math keypad aligns operators and keeps next button compact', () {
    final source = practiceScreen.readAsStringSync();

    expect(source, contains("bottom: symbol == '-' ? 0 : 10"));
    expect(source, contains('width: compact ? 118 : 146'));
    expect(source, isNot(contains('width: compact ? 138 : 170')));
  });

  test('math expression blanks use inputTypes to accept operators', () {
    final modelSource = File(
      'lib/models/worksheet_models.dart',
    ).readAsStringSync();
    final screenSource = practiceScreen.readAsStringSync();
    final serviceSource = File(
      'lib/services/worksheet_service.dart',
    ).readAsStringSync();

    expect(modelSource, contains('final List<String> inputTypes;'));
    expect(modelSource, contains("return 'number';"));
    expect(screenSource, contains('_isAllowedBlankInput'));
    expect(screenSource, contains("case 'operator':"));
    expect(screenSource, contains("return value == '+' || value == '-';"));
    expect(screenSource, contains("_setAnswer(key, digit)"));
    expect(serviceSource, contains("'operator'"));
    expect(serviceSource, contains('inputTypes.length > blankCount'));
  });

  test('math expression operator blanks render with a distinct box style', () {
    final screenSource = practiceScreen.readAsStringSync();

    expect(screenSource, contains('this.inputType = \'number\''));
    expect(
      screenSource,
      contains("final isOperator = inputType == 'operator';"),
    );
    expect(
      screenSource,
      contains("inputType: question.blankInputType(currentBlank)"),
    );
    expect(screenSource, contains('Color(0xFFFFF3D5)'));
    expect(screenSource, contains('Color(0xFFE6A13A)'));
  });

  test('worksheet images keep full width with reduced height', () {
    final screenSource = practiceScreen.readAsStringSync();

    expect(
      screenSource,
      contains('static const double _questionImageHeight = 112'),
    );
    expect(screenSource, contains('width: double.infinity'));
    expect(screenSource, contains('height: _questionImageHeight'));
  });

  test('math compact questions keep three columns by adapting card width', () {
    final screenSource = practiceScreen.readAsStringSync();

    expect(screenSource, contains('final targetColumns'));
    expect(screenSource, contains('adaptiveItemWidth'));
    expect(screenSource, contains('currentRow.length < targetColumns'));
    expect(screenSource, isNot(contains('math.max(width, 270.0)')));
    expect(screenSource, isNot(contains('? row[c].estimatedWidth : 270')));
  });

  test(
    'math worksheet page gives more width to questions on narrow tablets',
    () {
      final screenSource = practiceScreen.readAsStringSync();

      expect(screenSource, contains('final compactMathTablet'));
      expect(screenSource, contains('final sidePanelWidth'));
      expect(screenSource, contains('compactMathTablet ? 224.0 : 300.0'));
      expect(screenSource, contains('final horizontalPadding'));
      expect(screenSource, contains('final panelGap'));
    },
  );

  test('morning vertical calculations use build mode with process cells', () {
    final screenSource = practiceScreen.readAsStringSync();
    final worksheetSource = morningCalc.readAsStringSync();

    expect(worksheetSource, contains('"mode": "build"'));
    expect(screenSource, contains('_isBuildVerticalQuestion(question)'));
    expect(screenSource, contains('_verticalBuildAnswerKey'));
    expect(screenSource, contains('_BuildVerticalCalculation'));
    expect(screenSource, contains('_isVerticalBuildAnswerCorrect'));
    expect(screenSource, contains('_nextVerticalBuildSlotAfterInput'));
    expect(screenSource, isNot(contains('_VerticalOpSelector')));
  });

  test('vertical build focus can flow through the whole question', () {
    final screenSource = practiceScreen.readAsStringSync();

    expect(screenSource, contains('return opSlot;'));
    expect(screenSource, contains('return bottomStart;'));
    expect(screenSource, contains('return resultEnd;'));
    expect(screenSource, contains('return slotIndex - 1;'));
  });

  test('vertical build operator cell uses keypad input without a dialog', () {
    final screenSource = practiceScreen.readAsStringSync();

    expect(screenSource, contains('if (isOpCell)'));
    expect(screenSource, contains('return value == \'+\' || value == \'-\';'));
    expect(
      screenSource,
      isNot(contains('builder: (_) => const _VerticalOpSelector()')),
    );
  });

  test('vertical build question selection defaults to the top left cell', () {
    final screenSource = practiceScreen.readAsStringSync();

    expect(screenSource, contains('int? _defaultBlankIndexForQuestion'));
    expect(
      screenSource,
      contains('return _isBuildVerticalQuestion(question) ? 0 : null;'),
    );
    expect(
      screenSource,
      contains('_selectedBlankIndex = _defaultBlankIndexForQuestion'),
    );
  });
}
