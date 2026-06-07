import 'dart:math';

import '../models/app_models.dart';

const pets = [
  PetDefinition(
    id: 'dino',
    name: '迪诺',
    role: '小恐龙',
    description: '活泼型，动作幅度大，适合喜欢热闹的小探险家。',
    primaryColor: 0xFF4CAF50,
  ),
  PetDefinition(
    id: 'fifi',
    name: '果果',
    role: '小狐狸',
    description: '机灵型，眼睛亮亮的，陪你一起发现规律。',
    primaryColor: 0xFFFF8C42,
  ),
  PetDefinition(
    id: 'apollo',
    name: '阿波',
    role: '小宇航员',
    description: '科技型，带一点悬浮特效，适合未来感探险。',
    primaryColor: 0xFF42A5F5,
  ),
  PetDefinition(
    id: 'magic_star',
    name: '星愿露露',
    role: '星杖魔法宠',
    description: '挥动星星法杖，带着闪亮魔法特效陪你闯关。',
    primaryColor: 0xFFFF80AB,
    badgeCost: 4,
    starter: false,
  ),
  PetDefinition(
    id: 'magic_moon',
    name: '月影米娅',
    role: '月光魔法宠',
    description: '月亮丝带会轻轻发光，适合安静又专注的探险。',
    primaryColor: 0xFF8B5CF6,
    badgeCost: 7,
    starter: false,
  ),
  PetDefinition(
    id: 'magic_flower',
    name: '花晶妮妮',
    role: '花晶魔法宠',
    description: '花瓣和水晶环绕身边，完成挑战时会更闪耀。',
    primaryColor: 0xFF34D399,
    badgeCost: 10,
    starter: false,
  ),
];

const cosmetics = [
  CosmeticDefinition(
    id: 'hat',
    name: '探险帽',
    description: '戴上它，像真正的小队长一样出发。',
    icon: '🎒',
    requiredLevel: 2,
    fruitCost: 80,
    starCost: 40,
  ),
  CosmeticDefinition(
    id: 'backpack',
    name: '星星背包',
    description: '把今天学到的知识都装进去。',
    icon: '⭐',
    requiredLevel: 3,
    fruitCost: 160,
    starCost: 90,
  ),
  CosmeticDefinition(
    id: 'halo',
    name: '勇气光环',
    description: '答题时闪闪发亮，勇气值加满。',
    icon: '✨',
    requiredLevel: 6,
    fruitCost: 1000,
    starCost: 700,
  ),
  CosmeticDefinition(
    id: 'ultimate',
    name: '终极形态',
    description: '宠物进入高能探险状态。',
    icon: '⚡',
    requiredLevel: 7,
    fruitCost: 1600,
    starCost: 1100,
  ),
  CosmeticDefinition(
    id: 'cape',
    name: '学霸披风',
    description: '挑战高难关卡时很有气势。',
    icon: '🏅',
    requiredLevel: 4,
    fruitCost: 300,
    starCost: 180,
  ),
  CosmeticDefinition(
    id: 'crown',
    name: '知识皇冠',
    description: '为坚持学习的小探险家准备。',
    icon: '👑',
    requiredLevel: 5,
    fruitCost: 560,
    starCost: 360,
  ),
];

