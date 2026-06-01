import 'dart:math';

import '../data/app_data.dart';
import '../models/app_models.dart';

class QuestionFactory {
  QuestionFactory({Random? random}) : random = random ?? Random();

  final Random random;

  List<Question> buildForLevel(LevelDefinition level, {int count = 10}) {
    if (count <= 0) return const [];

    final questions = <Question>[];
    final seen = <String>{};
    final maxAttempts = max(80, count * 24);

    for (
      var attempt = 0;
      questions.length < count && attempt < maxAttempts;
      attempt++
    ) {
      final candidateIndex = attempt < count
          ? attempt
          : count + attempt * 3 + random.nextInt(count * 5 + 7);
      final candidate = _build(level, candidateIndex, isBoss: false);
      if (seen.add(_questionKey(candidate))) {
        questions.add(candidate);
      }
    }

    if (questions.isEmpty) {
      questions.add(_build(level, 0, isBoss: false));
    }

    return [
      for (var i = 0; i < questions.length; i++)
        _withBossFlag(questions[i], i == questions.length - 1),
    ];
  }

  List<Question> buildDailyChallenge(int grade) {
    final daySeed =
        DateTime.now().year * 372 +
        DateTime.now().month * 31 +
        DateTime.now().day;
    List<LevelDefinition> pick(Island island, int count) {
      final levels = levelsForIsland(island, grade);
      return [
        for (var i = 0; i < count; i++)
          levels[(daySeed + i * 7) % levels.length],
      ];
    }

    final math = pick(Island.math, 5);
    final chinese = pick(Island.chinese, 3);
    final english = pick(Island.english, 2);
    return [
      for (var i = 0; i < math.length; i++)
        _build(math[i], i, isBoss: i == math.length - 1),
      for (var i = 0; i < chinese.length; i++)
        _build(chinese[i], i, isBoss: i == chinese.length - 1),
      for (var i = 0; i < english.length; i++)
        _build(english[i], i, isBoss: i == english.length - 1),
    ];
  }

  Question buildVariant(WrongItem item) {
    final original = item.originalQuestion;
    final island = switch (original.subject) {
      '语文' => Island.chinese,
      '英语' => Island.english,
      _ => Island.math,
    };
    final level = _quickLevel(
      'wrong-${DateTime.now().microsecondsSinceEpoch}',
      island,
      item.knowledgePoint,
      _kindFromWrong(item),
      item.questionType,
      2,
    );
    return _build(
      level,
      item.wrongCount + item.variantCorrectStreak + 3,
      isBoss: false,
    );
  }

  LevelDefinition _quickLevel(
    String id,
    Island island,
    String knowledge,
    String kind,
    String type,
    int grade,
  ) {
    return LevelDefinition(
      id: id,
      island: island,
      chapterId: 'TEMP',
      chapterTitle: knowledge,
      title: knowledge,
      scene: knowledge,
      knowledgePoint: knowledge,
      levelIndex: grade,
      generatorKind: kind,
      questionType: type,
      gradeMin: 1,
      gradeMax: 2,
    );
  }

  Question _build(LevelDefinition level, int index, {required bool isBoss}) {
    switch (level.generatorKind) {
      case 'small_number':
        return _smallNumber(level, index, isBoss);
      case 'ten_add_sub':
        return _tenAddSub(level, index, isBoss);
      case 'teen_number':
        return _teenNumber(level, index, isBoss);
      case 'solid_shape':
        return _solidShape(level, index, isBoss);
      case 'clock_basic':
        return _clockBasic(level, index, isBoss);
      case 'make_ten':
        return _makeTen(level, index, isBoss);
      case 'plane_classify':
        return _planeClassify(level, index, isBoss);
      case 'subtract20':
        return _subtract20(level, index, isBoss);
      case 'hundred_number':
        return _hundredNumber(level, index, isBoss);
      case 'hundred_add_sub':
        return _hundredAddSub(level, index, isBoss, advanced: false);
      case 'length_angle':
        return _lengthAngle(level, index, isBoss);
      case 'hundred_add_sub2':
        return _hundredAddSub(level, index, isBoss, advanced: true);
      case 'time_combo':
        return _timeCombo(level, index, isBoss);
      case 'data':
        return _data(level, index, isBoss);
      case 'divide_intro':
        return _divideIntro(level, index, isBoss);
      case 'number':
        return _number(level, index, isBoss);
      case 'add_sub':
        return _addSub(level, index, 40, isBoss);
      case 'carry':
        return _addSub(level, index, 100, isBoss, carry: true);
      case 'chain':
        return _chain(level, index, isBoss);
      case 'shape':
        return _shape(level, index, isBoss);
      case 'time':
        return _time(level, index, isBoss);
      case 'money':
        return _money(level, index, isBoss);
      case 'pattern':
        return _pattern(level, index, isBoss);
      case 'multiply_low':
        return _multiply(level, index, 6, isBoss);
      case 'multiply_high':
        return _multiply(level, index, 9, isBoss, minFactor: 7);
      case 'divide':
        return _divide(level, index, isBoss);
      case 'mixed':
        return _mixed(level, index, isBoss);
      case 'large_number':
        return _largeNumber(level, index, isBoss);
      case 'weight':
        return _weight(level, index, isBoss);
      case 'logic':
        return _logic(level, index, isBoss);
      case 'pinyin':
        return _pinyin(level, index, isBoss);
      case 'hanzi':
        return _hanzi(level, index, isBoss);
      case 'words_cn':
        return _chineseWords(level, index, isBoss);
      case 'reading':
        return _reading(level, index, isBoss);
      case 'word':
        return _word(level, index, isBoss);
      case 'phonics':
        return _phonics(level, index, isBoss);
      case 'dialogue':
        return _dialogue(level, index, isBoss);
      default:
        return _addSub(level, index, 20, isBoss);
    }
  }

  Question _smallNumber(LevelDefinition level, int index, bool isBoss) {
    final stage = level.levelIndex;
    if (stage == 1) {
      final count = _range(1, 5);
      return _choice(
        level,
        index,
        '小松鼠采了$count颗松果，应该用哪个数表示？',
        '$count',
        ['1', '2', '3', '4', '5'],
        '一边点数，一边说出对应的数。',
        '数到$count，所以选$count。',
        isBoss,
      );
    }
    if (stage == 2) {
      final a = _range(1, 5);
      final b = _range(1, 5);
      final answer = a > b
          ? '>'
          : a < b
          ? '<'
          : '=';
      return _choice(
        level,
        index,
        '$a 和 $b 比一比，中间填什么？',
        answer,
        ['>', '<', '='],
        '数量多的一边更大，数量一样就填等号。',
        '$a 和 $b 比较，应该填 $answer。',
        isBoss,
      );
    }
    if (stage == 3) {
      final rows = [
        ['小猫在桌子的上面，小球在桌子的下面。小猫在哪里？', '上面', '找准参照物“桌子”。'],
        ['排队时，小红前面是小明，后面是小丽。小丽在小红的哪边？', '后面', '按队伍前进方向看前后。'],
        ['书包左边是铅笔盒，右边是水杯。水杯在书包的哪边？', '右边', '先找到书包，再分左右。'],
        ['从左往右数，第三个是红旗。红旗排第几？', '第3', '第几表示位置，不是数量。'],
      ];
      final row = rows[index % rows.length];
      return _choice(
        level,
        index,
        row[0],
        row[1],
        [row[1], '上面', '下面', '前面', '后面', '左边', '右边', '第2', '第3']
          ..shuffle(random),
        '先找到题目说的参照物，再判断位置。',
        row[2],
        isBoss,
      );
    }
    final a = _range(0, 5);
    final add = a < 3 || random.nextBool();
    final b = add ? _range(0, 5 - a) : _range(0, a);
    final answer = add ? a + b : a - b;
    return _choice(
      level,
      index,
      '$a ${add ? '+' : '-'} $b = ?',
      '$answer',
      _numberChoices(answer, spread: 4),
      add ? '可以把两部分合起来数。' : '可以从$a开始往回数$b个。',
      add ? '$a + $b = $answer。' : '$a - $b = $answer。',
      isBoss,
    );
  }

  Question _tenAddSub(LevelDefinition level, int index, bool isBoss) {
    final stage = level.levelIndex;
    if (stage <= 3) {
      final total = stage == 1
          ? _range(6, 7)
          : stage == 2
          ? _range(8, 9)
          : 10;
      final known = _range(1, total - 1);
      return _choice(
        level,
        index,
        '$total可以分成$known和几？',
        '${total - known}',
        _numberChoices(total - known, spread: 5),
        '想一想合起来要等于$total。',
        '$known + ${total - known} = $total。',
        isBoss,
      );
    }
    final add = stage == 4 || random.nextBool();
    final a = _range(1, 9);
    final b = add ? _range(1, 10 - a) : _range(1, a);
    final answer = add ? a + b : a - b;
    return _choice(
      level,
      index,
      '$a ${add ? '+' : '-'} $b = ?',
      '$answer',
      _numberChoices(answer, spread: 6),
      '先想10以内数的分与合。',
      '$a ${add ? '+' : '-'} $b = $answer。',
      isBoss,
    );
  }

