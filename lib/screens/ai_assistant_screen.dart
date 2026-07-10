import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../models/app_models.dart';
import '../services/ai_service.dart';
import '../services/app_store.dart';
import '../widgets/ui_components.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final aiService = AiService();
  final chatController = TextEditingController();
  final questionController = TextEditingController();
  final studentAnswerController = TextEditingController();
  final correctAnswerController = TextEditingController();
  final knowledgeController = TextEditingController();
  final messages = <_ChatBubble>[
    const _ChatBubble(role: _ChatRole.assistant, text: '你好，我可以帮你讲题、整理思路。'),
  ];

  bool chatLoading = false;
  bool explainLoading = false;
  String? conversationId;
  String explainResult = '';

  String get gradeLabel => gradeName(normalizeGradeCode(widget.store.progress.selectedGrade));

  @override
  void dispose() {
    aiService.close();
    chatController.dispose();
    questionController.dispose();
    studentAnswerController.dispose();
    correctAnswerController.dispose();
    knowledgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExplorerScaffold(
      title: 'AI 助手',
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              labelColor: Color(0xFF7C3F1D),
              indicatorColor: Color(0xFFFF8C42),
              tabs: [
                Tab(icon: Icon(Icons.chat_bubble_outline), text: 'AI问答'),
                Tab(icon: Icon(Icons.psychology_alt), text: '错题讲解'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildChatTab(),
                  _buildExplainTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Expanded(
            child: SoftCard(
              color: const Color(0xFFFFFBEB),
              child: ListView.separated(
                itemCount: messages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isUser = message.role == _ChatRole.user;
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isUser
                              ? const Color(0xFFFFE0B2)
                              : const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE6C8A2)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            message.text,
                            style: const TextStyle(
                              fontSize: 18,
                              height: 1.45,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3F2A18),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: chatController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '输入想问的问题',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: chatLoading ? null : _sendChat,
                icon: chatLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('发送'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExplainTab() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: SoftCard(
              color: const Color(0xFFFFF8E1),
              child: ListView(
                children: [
                  _labeledField('题目', questionController, maxLines: 5),
                  const SizedBox(height: 10),
                  _labeledField('孩子答案', studentAnswerController, maxLines: 2),
                  const SizedBox(height: 10),
                  _labeledField('参考答案', correctAnswerController, maxLines: 2),
                  const SizedBox(height: 10),
                  _labeledField('知识点', knowledgeController, maxLines: 1),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: explainLoading ? null : _explainWrongItem,
                    icon: explainLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: const Text('生成讲解'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SoftCard(
              color: Colors.white,
              child: SingleChildScrollView(
                child: Text(
                  explainResult.isEmpty
                      ? '讲解会显示在这里。'
                      : explainResult,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3F2A18),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labeledField(
    String label,
    TextEditingController controller, {
    required int maxLines,
  }) {
    return TextField(
      controller: controller,
      minLines: maxLines == 1 ? 1 : 2,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _sendChat() async {
    final text = chatController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add(_ChatBubble(role: _ChatRole.user, text: text));
      chatController.clear();
      chatLoading = true;
    });
    try {
      final result = await aiService.chat(
        message: text,
        gradeLabel: gradeLabel,
        conversationId: conversationId,
      );
      setState(() {
        conversationId = result.conversationId;
        messages.add(_ChatBubble(role: _ChatRole.assistant, text: result.answer));
      });
    } on AiServiceException catch (error) {
      setState(() {
        messages.add(
          _ChatBubble(
            role: _ChatRole.assistant,
            text: _friendlyError(error),
          ),
        );
      });
    } finally {
      if (mounted) setState(() => chatLoading = false);
    }
  }

  Future<void> _explainWrongItem() async {
    final question = questionController.text.trim();
    if (question.isEmpty) {
      setState(() => explainResult = '请先输入题目。');
      return;
    }
    setState(() {
      explainLoading = true;
      explainResult = '正在生成讲解...';
    });
    try {
      final result = await aiService.explainWrongItem(
        subject: '综合',
        question: question,
        studentAnswer: studentAnswerController.text.trim(),
        correctAnswer: correctAnswerController.text.trim(),
        knowledgePoint: knowledgeController.text.trim(),
        gradeLabel: gradeLabel,
      );
      setState(() => explainResult = result.explanation);
    } on AiServiceException catch (error) {
      setState(() => explainResult = _friendlyError(error));
    } finally {
      if (mounted) setState(() => explainLoading = false);
    }
  }

  String _friendlyError(AiServiceException error) {
    if (error.statusCode == 503) {
      return 'AI 服务还没有配置 DeepSeek API Key。配置完成后这里就可以正常使用。';
    }
    return error.message;
  }
}

enum _ChatRole { user, assistant }

class _ChatBubble {
  const _ChatBubble({required this.role, required this.text});

  final _ChatRole role;
  final String text;
}
