enum Island { math, chinese, english, sudoku }

enum QuestionInputMode { choice, sequence, vertical }

const int gradeOneUp = 11;
const int gradeOneDown = 12;
const int gradeTwoUp = 21;
const int gradeTwoDown = 22;

int normalizeGradeCode(int? grade) {
  return switch (grade) {
    gradeOneUp || gradeOneDown || gradeTwoUp || gradeTwoDown => grade!,
    2 => gradeTwoUp,
    _ => gradeOneUp,
  };
}

int gradeYearOf(int? grade) => normalizeGradeCode(grade) ~/ 10;

int gradeTermOf(int? grade) => normalizeGradeCode(grade) % 10;

bool supportsLearningStage({
  required int selectedGrade,
  required int gradeMin,
  required int gradeMax,
  int termMin = 1,
  int termMax = 2,
}) {
  final year = gradeYearOf(selectedGrade);
  final term = gradeTermOf(selectedGrade);
  return year >= gradeMin &&
      year <= gradeMax &&
      term >= termMin &&
      term <= termMax;
}

class PetDefinition {
  const PetDefinition({
    required this.id,
    required this.name,
    required this.role,
    required this.description,
    required this.primaryColor,
    this.badgeCost = 0,
    this.starter = true,
  });

  final String id;
  final String name;
  final String role;
  final String description;
  final int primaryColor;
  final int badgeCost;
  final bool starter;
}

class CosmeticDefinition {
  const CosmeticDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.requiredLevel,
    required this.fruitCost,
    required this.starCost,
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final int requiredLevel;
  final int fruitCost;
  final int starCost;
}

class LevelDefinition {
  const LevelDefinition({
    required this.id,
    required this.island,
    required this.chapterId,
    required this.chapterTitle,
    required this.title,
    required this.scene,
    required this.knowledgePoint,
    required this.levelIndex,
    required this.generatorKind,
    required this.questionType,
    required this.gradeMin,
    required this.gradeMax,
    this.termMin = 1,
    this.termMax = 2,
    this.bossKind = 'life',
  });

  final String id;
  final Island island;
  final String chapterId;
  final String chapterTitle;
  final String title;
  final String scene;
  final String knowledgePoint;
  final int levelIndex;
  final String generatorKind;
  final String questionType;
  final int gradeMin;
  final int gradeMax;
  final int termMin;
  final int termMax;
  final String bossKind;

  bool supportsGrade(int grade) => supportsLearningStage(
    selectedGrade: grade,
    gradeMin: gradeMin,
    gradeMax: gradeMax,
    termMin: termMin,
    termMax: termMax,
  );
}

class BossEscapeOutcome {
  const BossEscapeOutcome({
    required this.escaped,
    this.stolenType,
    this.stolenAmount = 0,
  });

  final bool escaped;
  final String? stolenType;
  final int stolenAmount;

  String get message {
    if (!escaped) return 'Boss被打倒了，没有机会逃走。';
    if (stolenType == null || stolenAmount <= 0) {
      return 'Boss趁乱逃走了，不过什么也没偷到。';
    }
    final label = switch (stolenType) {
      'energyFruit' => '能量果',
      'totalStars' => '星星',
      'badge' => '勋章',
      'cosmetic' => '装扮道具',
      _ => '奖励',
    };
    return 'Boss逃走时偷走了$stolenAmount 个$label。';
  }
}

class WorksheetCompletionResult {
  const WorksheetCompletionResult({
    required this.stars,
    required this.addedStars,
    required this.addedEnergyFruit,
    required this.addedDiamonds,
    required this.correct,
    required this.total,
  });

  final int stars;
  final int addedStars;
  final int addedEnergyFruit;
  final int addedDiamonds;
  final int correct;
  final int total;