  Question _teenNumber(LevelDefinition level, int index, bool isBoss) {
    final teen = _range(11, 20);
    if (level.levelIndex <= 2) {
      final ones = teen - 10;
      return _choice(
        level,
        index,
        '$teen里面有1个十和几个一？',
        '$ones个一',
        ['1个一', '2个一', '5个一', '$ones个一'],
        '十几就是1个十和几个一。',
        '$teen = 10 + $ones，所以有$ones个一。',
        isBoss,
      );
    }
    final b = _range(1, 8);
    final subtract = level.levelIndex == 4 || random.nextBool();
    final answer = subtract ? teen - b : teen + b;
    return _choice(
      level,
      index,
      '$teen ${subtract ? '-' : '+'} $b = ?',
      '$answer',
      _numberChoices(answer, spread: 7),
      '先看十位不变，再处理个位。',
      '$teen ${subtract ? '-' : '+'} $b = $answer。',
      isBoss,
    );
  }

  Question _solidShape(LevelDefinition level, int index, bool isBoss) {
    final items = [
      ('魔方', '正方体', '6个一样大的正方形面'),
      ('牙膏盒', '长方体', '有长长方方的面'),
      ('水杯', '圆柱', '上下两个圆形面'),
      ('皮球', '球', '圆圆的，没有平平的面'),
    ];
    final item = items[(index + level.levelIndex) % items.length];
    if (level.levelIndex == 3 || isBoss) {
      return _choice(
        level,
        index,
        '把魔方、牙膏盒、水杯、皮球分类，哪一个最像圆柱？',
        '水杯',
        items.map((e) => e.$1).toList(),
        '圆柱上下是圆形，中间直直的。',
        '水杯最像圆柱。',
        isBoss,
      );
    }
    return _choice(
      level,
      index,
      '${item.$1}最接近哪种立体图形？',
      item.$2,
      ['长方体', '正方体', '圆柱', '球'],
      item.$3,
      '${item.$1}可以看成${item.$2}。',
      isBoss,
    );
  }

  Question _clockBasic(LevelDefinition level, int index, bool isBoss) {
    final hour = _range(1, 12);
    if (level.levelIndex == 1) {
      return _choice(
        level,
        index,
        '分针指着12，时针指着$hour，现在是几时？',
        '$hour时',
        ['$hour时', '${hour % 12 + 1}时', '$hour时半', '${max(1, hour - 1)}时'],
        '分针指12表示整时。',
        '分针指12，时针指$hour，就是$hour时。',
        isBoss,
      );
    }
    if (level.levelIndex == 2) {
      return _choice(
        level,
        index,
        '分针指着6，时针走过$hour，现在是？',
        '$hour时半',
        ['$hour时', '$hour时半', '${hour % 12 + 1}时半', '${hour % 12 + 1}时'],
        '分针指6表示半时。',
        '分针指6，时针走过$hour，就是$hour时半。',
        isBoss,
      );
    }
    return _choice(
      level,
      index,
      '时针快指向${hour % 12 + 1}，分针快到12，可以说接近什么时间？',
      '快到${hour % 12 + 1}时',
      ['刚过$hour时', '快到${hour % 12 + 1}时', '$hour时半', '${hour % 12 + 1}时半'],
      '看时针接近哪个数字，再看分针是不是接近12。',
      '这是快到${hour % 12 + 1}时。',
      isBoss,
    );
  }

  Question _makeTen(LevelDefinition level, int index, bool isBoss) {
    final first = switch (level.levelIndex) {
      1 => 9,
      2 => [8, 7, 6][index % 3],
      3 => [5, 4, 3, 2][index % 4],
      _ => _range(2, 9),
    };
    final second = _range(2, 9);
    final answer = first + second;
    if (isBoss || level.levelIndex >= 4 && index.isOdd) {
      final used = _range(2, 8);
      return _choice(
        level,
        index,
        '盒子里有$first颗星星，又放进$second颗，拿走$used颗，还剩几颗？',
        '${answer - used}',
        _numberChoices(answer - used),
        '先用凑十法算加法，再减去拿走的。',
        '$first + $second = $answer，$answer - $used = ${answer - used}。',
        isBoss,
      );
    }
    return _choice(
      level,
      index,
      '$first + $second = ?',
      '$answer',
      _numberChoices(answer),
      '先把$first凑成10。',
      '$first还差${10 - first}到10，凑十后再加剩下的。',
      isBoss,
    );
  }

  Question _planeClassify(LevelDefinition level, int index, bool isBoss) {
    if (level.levelIndex <= 2) {
      final shapes = [
        ('红色三角形', '三角形'),
        ('蓝色圆形', '圆形'),
        ('黄色长方形', '长方形'),
        ('绿色正方形', '正方形'),
      ];
      final picked = shapes[(index + level.levelIndex) % shapes.length];
      return _choice(
        level,
        index,
        '${picked.$1}按形状分，属于哪一类？',
        picked.$2,
        ['三角形', '圆形', '长方形', '正方形'],
        '只看形状，不看颜色。',
        '${picked.$1}是${picked.$2}。',
        isBoss,
      );
    }
    final red = _range(2, 6);
    final blue = _range(1, 5);
    final yellow = _range(1, 5);
    final answer = level.levelIndex == 3 ? red : red + blue + yellow;
    return _choice(
      level,
      index,
      level.levelIndex == 3
          ? '图形盒里有$red个红色、$blue个蓝色、$yellow个黄色。按颜色分类，红色有几个？'
          : '图形盒里有$red个圆形、$blue个三角形、$yellow个长方形。一共有几个图形？',
      '$answer',
      _numberChoices(answer),
      '分类后先找准问题问的是哪一类。',
      '按题意计算，答案是$answer。',
      isBoss,
    );
  }

  Question _subtract20(LevelDefinition level, int index, bool isBoss) {
    final minuend = _range(11, 18);
    final subtrahend = switch (level.levelIndex) {
      1 => 9,
      2 => [8, 7, 6][index % 3],
      3 => [5, 4, 3, 2][index % 4],
      _ => _range(2, 9),
    };
    final answer = minuend - subtrahend;
    if (isBoss || level.levelIndex >= 4 && index.isOdd) {
      final addBack = _range(1, 5);
      return _choice(
        level,
        index,
        '书架上有$minuend本书，借走$subtrahend本，又还回$addBack本，现在有几本？',
        '${answer + addBack}',
        _numberChoices(answer + addBack),
        '先退位减，再加还回来的。',
        '$minuend - $subtrahend = $answer，$answer + $addBack = ${answer + addBack}。',
        isBoss,
      );
    }
    return _choice(
      level,
      index,
      '$minuend - $subtrahend = ?',
      '$answer',
      _numberChoices(answer),
      '可以想“破十法”：先从10里减。',
      '$minuend - $subtrahend = $answer。',
      isBoss,
    );
  }

  Question _hundredNumber(LevelDefinition level, int index, bool isBoss) {
    final n = _range(21, 99);
    if (level.levelIndex <= 2) {
      final tens = n ~/ 10;
      final ones = n % 10;
      return _choice(
        level,
        index,
        '$n由几个十和几个一组成？',
        '$tens个十和$ones个一',
        [
          '$tens个十和$ones个一',
          '$ones个十和$tens个一',
          '${tens + 1}个十和$ones个一',
          '$tens个十和${max(0, ones - 1)}个一',
        ],
        '十位上的数表示几个十，个位上的数表示几个一。',
        '$n的十位是$tens，个位是$ones。',
        isBoss,
      );
    }
    if (level.levelIndex == 5) {
      final target = _range(35, 75);
      return _choice(
        level,
        index,
        '和$target相比，下面哪个数可以说“多一些”？',
        '${target + _range(2, 8)}',
        [
          '${target + _range(2, 8)}',
          '${target + _range(20, 28)}',
          '${target - _range(2, 8)}',
          '${max(1, target - _range(20, 28))}',
        ],
        '“多一些”表示只多一点点。',
        '比$target大一点点的数，适合说多一些。',
        isBoss,
      );
    }
    final a = _range(10, 99);
    final b = _range(10, 99);
    final answer = a > b
        ? '>'
        : a < b
        ? '<'
        : '=';
    return _choice(
      level,
      index,
      '$a 和 $b 比大小，中间填什么？',
      answer,
      ['>', '<', '='],
      '先比十位，十位相同再比个位。',
      '比较后应填 $answer。',
      isBoss,
    );
  }

