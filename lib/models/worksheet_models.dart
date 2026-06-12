import 'dart:convert';

class WorksheetCatalogItem {
  const WorksheetCatalogItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.grade,
    required this.description,
    required this.asset,
  });

  final String id;
  final String title;
  final String subject;
  final String grade;
  final String description;
  final String asset;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subject': subject,
    'grade': grade,
    'description': description,
    'asset': asset,
  };

  factory WorksheetCatalogItem.fromJson(Map<String, dynamic> json) {
    return WorksheetCatalogItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      grade: json['grade'] as String? ?? '',
      description: json['description'] as String? ?? '',
      asset: json['asset'] as String? ?? '',
    );
  }
}

class WorksheetSet {
  const WorksheetSet({
    required this.id,
    required this.title,
    required this.subject,
    required this.days,
  });

  final String id;
  final String title;
  final String subject;
  final List<WorksheetDay> days;

  int get questionCount =>
      days.fold(0, (total, day) => total + day.practiceQuestionCount);

  int get autoQuestionCount =>
      days.fold(0, (total, day) => total + day.autoQuestionCount);

  factory WorksheetSet.fromJson(Map<String, dynamic> json) {
    return WorksheetSet(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      days: (json['days'] as List<dynamic>? ?? const [])
          .map((item) => WorksheetDay.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WorksheetDay {
  const WorksheetDay({
    required this.day,
    required this.title,
    required this.questions,
  });

  final int day;
  final String title;
  final List<WorksheetQuestion> questions;

  int get practiceQuestionCount =>
      questions.where((question) => question.countsForProgress).length;

  int get autoQuestionCount =>
      questions.where((question) => question.canAutoCheck).length;

  factory WorksheetDay.fromJson(Map<String, dynamic> json) {
    return WorksheetDay(
      day: json['day'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      questions: (json['questions'] as List<dynamic>? ?? const [])
          .map(
            (item) => WorksheetQuestion.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class WorksheetQuestion {
  const WorksheetQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    required this.answers,
    required this.answerSource,
    this.sectionTitle = '',
    this.images = const [],
    this.leftItems = const [],
    this.rightItems = const [],
  });

  final String id;
  final String type;
  final String prompt;
  final List<String> answers;
  final String answerSource;
  final String sectionTitle;
  final List<String> images;
  final List<String> leftItems;
  final List<String> rightItems;

  bool get isDisplayOnly {
    final normalizedType = type.trim().toLowerCase();
    final normalizedSource = answerSource.trim().toLowerCase();
    return normalizedType == 'example' ||
        normalizedType == 'display_only' ||
        normalizedSource == 'display_only';
  }

  bool get countsForProgress => !isDisplayOnly;
  bool get canAutoCheck =>
      countsForProgress && answers.isNotEmpty;
  bool get needsManualAnswer => countsForProgress && !canAutoCheck;

  bool get hasBlankMarkers => prompt.contains('/r');

  bool get isMatch => leftItems.isNotEmpty && rightItems.isNotEmpty;

  int get blankCount => '/r'.allMatches(prompt).length;

  String blankAnswerKey(int blankIndex) => '${id}_blank_$blankIndex';

  String? correctAnswerForBlank(int blankIndex) {
    if (blankIndex < 0 || blankIndex >= answers.length) return null;
    return answers[blankIndex];
  }

  bool hasAnyBlankAnswer(Map<String, String> userAnswers) {
    if (isMatch) {
      return (userAnswers[id] ?? '').trim().isNotEmpty;
    }
    if (hasBlankMarkers) {
      for (var i = 0; i < blankCount; i++) {
        if ((userAnswers[blankAnswerKey(i)] ?? '').trim().isNotEmpty) return true;
      }
      return false;
    }
    return (userAnswers[id] ?? '').trim().isNotEmpty;
  }

  bool allBlanksAnswered(Map<String, String> userAnswers) {
    if (isMatch) {
      final raw = userAnswers[id] ?? '';
      if (raw.isEmpty) return false;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return map.length == leftItems.length;
      } catch (_) {
        return false;
      }
    }
    if (hasBlankMarkers) {
      for (var i = 0; i < blankCount; i++) {
        if ((userAnswers[blankAnswerKey(i)] ?? '').trim().isEmpty) return false;
      }
      return true;
    }
    return (userAnswers[id] ?? '').trim().isNotEmpty;
  }

  factory WorksheetQuestion.fromJson(Map<String, dynamic> json) {
    return WorksheetQuestion(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      answers: (json['answers'] as List<dynamic>? ?? const [])
          .map((item) => item?.toString() ?? '')
          .toList(),
      answerSource: json['answerSource'] as String? ?? 'manual_required',
      sectionTitle: json['sectionTitle'] as String? ?? '',
      images: (json['images'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      leftItems: (json['left'] as List<dynamic>? ?? const [])
          .map((item) => item?.toString() ?? '')
          .toList(),
      rightItems: (json['right'] as List<dynamic>? ?? const [])
          .map((item) => item?.toString() ?? '')
          .toList(),
    );
  }
}

class WorksheetProgress {
  WorksheetProgress({
    Map<String, String>? answers,
    Set<String>? checkedQuestionIds,
    Set<String>? correctQuestionIds,
  }) : answers = answers ?? {},
       checkedQuestionIds = checkedQuestionIds ?? {},
       correctQuestionIds = correctQuestionIds ?? {};

  final Map<String, String> answers;
  final Set<String> checkedQuestionIds;
  final Set<String> correctQuestionIds;

  int correctCountFor(Iterable<WorksheetQuestion> questions) {
    return questions
        .where(
          (question) =>
              question.countsForProgress &&
              correctQuestionIds.contains(question.id),
        )
        .length;
  }

  int answeredCountFor(Iterable<WorksheetQuestion> questions) {
    return questions
        .where(
          (question) =>
              question.countsForProgress &&
              question.hasAnyBlankAnswer(answers),
        )
        .length;
  }

  bool? checkedResultFor(String questionId) {
    if (!checkedQuestionIds.contains(questionId)) return null;
    return correctQuestionIds.contains(questionId);
  }

  Map<String, dynamic> toJson() => {
    'answers': answers,
    'checkedQuestionIds': checkedQuestionIds.toList(),
    'correctQuestionIds': correctQuestionIds.toList(),
  };

  factory WorksheetProgress.fromJson(Map<String, dynamic> json) {
    return WorksheetProgress(
      answers: (json['answers'] as Map<dynamic, dynamic>? ?? const {}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      checkedQuestionIds:
          (json['checkedQuestionIds'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toSet(),
      correctQuestionIds:
          (json['correctQuestionIds'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toSet(),
    );
  }
}