final mathChapterSpecs = [
  ChapterSpec(
    'M1',
    '准备课与位置',
    4,
    '1-10数数、比多少、上下前后左右、第几',
    'small_number',
    'number',
    1,
    1,
  ),
  ChapterSpec(
    'M2',
    '1-10加减小路',
    5,
    '1-5和6-10的认识、分与合、10以内加减',
    'ten_add_sub',
    'calculation',
    1,
    1,
  ),
  ChapterSpec(
    'M3',
    '11-20数位桥',
    4,
    '11-20各数、十和几、十几加减几',
    'teen_number',
    'number',
    1,
    1,
  ),
  ChapterSpec(
    'M4',
    '图形积木屋',
    3,
    '长方体、正方体、圆柱、球',
    'solid_shape',
    'geometry',
    1,
    1,
  ),
  ChapterSpec('M5', '钟表小镇', 3, '整时、半时、快几时和刚过几时', 'clock_basic', 'time', 1, 1),
  ChapterSpec('M6', '凑十火箭', 5, '20以内进位加法、凑十法', 'make_ten', 'calculation', 1, 1),
  ChapterSpec(
    'M7',
    '平面图形与分类',
    3,
    '平面图形、拼组、分类整理',
    'plane_classify',
    'geometry',
    1,
    1,
  ),
  ChapterSpec(
    'M8',
    '退位减法洞穴',
    5,
    '20以内退位减法、破十法',
    'subtract20',
    'calculation',
    1,
    1,
  ),
  ChapterSpec('M10', '人民币小镇', 4, '元角分、换算、购物找零', 'money', 'money', 1, 1),
  ChapterSpec(
    'M11',
    '百以内加减营地',
    5,
    '100以内不进位、不退位加减和应用',
    'hundred_add_sub',
    'calculation',
    1,
    1,
  ),
  ChapterSpec(
    'M25',
    '竖式计算工坊',
    1,
    '100以内加减竖式、进位退位、破百Boss',
    'vertical_calc',
    'calculation',
    1,
    1,
    termMin: 2,
    termMax: 2,
  ),
  ChapterSpec('M12', '规律花园', 4, '数字、图形、颜色、周期规律', 'pattern', 'pattern', 1, 1),
  ChapterSpec(
    'M13',
    '长度与角观察站',
    5,
    '厘米、米、线段、角和观察物体',
    'length_angle',
    'geometry',
    2,
    2,
  ),
  ChapterSpec(
    'M14',
    '百以内加减城堡',
    6,
    '100以内进位加法、退位减法、连加连减',
    'hundred_add_sub2',
    'calculation',
    2,
    2,
  ),
  ChapterSpec(
    'M15',
    '2-6口诀花园',
    6,
    '乘法意义、2-6乘法口诀、乘加乘减',
    'multiply_low',
    'calculation',
    2,
    2,
  ),
  ChapterSpec(
    'M16',
    '7-9口诀城堡',
    6,
    '7-9乘法口诀、倍的认识、乘法应用',
    'multiply_high',
    'calculation',
    2,
    2,
  ),
  ChapterSpec(
    'M17',
    '时间与搭配列车',
    5,
    '几时几分、经过时间、简单搭配',
    'time_combo',
    'time',
    2,
    2,
  ),
  ChapterSpec(
    'M18',
    '数据与图形运动营',
    3,
    '调查、分类计数、简单统计表、平移旋转',
    'data',
    'statistics',
    2,
    2,
  ),
  ChapterSpec(
    'M19',
    '平均分工坊',
    5,
    '平均分、除法含义、用2-6口诀求商',
    'divide_intro',
    'calculation',
    2,
    2,
  ),
  ChapterSpec(
    'M20',
    '表内除法山谷',
    5,
    '用7-9口诀求商、除法应用',
    'divide',
    'calculation',
    2,
    2,
  ),
  ChapterSpec(
    'M21',
    '混合与余数塔',
    6,
    '混合运算、有余数除法、余数关系',
    'mixed',
    'calculation',
    2,
    2,
  ),
  ChapterSpec(
    'M22',
    '万以内数王国',
    5,
    '万以内数的读写、比较、近似数',
    'large_number',
    'number',
    2,
    2,
  ),
  ChapterSpec('M23', '克千克驿站', 4, '克、千克、单位选择、重量应用', 'weight', 'unit', 2, 2),
  ChapterSpec('M24', '推理密室', 3, '搭配、简单推理、逻辑排序', 'logic', 'logic', 2, 2),
];