  Question _hundredAddSub(
    LevelDefinition level,
    int index,
    bool isBoss, {
    required bool advanced,
  }) {
    if (!advanced) {
      final kind = level.levelIndex;
      final a = kind == 1 ? _range(20, 80) ~/ 10 * 10 : _range(20, 89);
      final b = kind == 4 ? _range(10, 40) ~/ 10 * 10 : _range(2, 9);
      final subtract = kind == 3 || random.nextBool() && kind != 2;
      final subtractValue = min<int>(b, a % 10 == 0 ? 10 : b);
      final answer = subtract ? a - subtractValue : a + b;
      return _choice(
        level,
        index,
        '$a ${subtract ? '-' : '+'} $b = ?',
        '$answer',
        _numberChoices(answer),
        '先看十位和个位，整十数可以按几个十来算。',
        '$a ${subtract ? '-' : '+'} $b = $answer。',
        isBoss,
      );
    }
    if (level.levelIndex >= 5 || isBoss) {
      final a = _range(20, 49);
      final b = _range(10, 39);
      final c = _range(5, 25);
      final answer = level.levelIndex == 5 ? a + b - c : a + b;
      return _choice(
        level,
        index,
        level.levelIndex == 5
            ? '$a + $b - $c = ?'
            : '一年级有$a人，二年级比一年级多$b人，二年级有多少人？',
        '$answer',
        _numberChoices(answer),
        '按从左到右的顺序一步一步算。',
        level.levelIndex == 5
            ? '$a + $b - $c = $answer。'
            : '$a + $b = $answer。',
        isBoss,
      );
    }
    final add = level.levelIndex == 1 || level.levelIndex == 3;
    final a = add ? _range(28, 68) : _range(45, 98);
    final b = add ? _range(18, min(31, 99 - a)) : _range(17, min(39, a - 5));
    final answer = add ? a + b : a - b;
    return _choice(
      level,
      index,
      '$a ${add ? '+' : '-'} $b = ?',
      '$answer',
      _numberChoices(answer),
      add ? '个位相加满10要向十位进1。' : '个位不够减时，从十位退1作10。',
      '$a ${add ? '+' : '-'} $b = $answer。',
      isBoss,
    );
  }

  Question _lengthAngle(LevelDefinition level, int index, bool isBoss) {
    if (level.levelIndex <= 2) {
      final rows = level.levelIndex == 1
          ? [
              ('铅笔', '厘米', '小物体常用厘米。'),
              ('橡皮', '厘米', '橡皮比较短，用厘米更合适。'),
              ('课本的宽', '厘米', '课本的宽度通常用厘米测量。'),
              ('文具盒的长', '厘米', '文具盒放在桌面上，用厘米描述更清楚。'),
              ('手掌的宽', '厘米', '手掌宽度是较短的长度，常用厘米。'),
              ('直尺的长', '厘米', '直尺这样的短长度常用厘米。'),
            ]
          : [
              ('教室门的高', '米', '较高或较长的物体常用米。'),
              ('黑板的长', '米', '黑板比较长，用米更合适。'),
              ('教室的宽', '米', '教室这样的空间长度常用米。'),
              ('操场跑道的一小段', '米', '较长的距离通常用米。'),
              ('走廊的长', '米', '走廊比较长，常用米表示。'),
              ('树的高', '米', '树的高度适合用米估计。'),
            ];
      final row = rows[(index + level.levelIndex) % rows.length];
      return _choice(
        level,
        index,
        '测量${row.$1}，用哪个单位更合适？',
        row.$2,
        ['厘米', '米', '千克', '元'],
        '厘米和米都是长度单位，要根据物体大小来选。',
        row.$3,
        isBoss,
      );
    }
    if (level.levelIndex == 3) {
      final a = _range(3, 12);
      final b = _range(2, 9);
      return _choice(
        level,
        index,
        '一条线段长$a厘米，另一条长$b厘米，两条一共多少厘米？',
        '${a + b}',
        _numberChoices(a + b),
        '线段长度可以相加。',
        '$a + $b = ${a + b}厘米。',
        isBoss,
      );
    }
    if (level.levelIndex == 4) {
      final rows = [
        ('长方形', '一定有4个直角', '长方形的四个角都是直角。'),
        ('正方形', '一定有4个直角', '正方形的四个角也都是直角。'),
        ('三角尺上的最大角', '可能是直角', '常见三角尺里有一个角是直角。'),
        ('圆形', '没有直角', '圆形没有边和角。'),
        ('普通三角形', '不一定有直角', '三角形可能有直角，也可能没有。'),
        ('任意四边形', '不一定有直角', '不是所有四边形都有直角。'),
      ];
      final row = rows[(index + level.levelIndex) % rows.length];
      return _choice(
        level,
        index,
        '${row.$1}和直角的关系是？',
        row.$2,
        ['一定有4个直角', '可能是直角', '没有直角', '不一定有直角'],
        '直角像课本角一样方方正正。',
        row.$3,
        isBoss,
      );
    }
    final rows = [
      (
        '从小熊正面看杯子，能看到杯把；从右面看不到杯把。杯把大约在杯子的哪边？',
        '左边或正面可见的一侧',
        '正面能看到而右面看不到，说明杯把不在右侧。',
      ),
      ('从正面看积木塔是3块高，从上面看只有1个方块位置。这个塔最可能怎样摆？', '竖着叠3块', '上面只看见一个位置，说明方块上下叠在一起。'),
      ('一个鞋盒从正面看是长方形，从侧面看还是长方形，它更接近哪种立体图形？', '长方体', '鞋盒有长长方方的面，整体接近长方体。'),
      ('从上面看水杯，看到一个圆；从侧面看，像一个长方形。水杯最接近哪种立体图形？', '圆柱', '圆柱从上面看常是圆形，从侧面看像长方形。'),
      ('从左面看书包能看到侧袋，从右面看不到侧袋。侧袋大约在哪边？', '左边', '哪个方向能看见，物体特征就靠近哪个方向。'),
      ('同一个魔方，从正面和右面看到的颜色不一样，说明观察物体时要注意什么？', '观察方向', '站的位置不同，看到的面也不同。'),
    ];
    final row = rows[(index + level.levelIndex) % rows.length];
    return _choice(
      level,
      index,
      row.$1,
      row.$2,
      [row.$2, '杯子后面', '杯底下面', '圆形', '长方体', '圆柱', '观察方向']..shuffle(random),
      '观察物体要先想自己站在哪个方向。',
      row.$3,
      isBoss,
    );
  }

  Question _timeCombo(LevelDefinition level, int index, bool isBoss) {
    if (level.levelIndex <= 2) {
      final hour = _range(7, 9);
      final minute = [5, 10, 15, 20, 30, 45][index % 6];
      final add = level.levelIndex == 2 ? [10, 15, 20][index % 3] : 0;
      final answerMinute = minute + add;
      return _choice(
        level,
        index,
        add == 0 ? '$hour时$minute分怎么读？' : '$hour时$minute分过$add分钟是几时几分？',
        add == 0 ? '$hour时$minute分' : '$hour时$answerMinute分',
        [
          '$hour时$minute分',
          '$hour时$answerMinute分',
          '${hour + 1}时$minute分',
          '$hour时${(minute + 30) % 60}分',
        ],
        '1大格是5分钟，经过时间就往后数。',
        add == 0 ? '读作$hour时$minute分。' : '$minute + $add = $answerMinute。',
        isBoss,
      );
    }
    final shirts = _range(2, 4);
    final pants = _range(2, 3);
    final answer = shirts * pants;
    return _choice(
      level,
      index,
      '有$shirts件上衣和$pants条裤子，每次选一件上衣配一条裤子，有几种搭配？',
      '$answer',
      _numberChoices(answer, spread: 5),
      '每件上衣都可以配每条裤子。',
      '$shirts × $pants = $answer种。',
      isBoss,
    );
  }