  String get message {
    if (total <= 0) return '这套试卷还没有题目。';
    final diamondText = addedDiamonds > 0 ? '，还获得1颗钻石' : '';
    if (stars == 3) {
      return '太棒了，全部做对！获得$addedStars颗星星、$addedEnergyFruit个能量果$diamondText！';
    }
    if (stars > 0) {
      return '本次做对$correct/$total题，获得$addedStars颗星星、$addedEnergyFruit个能量果。';
    }
    return '本次做对$correct/$total题，再练一练，奖励就在前面。';
  }
}

class Question {
  const Question({
    required this.id,
    required this.subject,
    required this.knowledgePoint,
    required this.questionType,
    required this.prompt,
    required this.answer,
    required this.choices,
    required this.explanation,
    this.hint = '',
    this.inputMode = QuestionInputMode.choice,
    this.variantSeed = 0,
    this.isBoss = false,
    this.visual,
  });

  final String id;
  final String subject;
  final String knowledgePoint;
  final String questionType;
  final String prompt;
  final String answer;
  final List<String> choices;
  final String hint;
  final String explanation;
  final QuestionInputMode inputMode;
  final int variantSeed;
  final bool isBoss;
  final Map<String, String>? visual;

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'knowledgePoint': knowledgePoint,
    'questionType': questionType,
    'prompt': prompt,
    'answer': answer,
    'choices': choices,
    'hint': hint,
    'explanation': explanation,
    'inputMode': inputMode.name,
    'variantSeed': variantSeed,
    'isBoss': isBoss,
    if (visual != null) 'visual': visual,
  };

  factory Question.fromJson(Map<String, dynamic> json) => Question(
    id: json['id'] as String? ?? '',
    subject: json['subject'] as String? ?? '数学',
    knowledgePoint: json['knowledgePoint'] as String? ?? '',
    questionType: json['questionType'] as String? ?? 'calculation',
    prompt: json['prompt'] as String? ?? '',
    answer: json['answer'] as String? ?? '',
    choices: (json['choices'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(),
    hint: json['hint'] as String? ?? '',
    explanation: json['explanation'] as String? ?? '',
    inputMode: QuestionInputMode.values.firstWhere(
      (mode) => mode.name == json['inputMode'],
      orElse: () => QuestionInputMode.choice,
    ),
    variantSeed: json['variantSeed'] as int? ?? 0,
    isBoss: json['isBoss'] as bool? ?? false,
    visual: (json['visual'] as Map<dynamic, dynamic>?)?.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    ),
  );
}

class WrongItem {
  WrongItem({
    required this.originalQuestion,
    required this.knowledgePoint,
    required this.questionType,
    required this.createdAt,
    this.wrongCount = 1,
    this.variantCorrectStreak = 0,
    this.lastPracticedAt,
  });

  final Question originalQuestion;
  final String knowledgePoint;
  final String questionType;
  int wrongCount;
  int variantCorrectStreak;
  final DateTime createdAt;
  DateTime? lastPracticedAt;

  Map<String, dynamic> toJson() => {
    'originalQuestion': originalQuestion.toJson(),
    'knowledgePoint': knowledgePoint,
    'questionType': questionType,
    'wrongCount': wrongCount,
    'variantCorrectStreak': variantCorrectStreak,
    'createdAt': createdAt.toIso8601String(),
    'lastPracticedAt': lastPracticedAt?.toIso8601String(),
  };

  factory WrongItem.fromJson(Map<String, dynamic> json) => WrongItem(
    originalQuestion: Question.fromJson(
      (json['originalQuestion'] as Map<dynamic, dynamic>? ?? const {})
          .cast<String, dynamic>(),
    ),
    knowledgePoint: json['knowledgePoint'] as String? ?? '',
    questionType: json['questionType'] as String? ?? 'calculation',
    wrongCount: json['wrongCount'] as int? ?? 1,
    variantCorrectStreak: json['variantCorrectStreak'] as int? ?? 0,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    lastPracticedAt: DateTime.tryParse(
      json['lastPracticedAt'] as String? ?? '',
    ),
  );
}

