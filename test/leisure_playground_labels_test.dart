import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('leisure playground no longer ships spot difference game', () {
    final leisureSource = File(
      'lib/screens/leisure_playground_screen.dart',
    ).readAsStringSync();
    final settingsSource = File(
      'lib/screens/stats_settings_screen.dart',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(leisureSource, isNot(contains('_SpotDifferenceGame')));
    expect(leisureSource, isNot(contains('_SpotLevel')));
    expect(leisureSource, isNot(contains('spot_difference_card')));
    expect(leisureSource, isNot(contains("id: 'spot'")));
    expect(settingsSource, isNot(contains('spotMarker')));
    expect(pubspec, isNot(contains('assets/leisure/spot')));
    expect(Directory('assets/leisure/spot').existsSync(), isFalse);
    expect(
      File('assets/leisure/cards/spot_difference_card.png').existsSync(),
      isFalse,
    );
  });
}