  Question _data(LevelDefinition level, int index, bool isBoss) {
    final apple = _range(4, 9);
    final banana = _range(2, 8);
    final grape = _range(1, 7);
    if (level.levelIndex == 1) {
      return _choice(
        level,
        index,
        '调查喜欢的水果：苹果$apple人，香蕉$banana人，葡萄$grape人。喜欢苹果的有几人？',
        '$apple',
        _numberChoices(apple),
        '先读表头，再找苹果这一项。',
        '苹果对应的人数是$apple。',
        isBoss,
      );
    }
    final most = {
      '苹果': apple,
      '香蕉': banana,
      '葡萄': grape,
    }.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (level.levelIndex == 2) {
      return _choice(
        level,
        index,
        '苹果$apple人，香蕉$banana人，葡萄$grape人。喜欢哪种水果的人最多？',
        most.key,
        ['苹果', '香蕉', '葡萄'],
        '比较三个数的大小。',
        '${most.key}的人数最多。',
        isBoss,
      );
    }
    if (index.isOdd || isBoss) {
      final rows = [
        ['电梯门直直向左移动，这种运动是？', '平移', '物体沿直线移动，方向不变，叫平移。'],
        ['风车绕中心转起来，这种运动是？', '旋转', '围着一个点或一条轴转动，叫旋转。'],
        ['把一张纸对折，两边图案完全重合，说明它有什么特点？', '轴对称', '对折后能完全重合，就是轴对称。'],
      ];
      final row = rows[index % rows.length];
      return _choice(
        level,
        index,
        row[0],
        row[1],
        ['平移', '旋转', '轴对称', '分类'],
        '想一想图形是直线移动、转动，还是对折重合。',
        row[2],
        isBoss,
      );
    }
    return _choice(
      level,
      index,
      '苹果$apple人，香蕉$banana人，喜欢这两种水果的一共有几人？',
      '${apple + banana}',
      _numberChoices(apple + banana),
      '把两类人数合起来。',
      '$apple + $banana = ${apple + banana}。',
      isBoss,
    );
  }

  Question _divideIntro(LevelDefinition level, int index, bool isBoss) {
    if (level.levelIndex <= 2) {
      final groups = _range(2, 5);
      final each = _range(2, 6);
      final total = groups * each;
      return _choice(
        level,
        index,
        '$total颗糖平均分给$groups个小朋友，每人几颗？',
        '$each',
        _numberChoices(each, spread: 5),
        '平均分表示每份同样多。',
        '$total ÷ $groups = $each。',
        isBoss,
      );
    }
    final divisor = level.levelIndex == 3 ? _range(2, 6) : _range(2, 6);
    final quotient = _range(2, 8);
    final total = divisor * quotient;
    if (level.levelIndex == 4) {
      return _choice(
        level,
        index,
        '__ × $divisor = $total，所以$total ÷ $divisor = ?',
        '$quotient',
        _numberChoices(quotient, spread: 5),
        '用乘法口诀想除法。',
        '$quotient × $divisor = $total，所以商是$quotient。',
        isBoss,
      );
    }
    return _choice(
      level,
      index,
      '$total个桃子，每盘放$divisor个，可以放几盘？',
      '$quotient',
      _numberChoices(quotient, spread: 5),
      '求能分成几份，也可以用除法。',
      '$total ÷ $divisor = $quotient。',
      isBoss,
    );
  }

  Question _number(LevelDefinition level, int index, bool isBoss) {
    final a = _range(1, 100);
    final b = _range(1, 100);
    if (isBoss || index % 4 == 0) {
      final values = [_range(1, 20), _range(21, 60), _range(61, 100)]..sort();
      return _choice(
        level,
        index,
        '百数表任务：把 ${values.reversed.join('、')} 从小到大排队。',
        values.join('、'),
        [
          values.join('、'),
          values.reversed.join('、'),
          '${values[1]}、${values[0]}、${values[2]}',
          '${values[0]}、${values[2]}、${values[1]}',
        ],
        '先找十位小的数，再看个位。',
        '从小到大就是数字越来越大。',
        isBoss,
      );
    }
    final answer = a > b
        ? '>'
        : a < b
        ? '<'
        : '=';
    return _choice(
      level,
      index,
      '$a 和 $b 比一比，中间应该填什么？',
      answer,
      ['>', '<', '='],
      '把两个数放在数轴上，右边的更大。',
      '$a 与 $b 比较，正确符号是 $answer。',
      isBoss,
    );
  }

  Question _addSub(
    LevelDefinition level,
    int index,
    int max,
    bool isBoss, {
    bool carry = false,
  }) {
    if (isBoss) {
      final total = _range(26, max);
      final used = _range(8, min(30, total - 2));
      return _choice(
        level,
        index,
        '书架上原来有$total本书，借走$used本，又还回${index + 3}本，现在有多少本？',
        '${total - used + index + 3}',
        _numberChoices(total - used + index + 3),
        '先减去借走的，再加上还回的。',
        '$total - $used + ${index + 3} = ${total - used + index + 3}。',
        true,
      );
    }
    if (index % 3 == 1) {
      final answer = _range(8, max);
      final b = _range(2, min(20, answer - 1));
      return _choice(
        level,
        index,
        '__ + $b = $answer，空里填几？',
        '${answer - b}',
        _numberChoices(answer - b),
        '用总数减去已经知道的一部分。',
        '$answer - $b = ${answer - b}。',
        false,
      );
    }
    final add = random.nextBool();
    final a = carry ? _range(18, max - 18) : _range(1, max ~/ 2);
    final b = add ? _range(1, max - a) : _range(1, a);
    final answer = add ? a + b : a - b;
    return _choice(
      level,
      index,
      '$a ${add ? '+' : '-'} $b = ?',
      '$answer',
      _numberChoices(answer),
      add ? '可以先凑十，再继续数。' : '可以从$a往回数$b步。',
      '正确答案是 $answer。',
      false,
    );
  }

  Question _chain(LevelDefinition level, int index, bool isBoss) {
    final a = _range(15, 60);
    final b = _range(4, 20);
    final c = _range(3, 16);
    final subtract = random.nextBool();
    final answer = subtract ? max(0, a - b - c) : a + b + c;
    return _choice(
      level,
      index,
      subtract ? '$a - $b - $c = ?' : '$a + $b + $c = ?',
      '$answer',
      _numberChoices(answer),
      '一步一步算，每走一步点亮一盏灯。',
      subtract ? '$a - $b = ${a - b}，再减$c。' : '$a + $b = ${a + b}，再加$c。',
      isBoss,
    );
  }

  Question _shape(LevelDefinition level, int index, bool isBoss) {
    final shapes = [
      ['球', '圆圆的，没有平平的面'],
      ['正方体', '有6个一样大的正方形面'],
      ['长方体', '像纸盒，有长长方方的面'],
      ['圆柱', '上下是圆形，中间直直的'],
      ['三角形', '有3条边和3个角'],
      ['长方形', '有两条长边和两条短边'],
    ];
    final picked = shapes[(index + level.levelIndex) % shapes.length];
    return _choice(
      level,
      index,
      '图形广场的侦察员说：${picked[1]}。它是什么？',
      picked[0],
      shapes.map((s) => s[0]).toList()..shuffle(random),
      '想一想生活里的盒子、球、水杯和纸片。',
      '这个描述对应${picked[0]}。',
      isBoss,
    );
  }

  Question _time(LevelDefinition level, int index, bool isBoss) {
    final hour = _range(1, 12);
    final minute = level.levelIndex >= 5
        ? [5, 10, 20, 35, 45, 50][index % 6]
        : [0, 15, 30][index % 3];
    final label = minute == 0
        ? '$hour点'
        : minute == 30
        ? '$hour点半'
        : '$hour点$minute分';
    return _choice(
      level,
      index,
      '钟面上短针靠近$hour，长针指向${minute == 0 ? 12 : minute ~/ 5}，现在是？',
      label,
      [label, '$hour点${(minute + 15) % 60}分', '${hour % 12 + 1}点半', '$hour点一刻']
        ..shuffle(random),
      '长针走一大格是5分钟。',
      '这个钟面表示$label。',
      isBoss,
    );
  }

  Question _money(LevelDefinition level, int index, bool isBoss) {
    if (isBoss) {
      final pencil = _range(4, 8);
      final eraser = _range(3, 7);
      return _choice(
        level,
        index,
        '买一支铅笔$pencil角和一块橡皮$eraser角，一共要付多少角？',
        '${pencil + eraser}',
        _numberChoices(pencil + eraser),
        '购物题先把两个价钱合起来。',
        '$pencil角 + $eraser角 = ${pencil + eraser}角。',
        true,
      );
    }
    if (level.levelIndex == 1) {
      return _choice(
        level,
        index,
        '1元等于多少角？',
        '10角',
        ['10角', '1角', '100角', '10分'],
        '人民币单位从大到小可以换算。',
        '1元 = 10角。',
        isBoss,
      );
    }
    if (level.levelIndex == 2) {
      return _choice(
        level,
        index,
        '5角等于多少分？',
        '50分',
        ['5分', '10分', '50分', '500分'],
        '1角等于10分。',
        '5角 = 50分。',
        isBoss,
      );
    }
    if (level.levelIndex == 3) {
      final price = _range(4, 9);
      return _choice(
        level,
        index,
        '买一块橡皮$price角，付1元，应找回多少角？',
        '${10 - price}角',
        ['${10 - price}角', '${price - 1}角', '${price + 1}角', '${10 + price}角'],
        '先把1元换成10角。',
        '10角 - $price角 = ${10 - price}角。',
        isBoss,
      );
    }
    final yuan = _range(1, 5);
    final jiao = _range(1, 9);
    final answer = yuan * 10 + jiao;
    return _choice(
      level,
      index,
      '$yuan元$jiao角等于多少角？',
      '$answer角',
      _numberChoices(answer).map((value) => '$value角').toList(),
      '1元等于10角。',
      '$yuan元是${yuan * 10}角，再加$jiao角，一共$answer角。',
      isBoss,
    );
  }