class SudokuPuzzle {
  const SudokuPuzzle({
    required this.id,
    required this.title,
    required this.size,
    required this.boxRows,
    required this.boxCols,
    required this.solution,
    required this.givens,
    required this.difficulty,
    required this.caseClue,
    required this.gradeMin,
    required this.gradeMax,
  });

  final String id;
  final String title;
  final int size;
  final int boxRows;
  final int boxCols;
  final List<List<int>> solution;
  final List<List<int>> givens;
  final String difficulty;
  final String caseClue;
  final int gradeMin;
  final int gradeMax;

  bool supportsGrade(int grade) => supportsLearningStage(
    selectedGrade: grade,
    gradeMin: gradeMin,
    gradeMax: gradeMax,
  );
}

class ParentChallenge {
  ParentChallenge({
    required this.id,
    required this.prompt,
    required this.answer,
    required this.subject,
    required this.createdAt,
    this.completed = false,
  });

  final String id;
  final String prompt;
  final String answer;
  final String subject;
  final DateTime createdAt;
  bool completed;

  Map<String, dynamic> toJson() => {
    'id': id,
    'prompt': prompt,
    'answer': answer,
    'subject': subject,
    'createdAt': createdAt.toIso8601String(),
    'completed': completed,
  };

  factory ParentChallenge.fromJson(Map<String, dynamic> json) =>
      ParentChallenge(
        id: json['id'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
        subject: json['subject'] as String? ?? '综合',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        completed: json['completed'] as bool? ?? false,
      );
}

class AppProgress {
  AppProgress({
    this.selectedGrade,
    this.selectedPet,
    this.energyFruit = 0,
    this.diamonds = 0,
    this.petExp = 0,
    this.totalStars = 0,
    this.dailyRewardDate,
    this.winStreak = 0,
    Map<String, int>? levelStars,
    Set<String>? completedLevels,
    List<WrongItem>? wrongItems,
    Set<String>? badges,
    Set<String>? unlockedPets,
    Map<String, int>? sudokuResets,
    Set<String>? unlockedCosmetics,
    Set<String>? equippedCosmetics,
    Map<String, bool>? settings,
    Map<String, int>? bestTimes,
    Map<String, int>? challengeHistory,
    Map<String, int>? realRewardRedemptions,
    List<ParentChallenge>? parentChallenges,
  }) : levelStars = levelStars ?? {},
       completedLevels = completedLevels ?? {},
       wrongItems = wrongItems ?? [],
       badges = badges ?? {},
       unlockedPets = unlockedPets ?? {'dino', 'fifi', 'apollo'},
       sudokuResets = sudokuResets ?? {},
       unlockedCosmetics = unlockedCosmetics ?? {},
       equippedCosmetics = equippedCosmetics ?? {},
       settings =
           settings ?? {'music': true, 'sfx': true, 'parentReview': false},
       bestTimes = bestTimes ?? {},
       challengeHistory = challengeHistory ?? {},
       realRewardRedemptions = realRewardRedemptions ?? {},
       parentChallenges = parentChallenges ?? [];

  int? selectedGrade;
  String? selectedPet;
  int energyFruit;
  int diamonds;
  int petExp;
  int totalStars;
  String? dailyRewardDate;
  int winStreak;
  final Map<String, int> levelStars;
  final Set<String> completedLevels;
  final List<WrongItem> wrongItems;
  final Set<String> badges;
  final Set<String> unlockedPets;
  final Map<String, int> sudokuResets;
  final Set<String> unlockedCosmetics;
  final Set<String> equippedCosmetics;
  final Map<String, bool> settings;
  final Map<String, int> bestTimes;
  final Map<String, int> challengeHistory;
  final Map<String, int> realRewardRedemptions;
  final List<ParentChallenge> parentChallenges;

  int get petLevel {
    if (petExp >= 350) return 7;
    if (petExp >= 200) return 6;
    if (petExp >= 100) return 5;
    if (petExp >= 50) return 4;
    if (petExp >= 25) return 3;
    if (petExp >= 10) return 2;
    return 1;
  }