final chineseChapterSpecs = [
  ChapterSpec(
    'Y1',
    '识字启蒙园',
    5,
    '天地人、金木水火土、口耳目、日月水火、对韵歌',
    'hanzi',
    'stroke',
    1,
    1,
  ),
  ChapterSpec('Y2', '拼音溪流', 8, '声母、韵母、整体认读、声调、拼读', 'pinyin', 'pinyin', 1, 1),
  ChapterSpec(
    'Y3',
    '一年级上课文花园',
    5,
    '秋天、小小的船、江南、四季、比尾巴、青蛙写诗',
    'reading',
    'reading',
    1,
    1,
  ),
  ChapterSpec(
    'Y4',
    '一年级下识字词句',
    5,
    '春夏秋冬、姓氏歌、小青蛙、猜字谜、动物儿歌',
    'words_cn',
    'vocabulary',
    1,
    1,
  ),
  ChapterSpec(
    'Y5',
    '一年级下阅读花园',
    5,
    '吃水不忘挖井人、静夜思、端午粽、彩虹、荷叶圆圆',
    'reading',
    'reading',
    1,
    1,
  ),
  ChapterSpec(
    'Y6',
    '二年级识字山谷',
    6,
    '场景歌、树之歌、拍手歌、田家四季歌、偏旁形声',
    'hanzi',
    'stroke',
    2,
    2,
  ),
  ChapterSpec(
    'Y7',
    '词句训练营',
    6,
    '近反义词、量词、词语搭配、句式仿写、标点语气',
    'words_cn',
    'vocabulary',
    2,
    2,
  ),
  ChapterSpec(
    'Y8',
    '二年级上阅读岛',
    7,
    '小蝌蚪找妈妈、曹冲称象、登鹳雀楼、黄山奇石、坐井观天、寒号鸟',
    'reading',
    'reading',
    2,
    2,
  ),
  ChapterSpec(
    'Y9',
    '二年级下阅读岛',
    7,
    '村居、咏柳、雷锋叔叔、千人糕、寓言二则、传统节日、蜘蛛开店',
    'reading',
    'reading',
    2,
    2,
  ),
];

final englishChapterSpecs = [
  ChapterSpec(
    'E1',
    'Hello & Colours',
    6,
    '问候、自我介绍、颜色表达',
    'dialogue',
    'dialogue',
    1,
    1,
  ),
  ChapterSpec(
    'E2',
    'Numbers & School Things',
    6,
    '数字1-10、学习用品、课堂指令',
    'word',
    'word',
    1,
    1,
  ),
  ChapterSpec('E3', 'Animals & Fruit', 6, '动物、水果、喜好表达', 'word', 'word', 1, 1),
  ChapterSpec(
    'E4',
    'Room, Food & Clothes',
    6,
    '房间物品、食物饮品、衣物、方位',
    'dialogue',
    'dialogue',
    1,
    1,
  ),
  ChapterSpec(
    'E5',
    'Family & Friends',
    8,
    '家庭成员、朋友、男孩女孩、社区地点',
    'word',
    'word',
    2,
    2,
  ),
  ChapterSpec(
    'E6',
    'Community & Transport',
    8,
    '社区地点、交通工具、节日问候',
    'word',
    'word',
    2,
    2,
  ),
  ChapterSpec(
    'E7',
    'Playtime, Weather & Time',
    6,
    '活动、天气、季节、时间和日常表达',
    'dialogue',
    'dialogue',
    2,
    2,
  ),
  ChapterSpec(
    'E8',
    'Phonics Lab',
    4,
    'CVC短元音、短元音家族、首尾音辨析',
    'phonics',
    'phonics',
    2,
    2,
  ),
];

final List<LevelDefinition> mathLevels = [
  for (final spec in mathChapterSpecs)
    for (var i = 1; i <= spec.count; i++) _level(Island.math, spec, i),
];

final List<LevelDefinition> chineseLevels = [
  for (final spec in chineseChapterSpecs)
    for (var i = 1; i <= spec.count; i++) _level(Island.chinese, spec, i),
];

final List<LevelDefinition> englishLevels = [
  for (final spec in englishChapterSpecs)
    for (var i = 1; i <= spec.count; i++) _level(Island.english, spec, i),
];