  Question _pattern(LevelDefinition level, int index, bool isBoss) {
    if (index % 2 == 0) {
      final start = _range(1, 8);
      final step = _range(2, 6);
      final sequence = [for (var i = 0; i < 4; i++) start + i * step];
      final answer = start + 4 * step;
      return _choice(
        level,
        index,
        '找规律：${sequence.join('，')}，？',
        '$answer',
        _numberChoices(answer),
        '看看每次增加了多少。',
        '每次增加$step，所以下一个是$answer。',
        isBoss,
      );
    }
    return _choice(
      level,
      index,
      '找图形规律：红、蓝、蓝、红、蓝、蓝、？',
      '红',
      ['红', '蓝', '黄', '绿'],
      '这是一组“红蓝蓝”不断重复。',
      '红、蓝、蓝是一组，下一组从红开始。',
      isBoss,
    );
  }

  Question _multiply(
    LevelDefinition level,
    int index,
    int maxFactor,
    bool isBoss, {
    int minFactor = 2,
  }) {
    final a = minFactor >= 7
        ? switch (level.levelIndex) {
            1 => 7,
            2 => 8,
            3 => 9,
            _ => _range(7, maxFactor),
          }
        : switch (level.levelIndex) {
            1 => _range(2, 4),
            2 => 2,
            3 => _range(3, 4),
            4 => 5,
            5 => 6,
            _ => _range(minFactor, maxFactor),
          };
    final b = _range(2, 9);
    if (level.levelIndex == 1 && minFactor < 7 && !isBoss) {
      return _choice(
        level,
        index,
        '$b个盘子，每盘$a个苹果，一共有几个苹果？',
        '${a * b}',
        _numberChoices(a * b),
        '几个相同加数相加，可以用乘法表示。',
        '$a + $a + ... 加$b次，就是$a × $b = ${a * b}。',
        false,
      );
    }
    if (level.levelIndex == 4 && minFactor >= 7 && !isBoss) {
      final base = _range(2, 5);
      return _choice(
        level,
        index,
        '小鹿有$base朵花，小熊的花是小鹿的$a倍，小熊有几朵？',
        '${base * a}',
        _numberChoices(base * a),
        '求一个数的几倍，用乘法。',
        '$base × $a = ${base * a}。',
        false,
      );
    }
    if (isBoss) {
      final extra = _range(3, 9);
      final answer = a * b + extra;
      return _choice(
        level,
        index,
        '花园里有$b行花，每行$a朵，又新开了$extra朵，一共有多少朵？',
        '$answer',
        _numberChoices(answer),
        '先算$b行共有多少朵，再加新开的花。',
        '$a × $b + $extra = $answer。',
        true,
      );
    }
    if (index % 3 == 1) {
      return _choice(
        level,
        index,
        '__ × $b = ${a * b}，空里填几？',
        '$a',
        _numberChoices(a),
        '想一想哪句口诀的结果是${a * b}。',
        '$a × $b = ${a * b}。',
        false,
      );
    }
    return _choice(
      level,
      index,
      '$a × $b = ?',
      '${a * b}',
      _numberChoices(a * b),
      '可以背口诀，也可以把$a连加$b次。',
      '$a × $b = ${a * b}。',
      false,
    );
  }

  Question _divide(LevelDefinition level, int index, bool isBoss) {
    final divisor = switch (level.levelIndex) {
      1 => 7,
      2 => 8,
      3 => 9,
      _ => _range(2, 9),
    };
    final quotient = _range(2, 9);
    final total = divisor * quotient;
    if (isBoss) {
      return _choice(
        level,
        index,
        '$total颗糖平均分给$divisor个小朋友，每人几颗？',
        '$quotient',
        _numberChoices(quotient),
        '平均分就是用除法。',
        '$total ÷ $divisor = $quotient。',
        true,
      );
    }
    if (index % 3 == 1) {
      return _choice(
        level,
        index,
        '想口诀：${_cnNumber(divisor)}__${_cnNumber(total)}，$total ÷ $divisor = ?',
        '$quotient',
        _numberChoices(quotient),
        '被除数是口诀里的结果。',
        '$divisor × $quotient = $total，所以商是$quotient。',
        false,
      );
    }
    return _choice(
      level,
      index,
      '$total ÷ $divisor = ?',
      '$quotient',
      _numberChoices(quotient),
      '除法可以想乘法口诀。',
      '$divisor × $quotient = $total。',
      false,
    );
  }

  Question _mixed(LevelDefinition level, int index, bool isBoss) {
    if (index >= 4 && index <= 6) {
      final divisor = _range(3, 8);
      final quotient = _range(3, 8);
      final remainder = _range(1, divisor - 1);
      final total = divisor * quotient + remainder;
      return _choice(
        level,
        index,
        '$total ÷ $divisor = ? 余 ?',
        '$quotient余$remainder',
        [
          '$quotient余$remainder',
          '${quotient + 1}余$remainder',
          '$quotient余$divisor',
          '${quotient - 1}余${remainder + divisor}',
        ],
        '余数一定要比除数小。',
        '$divisor × $quotient = ${divisor * quotient}，还剩$remainder。',
        isBoss,
      );
    }
    final a = _range(2, 8);
    final b = _range(2, 9);
    final multiplyFirst = index % 2 == 0;
    final product = a * b;
    final c = multiplyFirst ? _range(6, 30) : _range(product + 1, product + 30);
    final answer = multiplyFirst ? a * b + c : c - a * b;
    return _choice(
      level,
      index,
      multiplyFirst ? '$a × $b + $c = ?' : '$c - $a × $b = ?',
      '$answer',
      _numberChoices(answer),
      '有乘除也有加减时，先算乘除。',
      multiplyFirst ? '$a × $b = ${a * b}，再加$c。' : '$a × $b = ${a * b}，再用$c减。',
      isBoss,
    );
  }

  Question _largeNumber(LevelDefinition level, int index, bool isBoss) {
    final n = _range(1000, 9999);
    if (isBoss || level.levelIndex == 5) {
      final rows = [
        ('0、3、5、8', '8530', ['8530', '8503', '8350', '3580']),
        ('0、1、6、9', '9610', ['9610', '9601', '9160', '6910']),
        ('0、2、4、7', '7420', ['7420', '7402', '7240', '4720']),
        ('1、3、6、6', '6631', ['6631', '6613', '6361', '3661']),
        ('2、5、8、9', '9852', ['9852', '9825', '9582', '8952']),
        ('0、4、4、7', '7440', ['7440', '7404', '7044', '4740']),
      ];
      final row = rows[index % rows.length];
      return _choice(
        level,
        index,
        '用${row.$1}组成最大的四位数是多少？',
        row.$2,
        row.$3,
        '最大的数要让最高位尽量大，0不能放在最高位。',
        '按从大到小排列数字，得到${row.$2}。',
        isBoss,
      );
    }
    if (level.levelIndex == 1) {
      final thousands = n ~/ 1000;
      final hundreds = n ~/ 100 % 10;
      final tens = n ~/ 10 % 10;
      final ones = n % 10;
      return _choice(
        level,
        index,
        '$n里面有几个千、几个百、几个十和几个一？',
        '$thousands个千$hundreds个百$tens个十$ones个一',
        [
          '$thousands个千$hundreds个百$tens个十$ones个一',
          '$hundreds个千$thousands个百$tens个十$ones个一',
          '$thousands个千$tens个百$hundreds个十$ones个一',
          '$thousands个千$hundreds个百$ones个十$tens个一',
        ],
        '每一位上的数字表示对应计数单位的个数。',
        '$n的千位是$thousands，百位是$hundreds，十位是$tens，个位是$ones。',
        isBoss,
      );
    }
    if (level.levelIndex == 2) {
      final rows = [
        ['五千零二十 写作多少？', '5020', '没有百，要用0占位。'],
        ['三千八百零六 写作多少？', '3806', '没有十，要在十位写0。'],
        ['七千零九 写作多少？', '7009', '百位和十位都要用0占位。'],
        ['四千零五十 写作多少？', '4050', '没有百，百位要写0。'],
        ['六千三百 写作多少？', '6300', '没有十和个，后两位写0。'],
        ['九千零八十 写作多少？', '9080', '百位是0，十位是8。'],
        ['二千零二 写作多少？', '2002', '百位和十位都是0，个位是2。'],
        ['一千二百零三 写作多少？', '1203', '十位没有数，要写0占位。'],
      ];
      final row = rows[index % rows.length];
      return _choice(
        level,
        index,
        row[0],
        row[1],
        [row[1], '5200', '5002', '7009', '3806', '4050', '6300', '2002']
          ..shuffle(random),
        '读写万以内数时，空着的数位要写0。',
        row[2],
        isBoss,
      );
    }
    if (level.levelIndex == 3 || index % 3 == 0) {
      final other = max(1000, min(9999, n + _range(-80, 80)));
      final answer = n > other
          ? '>'
          : n < other
          ? '<'
          : '=';
      return _choice(
        level,
        index,
        '$n 〇 $other，圆圈里填什么？',
        answer,
        ['>', '<', '='],
        '先比千位，再比百位。',
        '比较每一位后，符号是 $answer。',
        isBoss,
      );
    }
    if (level.levelIndex == 4 || index % 3 == 1) {
      final rounded = (n / 100).round() * 100;
      return _choice(
        level,
        index,
        '$n 约等于多少？',
        '$rounded',
        _numberChoices(rounded, spread: 300),
        '看十位，满5向百位进一。',
        '$n 约等于 $rounded。',
        isBoss,
      );
    }
    final hundreds = (n ~/ 100) * 100;
    final addend = _range(1, 8) * 100;
    return _choice(
      level,
      index,
      '$hundreds + $addend = ?',
      '${hundreds + addend}',
      _numberChoices(hundreds + addend, spread: 400),
      '整百数相加，先看百位。',
      '把百位加起来就能得到结果。',
      isBoss,
    );
  }

