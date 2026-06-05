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
    required this.answer,
    required this.answerSource,
    this.sectionTitle = '',
    this.displayPrompt = '',
    this.images = const [],
  });

  final String id;
  final String type;
  final String prompt;
  final String? answer;
  final String answerSource;
  final String sectionTitle;
  final String displayPrompt;
  final List<String> images;

  String get visiblePrompt =>
      displayPrompt.trim().isEmpty ? prompt : displayPrompt.trim();

  bool get isDisplayOnly {
    final normalizedType = type.trim().toLowerCase();
    final normalizedSource = answerSource.trim().toLowerCase();
    return normalizedType == 'example' ||
        normalizedType == 'display_only' ||
        normalizedSource == 'display_only';
  }

  bool get countsForProgress => !isDisplayOnly;
  bool get canAutoCheck =>
      countsForProgress && answer != null && answer!.isNotEmpty;
  bool get needsManualAnswer => countsForProgress && !canAutoCheck;

  factory WorksheetQuestion.fromJson(Map<String, dynamic> json) {
    return WorksheetQuestion(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      answer: json['answer'] as String?,
      answerSource: json['answerSource'] as String? ?? 'manual_required',
      sectionTitle: json['sectionTitle'] as String? ?? '',
      displayPrompt: json['displayPrompt'] as String? ?? '',
      images: (json['images'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
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
              (answers[question.id] ?? '').trim().isNotEmpty,
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