  int get nextLevelExp {
    if (petLevel >= 7) return 350;
    return switch (petLevel + 1) {
      2 => 10,
      3 => 25,
      4 => 50,
      5 => 100,
      6 => 200,
      _ => 350,
    };
  }

  Map<String, dynamic> toJson() => {
    'selectedGrade': selectedGrade,
    'selectedPet': selectedPet,
    'energyFruit': energyFruit,
    'diamonds': diamonds,
    'petExp': petExp,
    'totalStars': totalStars,
    'dailyRewardDate': dailyRewardDate,
    'winStreak': winStreak,
    'levelStars': levelStars,
    'completedLevels': completedLevels.toList(),
    'wrongItems': wrongItems.map((item) => item.toJson()).toList(),
    'badges': badges.toList(),
    'unlockedPets': unlockedPets.toList(),
    'sudokuResets': sudokuResets,
    'unlockedCosmetics': unlockedCosmetics.toList(),
    'equippedCosmetics': equippedCosmetics.toList(),
    'settings': settings,
    'bestTimes': bestTimes,
    'challengeHistory': challengeHistory,
    'realRewardRedemptions': realRewardRedemptions,
    'parentChallenges': parentChallenges
        .map((challenge) => challenge.toJson())
        .toList(),
  };

  factory AppProgress.fromJson(Map<String, dynamic> json) => AppProgress(
    selectedGrade: json['selectedGrade'] == null
        ? null
        : normalizeGradeCode(json['selectedGrade'] as int?),
    selectedPet: json['selectedPet'] as String?,
    energyFruit: json['energyFruit'] as int? ?? 0,
    diamonds: json['diamonds'] as int? ?? 0,
    petExp: json['petExp'] as int? ?? json['energyFruit'] as int? ?? 0,
    totalStars: json['totalStars'] as int? ?? 0,
    dailyRewardDate: json['dailyRewardDate'] as String?,
    winStreak: json['winStreak'] as int? ?? 0,
    levelStars: (json['levelStars'] as Map<dynamic, dynamic>? ?? const {}).map(
      (key, value) => MapEntry(key.toString(), value as int),
    ),
    completedLevels: (json['completedLevels'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toSet(),
    wrongItems: (json['wrongItems'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => WrongItem.fromJson(item.cast<String, dynamic>()))
        .toList(),
    badges: (json['badges'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toSet(),
    unlockedPets: {
      'dino',
      'fifi',
      'apollo',
      ...(json['unlockedPets'] as List<dynamic>? ?? const []).map(
        (item) => item.toString(),
      ),
    },
    sudokuResets: (json['sudokuResets'] as Map<dynamic, dynamic>? ?? const {})
        .map((key, value) => MapEntry(key.toString(), value as int)),
    unlockedCosmetics: (json['unlockedCosmetics'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toSet(),
    equippedCosmetics: (json['equippedCosmetics'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toSet(),
    settings: {
      'music': true,
      'sfx': true,
      'parentReview': false,
      ...(json['settings'] as Map<dynamic, dynamic>? ?? const {}).map(
        (key, value) => MapEntry(key.toString(), value == true),
      ),
    },
    bestTimes: (json['bestTimes'] as Map<dynamic, dynamic>? ?? const {}).map(
      (key, value) => MapEntry(key.toString(), value as int),
    ),
    challengeHistory:
        (json['challengeHistory'] as Map<dynamic, dynamic>? ?? const {}).map(
          (key, value) => MapEntry(key.toString(), value as int),
        ),
    realRewardRedemptions:
        (json['realRewardRedemptions'] as Map<dynamic, dynamic>? ?? const {})
            .map((key, value) => MapEntry(key.toString(), value as int)),
    parentChallenges: (json['parentChallenges'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((item) => ParentChallenge.fromJson(item.cast<String, dynamic>()))
        .toList(),
  );
}