  Question _weight(LevelDefinition level, int index, bool isBoss) {
    final kg = _range(1, 6);
    if (index % 3 == 0) {
      return _choice(
        level,
        index,
        '$kg千克 = 多少克？',
        '${kg * 1000}',
        _numberChoices(kg * 1000, spread: 1000),
        '1千克等于1000克。',
        '$kg千克就是${kg * 1000}克。',
        isBoss,
      );
    }
    if (index % 3 == 1) {
      return _choice(
        level,
        index,
        '一个鸡蛋大约重多少？',
        '50克',
        ['50克', '5千克', '500千克', '1克'],
        '鸡蛋很轻，用克作单位。',
        '一个鸡蛋通常约50克。',
        isBoss,
      );
    }
    return _choice(
      level,
      index,
      '${kg * 1000}克 〇 $kg千克，填什么？',
      '=',
      ['>', '<', '='],
      '先把单位换成一样。',
      '${kg * 1000}克等于$kg千克。',
      isBoss,
    );
  }

  Question _logic(LevelDefinition level, int index, bool isBoss) {
    final prompts = [
      ['2件上衣和3条裤子，一共有几种搭配？', '6', '用乘法：2 × 3 = 6。'],
      ['小红拿的不是语文书，小明拿的是数学书，小刚拿什么书？', '语文书', '剩下的书给小刚。'],
      ['三人排队，小华不在第1个，小明在小华前面，小华第几？', '第2个', '小明在前，小华只能在第2个。'],
      ['红、黄、蓝三张卡片，每次取两张，有几种不同取法？', '3', '红黄、红蓝、黄蓝。'],
      ['按“红、黄、蓝”循环排列，第20个是什么颜色？', '黄', '20 ÷ 3 余2，所以是每组第2个黄。'],
      ['A不是医生，B不是教师，C不是警察；三人分别是教师、医生、警察。B最可能是什么？', '医生', '先排除B不是教师，再结合C不是警察。'],
      ['4×4数独某行已有1、2、3，空格应填几？', '4', '一行里1到4各出现一次。'],
    ];
    final row = prompts[(index + level.levelIndex) % prompts.length];
    return _choice(
      level,
      index,
      row[0],
      row[1],
      [row[1], '2', '3', '4', '语文书', '医生', '黄']..shuffle(random),
      '把条件一条一条划掉。',
      row[2],
      isBoss,
    );
  }

  Question _pinyin(LevelDefinition level, int index, bool isBoss) {
    final rows = switch (level.levelIndex) {
      1 => [
        ['a', '单韵母', 'a、o、e 都是单韵母。'],
        ['ō', '一声', '一声平平走。'],
        ['ǎ', '三声', '三声先降再升。'],
        ['ü', '单韵母', 'ü读音圆圆的。'],
      ],
      2 => [
        ['b', '声母', '菠萝的开头音是 b。'],
        ['p', '声母', 'p 发音时气流更明显。'],
        ['mā', '妈', 'm-ā 拼成 mā。'],
        ['fó', '佛', 'f-ó 拼成 fó。'],
      ],
      3 => [
        ['dǎ', '打', 'd-ǎ 拼成 dǎ。'],
        ['tǔ', '土', 't-ǔ 拼成 tǔ。'],
        ['nǚ', '女', 'n-ǚ 拼成 nǚ。'],
        ['hē', '喝', 'h-ē 拼成 hē。'],
      ],
      4 => [
        ['jī', '鸡', 'j-ī 拼成 jī。'],
        ['qí', '旗', 'q-í 拼成 qí。'],
        ['xī', '西', 'x-ī 拼成 xī。'],
        ['sì', '四', 's-ì 拼成 sì。'],
      ],
      5 => [
        ['zhi', '整体认读音节', 'zhi 不用拼，整体读。'],
        ['chi', '整体认读音节', 'chi 是整体认读音节。'],
        ['zi', '整体认读音节', 'zi、ci、si 整体读。'],
        ['yi', '整体认读音节', 'yi、wu、yu 常整体读。'],
      ],
      6 => [
        ['huā', '花', 'h-u-ā 三拼成 huā。'],
        ['guā', '瓜', 'g-u-ā 三拼成 guā。'],
        ['xiǎo', '小', 'x-i-ǎo 拼成 xiǎo。'],
        ['quán', '泉', 'q-u-án 拼成 quán。'],
      ],
      _ => [
        ['shuǐ', '水', '水的拼音是 shuǐ。'],
        ['rì', '日', '日的拼音是 rì。'],
        ['yuè', '月', '月的拼音是 yuè。'],
        ['tiān', '天', '天的拼音是 tiān。'],
      ],
    };
    final row = rows[(index + level.levelIndex - 1) % rows.length];
    final prompt = isBoss
        ? '看图想一想：“${row[1]}”的正确拼音是？'
        : '${row[0]} 属于哪一类或表示哪个字？';
    return _choice(
      level,
      index,
      prompt,
      row[1],
      [row[1], '韵母', '二声', '整体认读音节', '木']..shuffle(random),
      '轻声读一读，再看声调。',
      row[2],
      isBoss,
      subject: '语文',
    );
  }

  Question _hanzi(LevelDefinition level, int index, bool isBoss) {
    final rows = switch (level.chapterId) {
      'Y6' => [
        ['园', 'yuán', '《场景歌》里有花园、果园。'],
        ['桥', 'qiáo', '木字旁常和树木、木制品有关。'],
        ['杨', 'yáng', '杨树的“杨”是木字旁。'],
        ['熊', 'xióng', '熊和动物有关，下面四点像火。'],
        ['季', 'jì', '田家四季歌里的“季”。'],
        ['铜', 'tóng', '金字旁常和金属有关。'],
        ['戴', 'dài', '《拍手歌》里有“孔雀锦鸡是伙伴”。'],
        ['歌', 'gē', '唱歌的“歌”右边是欠字旁。'],
      ],
      _ => [
        ['天', 'tiān', '《天地人》里有“天”。'],
        ['地', 'dì', '《天地人》里有“地”。'],
        ['人', 'rén', '“人”字撇捺展开。'],
        ['木', 'mù', '《金木水火土》里的“木”。'],
        ['水', 'shuǐ', '水和三点水偏旁有关。'],
        ['火', 'huǒ', '火字先点后撇。'],
        ['口', 'kǒu', '口耳目手足里的“口”。'],
        ['日', 'rì', '日月水火里的“日”。'],
        ['云', 'yún', '《对韵歌》里“云对雨”。'],
        ['雨', 'yǔ', '《对韵歌》里“雪对风”。'],
      ],
    };
    final row = rows[(index + level.levelIndex - 1) % rows.length];
    if (index % 3 == 1) {
      return _choice(
        level,
        index,
        '“${row[0]}”的正确读音是？',
        row[1],
        [row[1], 'mù', 'rén', 'shuǐ']..shuffle(random),
        '先想课文里这个字怎么读。',
        row[2],
        isBoss,
        subject: '语文',
      );
    }
    final mate = _wordMate(row[0]);
    return _choice(
      level,
      index,
      '“${row[0]}”可以和哪个字组成常见词语？',
      mate,
      [
        mate,
        ...['果', '笔', '步', '花', '云', '草'].where((e) => e != mate),
      ]..shuffle(random),
      '把两个字连起来读一读，看看像不像生活里的常见词。',
      '“${row[0]}$mate”是常见词语。',
      isBoss,
      subject: '语文',
    );
  }