final List<LevelDefinition> playableLevels = [
  ...mathLevels,
  ...chineseLevels,
  ...englishLevels,
];

final List<SudokuPuzzle> sudokuPuzzles = [
  for (var i = 1; i <= 15; i++) _buildSudoku(i),
];

SudokuPuzzle buildRandomSudoku(int size) {
  final random = Random();
  final boxRows = size == 6
      ? 2
      : size == 4
      ? 2
      : 3;
  final boxCols = size == 6
      ? 3
      : size == 4
      ? 2
      : 3;
  final base = List.generate(
    size,
    (r) => List.generate(
      size,
      (c) => ((r * boxCols + r ~/ boxRows + c) % size) + 1,
    ),
  );

  List<int> shuffledGroups(int groupSize) {
    final groups = [
      for (var start = 0; start < size; start += groupSize)
        [for (var i = 0; i < groupSize; i++) start + i]..shuffle(random),
    ]..shuffle(random);
    return groups.expand((group) => group).toList();
  }

  final rows = shuffledGroups(boxRows);
  final cols = shuffledGroups(boxCols);
  final symbols = [for (var i = 1; i <= size; i++) i]..shuffle(random);
  final solution = List.generate(
    size,
    (r) => List.generate(size, (c) => symbols[base[rows[r]][cols[c]] - 1]),
  );
  final targetGivens = switch (size) {
    4 => 5,
    6 => 10,
    _ => 24,
  };
  final cells = [
    for (var r = 0; r < size; r++)
      for (var c = 0; c < size; c++) (row: r, col: c),
  ]..shuffle(random);
  final givens = List.generate(size, (_) => List.filled(size, 0));
  for (final cell in cells.take(targetGivens)) {
    givens[cell.row][cell.col] = solution[cell.row][cell.col];
  }

  final difficulty = switch (size) {
    4 => '4×4 初级随机',
    6 => '6×6 进阶随机',
    _ => '9×9 侦探大师',
  };
  return SudokuPuzzle(
    id: 'S-random-$size',
    title: '$size×$size 随机案件',
    size: size,
    boxRows: boxRows,
    boxCols: boxCols,
    solution: solution,
    givens: givens,
    difficulty: difficulty,
    caseClue: '随机线索：把全部格子填完后，系统才会公布侦查结果。',
    gradeMin: 1,
    gradeMax: 2,
  );
}

PetDefinition petById(String? id) =>
    pets.firstWhere((pet) => pet.id == id, orElse: () => pets.first);

CosmeticDefinition cosmeticById(String id) => cosmetics.firstWhere(
  (cosmetic) => cosmetic.id == id,
  orElse: () => cosmetics.first,
);

LevelDefinition? levelById(String id) {
  for (final level in playableLevels) {
    if (level.id == id) return level;
  }
  return null;
}

String gradeName(int? grade) {
  return switch (normalizeGradeCode(grade)) {
    gradeOneDown => '一年级下册',
    gradeTwoUp => '二年级上册',
    gradeTwoDown => '二年级下册',
    _ => '一年级上册',
  };
}

String gradeShortName(int? grade) {
  return switch (normalizeGradeCode(grade)) {
    gradeOneDown => '一 下',
    gradeTwoUp => '二 上',
    gradeTwoDown => '二 下',
    _ => '一 上',
  };
}

const learningGradeCodes = [gradeOneUp, gradeOneDown, gradeTwoUp, gradeTwoDown];

String islandName(Island island) {
  switch (island) {
    case Island.math:
      return '数学岛';
    case Island.chinese:
      return '语文岛';
    case Island.english:
      return '英语岛';
    case Island.sudoku:
      return '数独侦探所';
  }
}

String bossAssetForLevel(LevelDefinition level) {
  if (level.id == 'daily_challenge') {
    return dailyChallengeBossAsset();
  }
  if (level.island == Island.math) {
    return _rotatingMathBossAsset(level);
  }
  final key = level.id.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  final mapped = _bossAssetReplacement(key);
  if (mapped != null) return mapped;
  return 'assets/bosses/boss_$key.png';
}

