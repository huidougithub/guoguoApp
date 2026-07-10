import 'dart:convert';
import 'dart:io';

const String defaultAiApiBaseUrl = 'http://8.163.115.183';

class AiServiceException implements Exception {
  const AiServiceException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AiChatResult {
  const AiChatResult({
    required this.conversationId,
    required this.answer,
    required this.model,
  });

  final String conversationId;
  final String answer;
  final String model;
}

class AiWrongExplainResult {
  const AiWrongExplainResult({
    required this.explanation,
    required this.model,
    this.wrongItemId,
  });

  final String explanation;
  final String model;
  final int? wrongItemId;
}

class AiService {
  AiService({String baseUrl = defaultAiApiBaseUrl, HttpClient? httpClient})
    : baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl,
      httpClient = httpClient ?? HttpClient();

  final String baseUrl;
  final HttpClient httpClient;

  Future<AiChatResult> chat({
    required String message,
    String? gradeLabel,
    String? conversationId,
  }) async {
    final payload = <String, Object?>{
      'message': message,
      'grade_label': gradeLabel,
      'conversation_id': conversationId,
    };
    final json = await _postJson('/api/v1/ai/chat', payload);
    return AiChatResult(
      conversationId: json['conversation_id'] as String,
      answer: json['answer'] as String,
      model: json['model'] as String,
    );
  }

  Future<AiWrongExplainResult> explainWrongItem({
    required String subject,
    required String question,
    String? studentAnswer,
    String? correctAnswer,
    String? knowledgePoint,
    String? gradeLabel,
  }) async {
    final payload = <String, Object?>{
      'subject': subject,
      'question': question,
      'student_answer': studentAnswer,
      'correct_answer': correctAnswer,
      'knowledge_point': knowledgePoint,
      'grade_label': gradeLabel,
    };
    final json = await _postJson('/api/v1/ai/wrong-item/explain', payload);
    return AiWrongExplainResult(
      explanation: json['explanation'] as String,
      model: json['model'] as String,
      wrongItemId: json['wrong_item_id'] as int?,
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> payload,
  ) async {
    final request = await httpClient.postUrl(Uri.parse('$baseUrl$path'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload));
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    final decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail'] : null;
      final message = detail is String
          ? detail
          : 'AI 服务请求失败（${response.statusCode}）';
      throw AiServiceException(message, statusCode: response.statusCode);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AiServiceException('AI 服务返回格式不正确');
    }
    return decoded;
  }

  void close() {
    httpClient.close(force: true);
  }
}