  Question _chineseWords(LevelDefinition level, int index, bool isBoss) {
    final rows = switch (level.chapterId) {
      'Y4' => [
        ['“春风、夏雨、秋霜、冬雪”都和什么有关？', '季节', '课文词语'],
        ['“你姓什么？我姓李。”这里练习的是？', '姓氏', '课文理解'],
        ['“青”加三点水，常和什么有关？', '水', '偏旁理解'],
        ['“一__鸟”中间填哪个量词更合适？', '只', '量词'],
        ['“小青蛙保护禾苗。”谁保护禾苗？', '小青蛙', '句子理解'],
        ['“蜻蜓半空展翅飞”里，谁在半空飞？', '蜻蜓', '动物儿歌'],
      ],
      _ => [
        ['“高兴”的近义词可以是？', '快乐', '近义词'],
        ['“仔细”的反义词可以是？', '马虎', '反义词'],
        ['“一__队旗”中间填哪个量词？', '面', '量词'],
        ['“碧绿的__”后面接哪个词最通顺？', '荷叶', '词语搭配'],
        ['“雪白雪白”这种词语形式是？', 'ABAB', '照样子写词'],
        ['“一边……一边……”表示什么？', '两个动作同时做', '句式仿写'],
        ['句子“多美的黄山奇石啊”应该用什么标点？', '！', '标点语气'],
      ],
    };
    final row = rows[(index + level.levelIndex - 1) % rows.length];
    return _choice(
      level,
      index,
      '${row[2]}练习：${row[0]}',
      row[1],
      [row[1], '铅笔', '昨天', '因为', '老师', '书包', '马虎', '！']..shuffle(random),
      '放进句子里读一读，最通顺的就是答案。',
      '${row[0]} 对应 ${row[1]}。',
      isBoss,
      subject: '语文',
    );
  }

  Question _reading(LevelDefinition level, int index, bool isBoss) {
    final rows = switch (level.chapterId) {
      'Y3' => [
        ['《秋天》里，“一片片叶子”说明叶子怎么样？', '很多', '抓住数量词“一片片”。'],
        ['“弯弯的月儿小小的船”，月儿像什么？', '小船', '课文把月儿比作小船。'],
        ['《江南》中，鱼儿在什么间游戏？', '莲叶间', '诗句里有“鱼戏莲叶间”。'],
        ['《四季》里，雪人大肚子一挺，他说自己是什么？', '冬天', '按课文内容回忆。'],
        ['《比尾巴》中，谁的尾巴弯？', '公鸡', '课文里说“公鸡的尾巴弯”。'],
        ['《青蛙写诗》中，小蝌蚪可以当什么标点？', '逗号', '小蝌蚪像逗号。'],
      ],
      'Y5' => [
        ['“吃水不忘挖井人”提醒我们要怎样？', '懂得感恩', '想一想题目中的“不忘”。'],
        ['《静夜思》的作者是谁？', '李白', '这首诗是李白写的。'],
        ['《端午粽》里，外婆包的粽子味道怎样？', '又黏又甜', '关注课文里的味道描写。'],
        ['《彩虹》中，“我”想在彩虹桥上做什么？', '荡秋千', '回忆小朋友的想象。'],
        ['《荷叶圆圆》里，小水珠把荷叶当作什么？', '摇篮', '小水珠躺在荷叶上。'],
        ['“床前明月光”出自哪首诗？', '静夜思', '这是李白的古诗。'],
      ],
      'Y8' => [
        ['小蝌蚪找妈妈，先长出什么？', '后腿', '故事有先后顺序。'],
        ['曹冲称象用了什么办法？', '借船和石头称重量', '抓住解决问题的方法。'],
        ['“白日依山尽”的下一句是？', '黄河入海流', '这是《登鹳雀楼》的诗句。'],
        ['黄山奇石为什么有趣？', '形状像不同东西', '看课文怎样描写石头。'],
        ['“坐井观天”告诉我们什么？', '眼界不能太小', '寓意藏在故事后面。'],
        ['寒号鸟不听劝告，结果怎样？', '冻死了', '看故事结局。'],
        ['“我要的是葫芦”里，葫芦为什么没长好？', '不治叶子上的蚜虫', '叶子和果实有关。'],
      ],
      _ => [
        ['“草长莺飞二月天”描写的是什么季节？', '春天', '二月、柳树、纸鸢都指向春天。'],
        ['《咏柳》中，把春风比作什么？', '剪刀', '诗句“不知细叶谁裁出”。'],
        ['雷锋叔叔常常帮助别人，可以用哪个词形容？', '乐于助人', '抓住人物品质。'],
        ['“千人糕”为什么叫千人糕？', '凝结了很多人的劳动', '联系制作过程理解。'],
        ['《亡羊补牢》告诉我们什么？', '出了问题及时补救', '寓言要读出道理。'],
        ['《揠苗助长》中的农夫错在哪里？', '太着急', '他违背禾苗生长规律。'],
        ['传统节日里，春节常做什么？', '贴春联', '联系节日习俗。'],
        ['蜘蛛开店总换招牌，说明做事要怎样？', '想周全再做', '读故事看原因。'],
      ],
    };
    final row = rows[(index + level.levelIndex - 1) % rows.length];
    return _choice(
      level,
      index,
      row[0],
      row[1],
      [row[1], '太阳', '小马', '书包', '铅笔', '昨天', '春天', '剪刀']..shuffle(random),
      '先读题干，再回到短文或诗句里找。',
      row[2],
      isBoss,
      subject: '语文',
    );
  }

  Question _word(LevelDefinition level, int index, bool isBoss) {
    final entries = switch (level.chapterId) {
      'E1' => [
        'hello|你好',
        'hi|嗨',
        'red|红色',
        'yellow|黄色',
        'blue|蓝色',
        'green|绿色',
      ],
      'E2' => [
        'one|一',
        'two|二',
        'three|三',
        'five|五',
        'ten|十',
        'book|书',
        'ruler|尺子',
        'pencil|铅笔',
        'eraser|橡皮',
        'bag|书包',
      ],
      'E3' => [
        'cat|猫',
        'dog|狗',
        'bird|鸟',
        'monkey|猴子',
        'tiger|老虎',
        'panda|熊猫',
        'apple|苹果',
        'pear|梨',
        'banana|香蕉',
        'orange|橙子',
      ],
      'E4' => [
        'room|房间',
        'door|门',
        'window|窗户',
        'bed|床',
        'desk|课桌',
        'chair|椅子',
        'rice|米饭',
        'milk|牛奶',
        'shirt|衬衫',
        'dress|连衣裙',
      ],
      'E5' => [
        'father|爸爸',
        'mother|妈妈',
        'grandfather|爷爷',
        'grandmother|奶奶',
        'brother|哥哥弟弟',
        'sister|姐姐妹妹',
        'friend|朋友',
        'boy|男孩',
        'girl|女孩',
        'tall|高的',
        'short|矮的',
      ],
      'E6' => [
        'school|学校',
        'park|公园',
        'hospital|医院',
        'bookstore|书店',
        'supermarket|超市',
        'restaurant|餐馆',
        'bus|公共汽车',
        'bike|自行车',
        'train|火车',
        'plane|飞机',
      ],
      'E7' => [
        'run|跑',
        'jump|跳',
        'swim|游泳',
        'play football|踢足球',
        'fly a kite|放风筝',
        'sunny|晴朗的',
        'rainy|下雨的',
        'cloudy|多云的',
        'windy|有风的',
        'spring|春天',
        'summer|夏天',
        'autumn|秋天',
        'winter|冬天',
      ],
      _ => [
        'apple|苹果',
        'banana|香蕉',
        'pear|梨',
        'orange|橙子',
        'pen|钢笔',
        'bag|书包',
        'hand|手',
        'foot|脚',
      ],
    };
    final pair = entries[(index + level.levelIndex) % entries.length].split(
      '|',
    );
    final answer = pair[0];
    final choices = [
      answer,
      ...entries
          .map((e) => e.split('|').first)
          .where((e) => e != answer)
          .take(5),
    ]..shuffle(random);
    return _choice(
      level,
      index,
      '请选择“${pair[1]}”的英文。',
      answer,
      choices,
      '可以先看含义，再慢慢读单词。',
      '${pair[1]} 的英文是 $answer。',
      isBoss,
      subject: '英语',
    );
  }