String _rotatingMathBossAsset(LevelDefinition level, [DateTime? now]) {
  final time = now ?? DateTime.now();
  final seed =
      level.id.codeUnits.fold<int>(0, (sum, code) => sum + code * 31) +
      time.microsecondsSinceEpoch;
  final index = seed.abs() % 24 + 1;
  return 'assets/bosses/boss_math_${index.toString().padLeft(2, '0')}.png';
}

String? _bossAssetReplacement(String key) {
  final parts = key.split('_');
  if (parts.length != 2) return null;
  final chapter = parts.first;
  final index = int.tryParse(parts.last);
  if (index == null) return null;

  String asset(String name) => 'assets/bosses/$name.png';

  if (chapter == 'm9' && index <= 5) {
    return asset('boss_math_${index.toString().padLeft(2, '0')}');
  }
  if (chapter == 'm15' && index == 6) return asset('boss_math_06');
  if (chapter == 'm17' && index <= 5) {
    return asset('boss_math_${(index + 6).toString().padLeft(2, '0')}');
  }
  if (chapter == 'm18' && index <= 3) {
    return asset('boss_math_${(index + 11).toString().padLeft(2, '0')}');
  }
  if (chapter == 'm19' && index <= 5) {
    return asset('boss_math_${(index + 14).toString().padLeft(2, '0')}');
  }
  if (chapter == 'm20' && index <= 5) {
    return asset('boss_math_${(index + 19).toString().padLeft(2, '0')}');
  }
  final mathExtra = <String, List<String>>{
    'm21': ['m2_6', 'm2_7', 'm2_8', 'm2_9', 'm2_10', 'm3_5'],
    'm22': ['m3_6', 'm3_7', 'm3_8', 'm4_4', 'm4_5'],
    'm23': ['m4_6', 'm5_4', 'm5_5', 'm6_6'],
    'm24': ['m7_5', 'm7_6', 'm10_5'],
  };
  final mathList = mathExtra[chapter];
  if (mathList != null && index <= mathList.length) {
    return asset('boss_${mathList[index - 1]}');
  }

  if (chapter == 'y5' && index <= 5) {
    return asset('boss_chinese_${index.toString().padLeft(2, '0')}');
  }
  if (chapter == 'y6' && index <= 6) {
    return asset('boss_chinese_${(index + 5).toString().padLeft(2, '0')}');
  }
  if (chapter == 'y7' && index <= 6) {
    return asset('boss_chinese_${(index + 11).toString().padLeft(2, '0')}');
  }
  if (chapter == 'y8' && index <= 7) {
    return asset('boss_chinese_${(index + 17).toString().padLeft(2, '0')}');
  }
  final chineseExtra = <String, List<String>>{
    'y9': ['y1_6', 'y1_7', 'y1_8', 'y2_9', 'y2_10', 'y3_6', 'y3_7'],
  };
  final chineseList = chineseExtra[chapter];
  if (chineseList != null && index <= chineseList.length) {
    return asset('boss_${chineseList[index - 1]}');
  }

  if (chapter == 'e4' && index <= 6) {
    return asset('boss_english_${index.toString().padLeft(2, '0')}');
  }
  if (chapter == 'e5' && index <= 8) {
    return asset('boss_english_${(index + 6).toString().padLeft(2, '0')}');
  }
  if (chapter == 'e6' && index <= 8) {
    return asset('boss_english_${(index + 14).toString().padLeft(2, '0')}');
  }
  final englishExtra = <String, List<String>>{
    'e7': ['english_23', 'english_24', 'e1_7', 'e1_8', 'e2_7', 'e2_8'],
    'e8': ['general_01', 'general_02', 'general_03', 'general_04'],
  };
  final englishList = englishExtra[chapter];
  if (englishList != null && index <= englishList.length) {
    return asset('boss_${englishList[index - 1]}');
  }

  return null;
}

