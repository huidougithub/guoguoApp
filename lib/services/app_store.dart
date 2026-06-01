import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_data.dart';
import '../models/app_models.dart';

class AppStore extends ChangeNotifier {
  static const int schemaVersion = 3;
  static const String _schemaKey = 'progress_schema_version';
  static const String _progressKey = 'wisdom_explorer_progress';

  AppProgress progress = AppProgress();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getInt(_schemaKey);
    final raw = prefs.getString(_progressKey);
    if (version == schemaVersion && raw != null) {
      progress = AppProgress.fromJson(
        (jsonDecode(raw) as Map<dynamic, dynamic>).cast<String, dynamic>(),
      );
      _syncCosmetics();
      return;
    }
    progress = AppProgress();
    await _save();
  }

  Future<void> selectGrade(int grade) async {
    progress.selectedGrade = grade;
    await _saveAndNotify();
  }

  Future<void> resetForGrade(int grade) async {
    final selectedPet = progress.selectedPet;
    progress = AppProgress(selectedGrade: grade, selectedPet: selectedPet);
    await _saveAndNotify();
  }

  Future<void> selectPet(String petId) async {
    if (!progress.unlockedPets.contains(petId)) return;
    progress.selectedPet = petId;
    await _saveAndNotify();
  }

  bool isLevelUnlocked(LevelDefinition level) => true;

  bool isSudokuUnlocked(SudokuPuzzle puzzle) => true;

  bool ownsCosmetic(CosmeticDefinition cosmetic) {
    return ownsCosmeticForPet(cosmetic, progress.selectedPet);
  }

  bool ownsCosmeticForPet(CosmeticDefinition cosmetic, String? petId) {
    final key = _cosmeticKey(petId, cosmetic.id);
    return progress.unlockedCosmetics.contains(key);
  }

  bool hasCosmeticEquipped(String cosmeticId) {
    return progress.equippedCosmetics.contains(
      _cosmeticKey(progress.selectedPet, cosmeticId),
    );
  }

  Set<String> equippedCosmeticsForPet(String? petId) {
    final prefix = '${petId ?? progress.selectedPet ?? 'dino'}:';
    return progress.equippedCosmetics
        .where((id) => id.startsWith(prefix))
        .map((id) => id.substring(prefix.length))
        .where((id) => cosmetics.any((cosmetic) => cosmetic.id == id))
        .toSet();
  }

  bool ownsPet(PetDefinition pet) => progress.unlockedPets.contains(pet.id);

  bool canPurchasePet(PetDefinition pet) {
    return !ownsPet(pet) && progress.badges.length >= pet.badgeCost;
  }

  Future<bool> purchasePetWithBadges(PetDefinition pet) async {
    if (pet.starter || !canPurchasePet(pet)) return false;
    final spent = progress.badges.take(pet.badgeCost).toList();
    for (final badge in spent) {
      progress.badges.remove(badge);
    }
    progress.unlockedPets.add(pet.id);
    progress.selectedPet = pet.id;
    await _saveAndNotify();
    return true;
  }

  bool canPurchaseCosmetic(CosmeticDefinition cosmetic) {
    return !ownsCosmetic(cosmetic) &&
        progress.petLevel >= cosmetic.requiredLevel &&
        progress.energyFruit >= cosmetic.fruitCost &&
        progress.totalStars >= cosmetic.starCost;
  }

  Future<bool> purchaseCosmetic(CosmeticDefinition cosmetic) async {
    if (!canPurchaseCosmetic(cosmetic)) return false;
    progress.energyFruit -= cosmetic.fruitCost;
    progress.totalStars -= cosmetic.starCost;
    final key = _cosmeticKey(progress.selectedPet, cosmetic.id);
    progress.unlockedCosmetics.add(key);
    progress.equippedCosmetics.add(key);
    await _saveAndNotify();
    return true;
  }

  Future<void> toggleCosmetic(String cosmeticId) async {
    final cosmetic = cosmeticById(cosmeticId);
    if (!ownsCosmetic(cosmetic)) return;
    final key = _cosmeticKey(progress.selectedPet, cosmetic.id);
    if (!progress.equippedCosmetics.add(key)) {
      progress.equippedCosmetics.remove(key);
    }
    await _saveAndNotify();
  }

  Future<void> completeLevel({
    required LevelDefinition level,
    required int correct,
    required int total,
    required int seconds,
    required List<Question> missedQuestions,
  }) async {
    final stars = _starsFor(correct: correct, total: total);
    final previousStars = progress.levelStars[level.id] ?? 0;
    final previousBest = progress.bestTimes[level.id];
    if (stars > previousStars) {
      progress.totalStars += stars - previousStars;
      progress.levelStars[level.id] = stars;
    }
    if (stars > 0) {
      progress.completedLevels.add(level.id);
      progress.energyFruit += correct == total ? 3 : 1;
      if (previousBest != null && correct == total && seconds < previousBest) {
        progress.energyFruit += 10;
      }
    }
    _recordBestTime(level.id, seconds, correct == total);
    _recordWinStreak(correct, total);
    for (final question in missedQuestions.where((q) => q.subject != '数独')) {
      _recordWrong(question);
    }
    _syncCosmetics();
    await _saveAndNotify();
  }

  Future<BossEscapeOutcome> resolveBossEscape({
    required int remainingHp,
    required int totalHp,
  }) async {
    if (remainingHp <= 0 || totalHp <= 0) {
      return const BossEscapeOutcome(escaped: false);
    }
    final rng = Random(
      DateTime.now().microsecondsSinceEpoch + remainingHp * 37,
    );
    final stealChance = (remainingHp / totalHp).clamp(0.0, 1.0);
    if (rng.nextDouble() > stealChance) {
      await _saveAndNotify();
      return const BossEscapeOutcome(escaped: true);
    }

    final options = <String>[
      if (progress.energyFruit > 0) 'energyFruit',
      if (progress.totalStars > 0) 'totalStars',
      if (progress.badges.isNotEmpty) 'badge',
    ];
    if (options.isEmpty) {
      if (progress.unlockedCosmetics.isNotEmpty) {
        final cosmeticId = progress.unlockedCosmetics.elementAt(
          rng.nextInt(progress.unlockedCosmetics.length),
        );
        progress.unlockedCosmetics.remove(cosmeticId);
        progress.equippedCosmetics.remove(cosmeticId);
        await _saveAndNotify();
        return const BossEscapeOutcome(
          escaped: true,
          stolenType: 'cosmetic',
          stolenAmount: 1,
        );
      }
      await _saveAndNotify();
      return const BossEscapeOutcome(escaped: true);
    }

    final type = options[rng.nextInt(options.length)];
    final severity = 1 + (remainingHp * 2 ~/ totalHp);
    var amount = 1;
    switch (type) {
      case 'energyFruit':
        amount = min(progress.energyFruit, max(1, severity));
        progress.energyFruit -= amount;
      case 'totalStars':
        amount = min(progress.totalStars, max(1, severity));
        progress.totalStars -= amount;
      case 'badge':
        final badge = progress.badges.last;
        progress.badges.remove(badge);
        amount = 1;
    }
    await _saveAndNotify();
    return BossEscapeOutcome(
      escaped: true,
      stolenType: type,
      stolenAmount: amount,
    );
  }

  Future<String> completeSudoku(
    SudokuPuzzle puzzle, {
    int seconds = 1 << 20,
    bool cleanRun = false,
  }) async {
    progress.completedLevels.add(puzzle.id);
    progress.challengeHistory['sudoku_completed_count'] =
        (progress.challengeHistory['sudoku_completed_count'] ?? 0) + 1;
    final count = progress.challengeHistory['sudoku_completed_count'] ?? 1;
    var reward = '案件破解成功！本次未触发限时一次通过奖励。';
    if (cleanRun) {
      if (puzzle.size == 4 && seconds <= 60) {
        progress.energyFruit += 1;
        reward = '案件破解成功！1分钟内一次通过，获得1颗能量果。';
      } else if (puzzle.size == 6 && seconds <= 180) {
        progress.totalStars += 1;
        progress.levelStars[puzzle.id] = max(
          progress.levelStars[puzzle.id] ?? 0,
          1,
        );
        reward = '案件破解成功！3分钟内一次通过，获得1颗星星。';
      } else if (puzzle.size == 9 && seconds <= 600) {
        _addBadge('侦探大师勋章 $count');
        reward = '案件破解成功！10分钟内一次通过，获得1枚勋章。';
      }
    }
    _syncCosmetics();
    await _saveAndNotify();
    return reward;
  }

  Future<void> recordSudokuReset(String puzzleId) async {
    progress.sudokuResets[puzzleId] =
        (progress.sudokuResets[puzzleId] ?? 0) + 1;
    await _saveAndNotify();
  }

  Future<void> recordWrongChallenge({
    required WrongItem item,
    required bool isCorrect,
  }) async {
    item.lastPracticedAt = DateTime.now();
    if (isCorrect) {
      item.variantCorrectStreak += 1;
      progress.energyFruit += 1;
      if (item.variantCorrectStreak >= 3) {
        progress.wrongItems.remove(item);
      }
    } else {
      item.variantCorrectStreak = 0;
      item.wrongCount += 1;
    }
    _recordWinStreak(isCorrect ? 1 : 0, 1);
    _syncCosmetics();
    await _saveAndNotify();
  }

  Future<void> recordDailyChallenge({
    required int correct,
    required int total,
    required int seconds,
  }) async {
    final key = _todayKey();
    progress.challengeHistory['daily_$key'] = correct;
    final best = progress.challengeHistory['daily_best'] ?? 0;
    final previousBestTime = progress.bestTimes['daily_challenge'];
    if (correct > best) {
      progress.challengeHistory['daily_best'] = correct;
      _addBadge('今日挑战新纪录');
    }
    if (correct > 0) {
      progress.energyFruit += correct >= total ? 3 : 1;
      if (previousBestTime != null &&
          correct == total &&
          seconds < previousBestTime) {
        progress.energyFruit += 10;
      }
    }
    _recordBestTime('daily_challenge', seconds, correct == total);
    _recordWinStreak(correct, total);
    _syncCosmetics();
    await _saveAndNotify();
  }

  Future<WorksheetCompletionResult> completeWorksheetPractice({
    required String worksheetId,
    required int day,
    required int correct,
    required int total,
    required List<Question> missedQuestions,
  }) async {
    final levelId = 'worksheet:$worksheetId:day$day';
    final stars = total <= 0 ? 0 : _starsFor(correct: correct, total: total);
    final previousStars = progress.levelStars[levelId] ?? 0;
    final addedStars = max(0, stars - previousStars);
    var addedEnergyFruit = 0;
    if (addedStars > 0) {
      progress.totalStars += addedStars;
      progress.levelStars[levelId] = stars;
      progress.completedLevels.add(levelId);
      addedEnergyFruit = stars == 3 ? 3 : 1;
      progress.energyFruit += addedEnergyFruit;
      if (stars == 3) {
        progress.petExp += 1;
      }
    }
    progress.challengeHistory['worksheet_${worksheetId}_day_$day'] = correct;
    _recordWinStreak(correct, total);
    for (final question in missedQuestions) {
      _recordWrong(question);
    }
    _syncCosmetics();
    await _saveAndNotify();
    return WorksheetCompletionResult(
      stars: stars,
      addedStars: addedStars,
      addedEnergyFruit: addedEnergyFruit,
      correct: correct,
      total: total,
    );
  }

  Future<void> addParentChallenge({
    required String prompt,
    required String answer,
    required String subject,
  }) async {
    progress.parentChallenges.insert(
      0,
      ParentChallenge(
        id: 'PC-${DateTime.now().microsecondsSinceEpoch}',
        prompt: prompt,
        answer: answer,
        subject: subject,
        createdAt: DateTime.now(),
      ),
    );
    if (progress.parentChallenges.length > 30) {
      progress.parentChallenges.removeRange(
        30,
        progress.parentChallenges.length,
      );
    }
    await _saveAndNotify();
  }

  Future<void> completeParentChallenge(ParentChallenge challenge) async {
    challenge.completed = true;
    progress.energyFruit += 2;
    progress.challengeHistory['parent_completed'] =
        (progress.challengeHistory['parent_completed'] ?? 0) + 1;
    _syncCosmetics();
    await _saveAndNotify();
  }

  Future<void> grantDailyReward({bool saveImmediately = true}) async {
    final today = _todayKey();
    if (progress.dailyRewardDate == today || progress.selectedGrade == null) {
      return;
    }
    progress.dailyRewardDate = today;
    progress.energyFruit += 1;
    if (saveImmediately) await _saveAndNotify();
  }

  Future<bool> feedPet() async {
    if (progress.energyFruit <= 0) return false;
    progress.energyFruit -= 1;
    progress.petExp += 1;
    _syncCosmetics();
    await _saveAndNotify();
    return true;
  }

  Future<void> setSetting(String key, bool value) async {
    progress.settings[key] = value;
    await _saveAndNotify();
  }

  Future<void> resetProgress() async {
    progress = AppProgress();
    await _saveAndNotify();
  }

  int _starsFor({required int correct, required int total}) {
    if (correct == total) return 3;
    if (correct / total >= 0.8) return 2;
    if (correct / total >= 0.6) return 1;
    return 0;
  }

  void _recordWrong(Question question) {
    WrongItem? existing;
    for (final item in progress.wrongItems) {
      final matched =
          item.originalQuestion.id == question.id ||
          (item.originalQuestion.prompt == question.prompt &&
              item.questionType == question.questionType);
      if (matched) {
        existing = item;
        break;
      }
    }
    if (existing != null) {
      existing.wrongCount += 1;
      existing.variantCorrectStreak = 0;
      return;
    }
    progress.wrongItems.insert(
      0,
      WrongItem(
        originalQuestion: question,
        knowledgePoint: question.knowledgePoint,
        questionType: question.questionType,
        createdAt: DateTime.now(),
      ),
    );
    if (progress.wrongItems.length > 160) {
      progress.wrongItems.removeRange(160, progress.wrongItems.length);
    }
  }

  void _recordBestTime(String key, int seconds, bool perfect) {
    if (!perfect) return;
    final previous = progress.bestTimes[key];
    if (previous == null || seconds < previous) {
      progress.bestTimes[key] = seconds;
    }
  }

  void _recordWinStreak(int correct, int total) {
    if (correct == total) {
      progress.winStreak += total;
    } else {
      progress.winStreak = 0;
    }
  }

  void _addBadge(String badge) {
    progress.badges.add(badge);
  }

  void _syncCosmetics() {
    final legacyNames = {
      '帽子装扮': 'hat',
      '背包配饰': 'backpack',
      '特效光环': 'halo',
      '终极形态': 'ultimate',
      '学霸披风': 'cape',
      '知识皇冠': 'crown',
    };
    final migrated = <String>{};
    for (final item in progress.unlockedCosmetics) {
      migrated.add(_normalizeCosmeticStorageId(legacyNames[item] ?? item));
    }
    progress.unlockedCosmetics
      ..clear()
      ..addAll(migrated.where(_isValidPetCosmeticKey));
    final equipped = progress.equippedCosmetics
        .map((id) => _normalizeCosmeticStorageId(legacyNames[id] ?? id))
        .where(progress.unlockedCosmetics.contains)
        .toSet();
    progress.equippedCosmetics
      ..clear()
      ..addAll(equipped);
  }

  String _cosmeticKey(String? petId, String cosmeticId) {
    return '${petId ?? progress.selectedPet ?? 'dino'}:$cosmeticId';
  }

  String _normalizeCosmeticStorageId(String id) {
    if (id.contains(':')) return id;
    return _cosmeticKey(progress.selectedPet, id);
  }

  bool _isValidPetCosmeticKey(String key) {
    final parts = key.split(':');
    if (parts.length != 2) return false;
    return pets.any((pet) => pet.id == parts.first) &&
        cosmetics.any((cosmetic) => cosmetic.id == parts.last);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveAndNotify() async {
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_schemaKey, schemaVersion);
    await prefs.setString(_progressKey, jsonEncode(progress.toJson()));
  }
}