  Question _phonics(LevelDefinition level, int index, bool isBoss) {
    final rows = switch (level.levelIndex) {
      1 => [
        ['cat', 'c _ t', 'a'],
        ['bag', 'b _ g', 'a'],
        ['map', 'm _ p', 'a'],
        ['hat', 'h _ t', 'a'],
      ],
      2 => [
        ['pen', 'p _ n', 'e'],
        ['bed', 'b _ d', 'e'],
        ['leg', 'l _ g', 'e'],
        ['red', 'r _ d', 'e'],
      ],
      3 => [
        ['pig', 'p _ g', 'i'],
        ['sit', 's _ t', 'i'],
        ['fish', 'f _ sh', 'i'],
        ['ship', 'sh _ p', 'i'],
      ],
      _ => [
        ['dog', 'd _ g', 'o'],
        ['sun', 's _ n', 'u'],
        ['duck', 'd _ ck', 'u'],
        ['clock', 'cl _ ck', 'o'],
      ],
    };
    final row = rows[(index + level.levelIndex) % rows.length];
    final word = row[0];
    final shown = row[1];
    final missing = row[2];
    return _choice(
      level,
      index,
      '拼读小积木：$shown，中间应该放哪个字母？',
      missing,
      ['a', 'e', 'i', 'o', 'k', 't']..shuffle(random),
      '慢慢读开头和结尾，中间的声音会跳出来。',
      '$word 里缺少的字母是 $missing。',
      isBoss,
      subject: '英语',
    );
  }

  Question _dialogue(LevelDefinition level, int index, bool isBoss) {
    final prompts = switch (level.chapterId) {
      'E1' => [
        ['新朋友见面，应该先说：', 'Hello!', 'Good night.', 'Thank you.', 'Sit down.'],
        ['想介绍自己是Tom，可以说：', "I'm Tom.", "You're Tom.", "He's Tom.", 'Bye, Tom.'],
        ['别人说“Hi!”时，最合适的回应是：', 'Hi!', 'Goodbye.', 'Blue.', 'Dog.'],
        [
          '老师问“What colour is it?”，它是红色，回答：',
          "It's red.",
          "It's a book.",
          "I'm red.",
          'Ten.',
        ],
        ['看到蓝色天空，选择正确表达：', 'blue sky', 'red sky', 'green apple', 'yellow cat'],
        ['彩虹里“红、橙、黄、绿、蓝”，blue表示哪种颜色？', '蓝色', '红色', '黄色', '绿色'],
      ],
      'E4' => [
        [
          '朋友问：What is in your room? 你想说有一张床。',
          'There is a bed.',
          'I am a bed.',
          'It is sunny.',
          'Good night.',
        ],
        [
          '老师问：What do you want? 你想要牛奶。',
          'I want milk.',
          'I am fine.',
          'It is a dog.',
          'This is Dad.',
        ],
        ['图中猫在床上，The cat is ___ the bed.', 'on', 'under', 'in', 'next to'],
        [
          '妈妈问：What are you wearing? 你穿着T-shirt。',
          "I'm wearing a T-shirt.",
          'I want water.',
          'It is a tiger.',
          'This is my room.',
        ],
      ],
      'E7' => [
        [
          '朋友问：What are you doing? 你正在踢足球。',
          "I'm playing football.",
          'It is cold.',
          'I am seven.',
          'This is Dad.',
        ],
        [
          '老师问：What is the weather like? 今天下雨。',
          "It's rainy.",
          'I want rice.',
          'It is a bus.',
          'Goodbye.',
        ],
        [
          '朋友问：Which season do you like? 你喜欢春天。',
          'I like spring.',
          'It is a desk.',
          "I'm Tom.",
          'Show me your ruler.',
        ],
        [
          '妈妈问：What time is it? 现在7点。',
          "It's seven o'clock.",
          'I am seven.',
          'It is sunny.',
          'This is my friend.',
        ],
      ],
      _ => [
        ['小熊说：Hello!', 'Hello!', 'Thank you.', 'Goodbye.', 'Red.'],
        [
          '朋友说：Nice to meet you!',
          'Nice to meet you, too!',
          'I am six.',
          'Blue.',
          'Dog.',
        ],
        [
          '老师说：What color is it? 这是一颗红苹果。',
          'Red.',
          'Dog.',
          'Goodbye.',
          'I am fine.',
        ],
        [
          '同学问：How old are you?',
          'I am seven.',
          'It is green.',
          'This is my father.',
          'Stand up.',
        ],
      ],
    };
    final row = prompts[index % prompts.length];
    return _choice(
      level,
      index,
      row[0],
      row[1],
      row.sublist(1)..shuffle(random),
      '先想一想对方在问什么。',
      '这个场景里应该回答：${row[1]}',
      isBoss,
      subject: '英语',
    );
  }

  Question _choice(
    LevelDefinition level,
    int index,
    String prompt,
    String answer,
    List<String> choices,
    String hint,
    String explanation,
    bool isBoss, {
    String? subject,
  }) {
    final unique = <String>{answer, ...choices}.toList();
    while (unique.length < 4) {
      unique.add('${_range(1, 99)}');
    }
    unique.shuffle(random);
    final picked = unique.take(4).toList();
    if (!picked.contains(answer)) {
      picked[0] = answer;
      picked.shuffle(random);
    }
    return Question(
      id: '${level.id}-$index-${level.levelIndex}',
      subject: subject ?? _subjectName(level.island),
      knowledgePoint: level.knowledgePoint,
      questionType: level.questionType,
      prompt: prompt,
      answer: answer,
      choices: picked,
      hint: hint,
      explanation: explanation,
      variantSeed: level.levelIndex + index,
      isBoss: isBoss,
    );
  }

  String _questionKey(Question question) {
    return question.prompt.replaceAll(RegExp(r'\s+'), '');
  }

  Question _withBossFlag(Question question, bool isBoss) {
    if (question.isBoss == isBoss) return question;
    return Question(
      id: question.id,
      subject: question.subject,
      knowledgePoint: question.knowledgePoint,
      questionType: question.questionType,
      prompt: question.prompt,
      answer: question.answer,
      choices: question.choices,
      hint: question.hint,
      explanation: question.explanation,
      inputMode: question.inputMode,
      variantSeed: question.variantSeed,
      isBoss: isBoss,
    );
  }

  List<String> _numberChoices(int answer, {int spread = 9}) {
    final values = <int>{answer};
    while (values.length < 4) {
      values.add(max(0, answer + _range(-spread, spread)));
    }
    return values.map((value) => '$value').toList()..shuffle(random);
  }

  int _range(int min, int max) {
    if (max <= min) return min;
    return min + random.nextInt(max - min + 1);
  }

  String _subjectName(Island island) {
    return switch (island) {
      Island.chinese => '语文',
      Island.english => '英语',
      Island.sudoku => '数独',
      Island.math => '数学',
    };
  }

  String _kindFromWrong(WrongItem item) {
    final q = item.originalQuestion;
    if (q.subject == '语文') {
      if (item.questionType == 'pinyin') return 'pinyin';
      if (item.questionType == 'stroke') return 'hanzi';
      if (item.questionType == 'reading') return 'reading';
      return 'words_cn';
    }
    if (q.subject == '英语') {
      if (item.questionType == 'phonics') return 'phonics';
      if (item.questionType == 'dialogue') return 'dialogue';
      return 'word';
    }
    if (item.knowledgePoint.contains('乘')) return 'multiply_high';
    if (item.knowledgePoint.contains('除')) return 'divide';
    if (item.knowledgePoint.contains('重量')) return 'weight';
    if (item.knowledgePoint.contains('万')) return 'large_number';
    if (item.knowledgePoint.contains('推理')) return 'logic';
    if (item.knowledgePoint.contains('时间')) return 'time';
    if (item.knowledgePoint.contains('人民币')) return 'money';
    if (item.knowledgePoint.contains('规律')) return 'pattern';
    if (item.knowledgePoint.contains('图形')) return 'shape';
    if (item.knowledgePoint.contains('连')) return 'chain';
    if (item.knowledgePoint.contains('进位')) return 'carry';
    return 'add_sub';
  }

  String _wordMate(String word) {
    return switch (word) {
      '天' => '空',
      '地' => '上',
      '人' => '们',
      '木' => '头',
      '水' => '果',
      '火' => '山',
      '口' => '水',
      '日' => '月',
      '云' => '朵',
      '雨' => '伞',
      '园' => '林',
      '桥' => '洞',
      '杨' => '树',
      '熊' => '猫',
      '季' => '节',
      '铜' => '号',
      '戴' => '帽',
      '歌' => '声',
      _ => '语',
    };
  }

  String _cnNumber(int value) {
    const names = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
    return value >= 0 && value < names.length ? names[value] : '$value';
  }
}