String dailyChallengeBossAsset([DateTime? date]) {
  final now = date ?? DateTime.now();
  const assets = [
    'assets/bosses/boss_m1_1.png',
    'assets/bosses/boss_m3_4.png',
    'assets/bosses/boss_m8_2.png',
    'assets/bosses/boss_m12_6.png',
    'assets/bosses/boss_y1_3.png',
    'assets/bosses/boss_y2_7.png',
    'assets/bosses/boss_y4_4.png',
    'assets/bosses/boss_chinese_12.png',
    'assets/bosses/boss_e1_5.png',
    'assets/bosses/boss_e2_6.png',
    'assets/bosses/boss_e3_2.png',
    'assets/bosses/boss_english_09.png',
  ];
  final daySeed = now.year * 372 + now.month * 31 + now.day;
  return assets[daySeed % assets.length];
}

String dailyChallengeBossKind([DateTime? date]) {
  final kinds = ['slime', 'stone', 'clock', 'ink', 'sound', 'shell', 'snow'];
  final now = date ?? DateTime.now();
  return kinds[(now.year + now.month + now.day) % kinds.length];
}

List<ChapterSpec> chapterSpecsFor(Island island, int grade) {
  final specs = switch (island) {
    Island.math => mathChapterSpecs,
    Island.chinese => chineseChapterSpecs,
    Island.english => englishChapterSpecs,
    Island.sudoku => <ChapterSpec>[],
  };
  return specs.where((spec) => spec.supportsGrade(grade)).toList();
}

List<LevelDefinition> levelsForIsland(Island island, int grade) {
  final levels = switch (island) {
    Island.math => mathLevels,
    Island.chinese => chineseLevels,
    Island.english => englishLevels,
    Island.sudoku => <LevelDefinition>[],
  };
  return levels.where((level) => level.supportsGrade(grade)).toList();
}

LevelDefinition chapterPracticeLevel(Island island, ChapterSpec spec) {
  return LevelDefinition(
    id: '${spec.id}-chapter',
    island: island,
    chapterId: spec.id,
    chapterTitle: spec.title,
    title: spec.title,
    scene: spec.title,
    knowledgePoint: spec.knowledgePoint,
    levelIndex: 0,
    generatorKind: spec.kind,
    questionType: spec.questionType,
    gradeMin: spec.gradeMin,
    gradeMax: spec.gradeMax,
    termMin: spec.resolvedTermMin,
    termMax: spec.resolvedTermMax,
    bossKind: _bossKindFor(island, spec.id),
  );
}

int totalLevelsForIsland(Island island, int grade) {
  if (island == Island.sudoku) {
    return 3;
  }
  return levelsForIsland(island, grade).length;
}

LevelDefinition _level(Island island, ChapterSpec spec, int index) {
  return LevelDefinition(
    id: '${spec.id}-$index',
    island: island,
    chapterId: spec.id,
    chapterTitle: spec.title,
    title: '${spec.title} 第$index关',
    scene: spec.title,
    knowledgePoint: _levelKnowledge(spec, index),
    levelIndex: index,
    generatorKind: spec.kind,
    questionType: spec.questionType,
    gradeMin: spec.gradeMin,
    gradeMax: spec.gradeMax,
    termMin: spec.resolvedTermMin,
    termMax: spec.resolvedTermMax,
    bossKind: _bossKindFor(island, spec.id),
  );
}

String _bossKindFor(Island island, String chapterId) {
  if (island == Island.math) {
    if (chapterId == 'M5') return 'stone';
    if (chapterId == 'M6' || chapterId == 'M7') return 'clock';
    if (chapterId == 'M16') return 'shadow';
    return 'slime';
  }
  if (island == Island.chinese) {
    if (chapterId == 'Y1') return 'sound';
    if (chapterId == 'Y4') return 'book';
    return 'ink';
  }
  if (island == Island.english) {
    if (chapterId == 'E2') return 'shell';
    if (chapterId == 'E3') return 'snow';
    return 'cloud';
  }
  return 'shadow';
}

