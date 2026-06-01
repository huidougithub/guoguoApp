import 'package:flutter/services.dart';

enum AppSound {
  tap('tap'),
  correct('correct'),
  wrong('wrong'),
  hint('hint'),
  erase('erase'),
  reward('reward'),
  brush('brush'),
  page('page'),
  chime('chime'),
  voice('voice'),
  petCute('pet_cute'),
  petCharge('pet_charge'),
  petProjectile('pet_projectile'),
  petAttack('pet_attack'),
  magicImpact('magic_impact'),
  bossCharge('boss_charge'),
  bossAttack('boss_attack'),
  shieldHit('shield_hit'),
  dizzy('dizzy'),
  hit('hit'),
  bossDown('boss_down'),
  bossEscape('boss_escape'),
  steal('steal'),
  feed('feed'),
  victory('victory'),
  petClick('pet_click'),
  sudokuVictory('sudoku_victory');

  const AppSound(this.key);

  final String key;
}

enum AppMusicScene {
  home('menu'),
  math('mach'),
  chinese('yw'),
  english('sd1'),
  sudoku('sd'),
  wrongChallenge('ct'),
  selfChallenge('tz'),
  boss('boss_user'),
  shop('shoping');

  const AppMusicScene(this.key);

  final String key;
}

class AudioService {
  AudioService._();

  static const _channel = MethodChannel('guoguo_forward/audio');
  static AppMusicScene? _currentScene;
  static bool _active = true;

  static Future<void> preload() async {
    try {
      await _channel.invokeMethod<void>('preload');
    } on Object {
      // Tests and non-Android targets can run without native audio.
    }
  }

  static Future<void> playSfx(AppSound sound, {required bool enabled}) async {
    if (!enabled || !_active) return;
    try {
      await _channel.invokeMethod<void>('playSfx', sound.key);
    } on Object {
      // Audio feedback is nice to have; it should never block learning flow.
    }
  }

  static Future<void> play(AppSound sound, {required bool enabled}) =>
      playSfx(sound, enabled: enabled);

  static Future<void> playOneShot(
    AppSound sound, {
    required bool enabled,
  }) async {
    if (!enabled || !_active) return;
    try {
      await _channel.invokeMethod<void>('playOneShot', sound.key);
    } on Object {
      // Long voice clips are optional and should not block the UI.
    }
  }

  static Future<void> playBgm(AppMusicScene scene) async {
    _currentScene = scene;
    if (!_active) return;
    try {
      await _channel.invokeMethod<void>('playBgm', scene.key);
    } on Object {
      // Background music should never block app startup.
    }
  }

  static Future<void> stopBgm() async {
    _currentScene = null;
    await pauseBgm();
  }

  static Future<void> pauseBgm() async {
    try {
      await _channel.invokeMethod<void>('stopBgm');
    } on Object {
      // No-op on tests and non-Android targets.
    }
  }

  static Future<void> suspendForLifecycle() async {
    _active = false;
    await pauseBgm();
  }

  static Future<void> resumeForLifecycle({required bool musicEnabled}) async {
    _active = true;
    final scene = _currentScene;
    if (musicEnabled && scene != null) {
      await playBgm(scene);
    }
  }

  static Future<void> speakEnglish(String text, {required bool enabled}) async {
    if (!enabled || !_active || text.trim().isEmpty) return;
    try {
      await _channel.invokeMethod<void>('speakEnglish', text.trim());
    } on Object {
      // Text-to-speech depends on the Android device engine.
    }
  }
}