String _levelKnowledge(ChapterSpec spec, int index) {
  final details = <String, List<String>>{
    'M1': ['数一数', '比多少', '上下前后左右', '第几和5以内加减'],
    'M2': ['6-7的分与合', '8-9的分与合', '10的组成', '10以内加法', '10以内减法'],
    'M3': ['11-20读写', '十和几', '十几加几', '十几减几'],
    'M4': ['认识长方体和正方体', '认识圆柱和球', '立体图形分类'],
    'M5': ['整时', '半时', '接近几时'],
    'M6': ['9加几', '8、7、6加几', '5、4、3、2加几', '凑十应用', '进位综合'],
    'M7': ['认识平面图形', '图形拼组', '分类整理'],
    'M8': ['十几减9', '十几减8、7、6', '十几减5、4、3、2', '退位应用', '退位综合'],
    'M10': ['元角分认识', '人民币换算', '购物付钱', '简单找零'],
    'M11': ['整十数加减', '两位数加一位数', '两位数减一位数', '两位数加整十数', '解决问题'],
    'M25': ['竖式计算'],
    'M12': ['数字规律', '图形规律', '颜色周期', '规律综合'],
    'M13': ['认识厘米', '认识米', '线段长度', '角的初步认识', '观察物体'],
    'M14': ['两位数加两位数', '两位数减两位数', '进位加法', '退位减法', '连加连减', '估算与应用'],
    'M15': ['乘法意义', '2的口诀', '3-4的口诀', '5的口诀', '6的口诀', '乘加乘减'],
    'M16': ['7的口诀', '8的口诀', '9的口诀', '倍的认识', '口诀填空', '乘法应用'],
    'M17': ['几时几分', '经过时间', '简单搭配', '排列组合', '时间搭配综合'],
    'M18': ['分类调查', '统计表读数', '图形运动与数据比较'],
    'M19': ['平均分', '除法含义', '用2-6口诀求商', '除法填空', '平均分应用'],
    'M20': ['用7的口诀求商', '用8的口诀求商', '用9的口诀求商', '除法比较', '除法应用'],
    'M21': ['同级混合运算', '乘加乘减', '除加除减', '有余数除法', '余数判断', '混合应用'],
    'M22': ['万以内读数', '万以内写数', '数的组成', '大小比较', '近似数'],
    'M23': ['认识克', '认识千克', '重量比较', '重量应用'],
    'M24': ['搭配问题', '条件推理', '逻辑排序'],
    'Y1': ['天地人识字', '金木水火土', '口耳目手足', '日月水火', '对韵歌'],
    'Y2': [
      '单韵母',
      '声母bpmf',
      '声母dtnl-gkh',
      '声母jqx-zcs',
      '整体认读',
      '声调拼读',
      '三拼音节',
      '拼音综合',
    ],
    'Y3': ['秋天词句', '小小的船', '江南', '四季', '青蛙写诗'],
    'Y4': ['春夏秋冬', '姓氏歌', '小青蛙', '猜字谜', '动物儿歌'],
    'Y5': ['吃水不忘挖井人', '静夜思', '端午粽', '彩虹', '荷叶圆圆'],
    'Y6': ['场景歌', '树之歌', '拍手歌', '田家四季歌', '形声字', '偏旁归类'],
    'Y7': ['近义词', '反义词', '量词', '词语搭配', '句式仿写', '标点语气'],
    'Y8': ['小蝌蚪找妈妈', '曹冲称象', '登鹳雀楼', '黄山奇石', '坐井观天', '寒号鸟', '我要的是葫芦'],
    'Y9': ['村居与咏柳', '雷锋叔叔', '千人糕', '寓言二则', '传统节日', '蜘蛛开店', '二下阅读综合'],
    'E1': ['hello', 'hi', "I'm", 'red', 'blue', 'green'],
    'E2': ['one', 'five', 'ten', 'book', 'ruler', 'pencil'],
    'E3': ['cat', 'dog', 'bird', 'apple', 'banana', 'orange'],
    'E4': ['room', 'desk', 'rice', 'milk', 'shirt', 'on'],
    'E5': [
      'father',
      'mother',
      'sister',
      'brother',
      'friend',
      'girl',
      'boy',
      'park',
    ],
    'E6': [
      'school',
      'hospital',
      'park',
      'bus',
      'train',
      'Spring Festival',
      'birthday',
      'present',
    ],
    'E7': [
      'play football',
      'weather',
      'season',
      'seven o’clock',
      'get up',
      'daily talk',
    ],
    'E8': ['short a', 'short e', 'short i', 'short o'],
  };
  final list = details[spec.id];
  if (list == null || list.isEmpty) return spec.knowledgePoint;
  return list[(index - 1) % list.length];
}

SudokuPuzzle _buildSudoku(int index) {
  final size = index <= 6
      ? 4
      : index <= 12
      ? 6
      : 9;
  final boxRows = size == 4
      ? 2
      : size == 6
      ? 2
      : 3;
  final boxCols = size == 4
      ? 2
      : size == 6
      ? 3
      : 3;
  final shift = index % size;
  final solution = List.generate(
    size,
    (r) => List.generate(
      size,
      (c) => ((r * boxCols + r ~/ boxRows + c + shift) % size) + 1,
    ),
  );
  final blankRate = index <= 3
      ? 0.5
      : index <= 6
      ? 0.6
      : index <= 9
      ? 0.56
      : index <= 12
      ? 0.66
      : 0.72;
  final givens = List.generate(size, (r) {
    return List.generate(size, (c) {
      final keep = ((r * 7 + c * 5 + index * 3) % 100) / 100 > blankRate;
      return keep ? solution[r][c] : 0;
    });
  });
  givens[0][0] = solution[0][0];
  givens[size - 1][size - 1] = solution[size - 1][size - 1];
  final difficulty = index <= 3
      ? '初级侦探'
      : index <= 6
      ? '中级侦探'
      : index <= 9
      ? '高级侦探'
      : index <= 12
      ? '大侦探'
      : '侦探大师';
  return SudokuPuzzle(
    id: 'S-$index',
    title: '$difficulty 第${((index - 1) % 3) + 1}案',
    size: size,
    boxRows: boxRows,
    boxCols: boxCols,
    solution: solution,
    givens: givens,
    difficulty: difficulty,
    caseClue: '线索$index：宝石藏在第${(index % size) + 1}列附近。',
    gradeMin: 1,
    gradeMax: 2,
  );
}

class ChapterSpec {
  const ChapterSpec(
    this.id,
    this.title,
    this.count,
    this.knowledgePoint,
    this.kind,
    this.questionType,
    this.gradeMin,
    this.gradeMax, {
    this.termMin,
    this.termMax,
  });

  final String id;
  final String title;
  final int count;
  final String knowledgePoint;
  final String kind;
  final String questionType;
  final int gradeMin;
  final int gradeMax;
  final int? termMin;
  final int? termMax;

  int get resolvedTermMin => termMin ?? _defaultTermForChapter(id);

  int get resolvedTermMax => termMax ?? _defaultTermForChapter(id);

  bool supportsGrade(int grade) => supportsLearningStage(
    selectedGrade: grade,
    gradeMin: gradeMin,
    gradeMax: gradeMax,
    termMin: resolvedTermMin,
    termMax: resolvedTermMax,
  );
}

int _defaultTermForChapter(String id) {
  final prefix = id.isEmpty ? '' : id.substring(0, 1).toUpperCase();
  final number = int.tryParse(id.length > 1 ? id.substring(1) : '') ?? 1;
  if (prefix == 'M') {
    if (number <= 6) return 1;
    if (number <= 12) return 2;
    if (number <= 18) return 1;
    return 2;
  }
  if (prefix == 'Y') {
    if (number <= 3) return 1;
    if (number <= 5) return 2;
    if (number <= 8) return 1;
    return 2;
  }
  if (prefix == 'E') {
    if (number <= 2) return 1;
    if (number <= 4) return 2;
    if (number <= 6) return 1;
    return 2;
  }
  return 1;
}
