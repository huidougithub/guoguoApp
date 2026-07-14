import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_data.dart';
import '../models/app_models.dart';
import '../services/ai_service.dart';
import '../services/app_store.dart';
import '../services/audio_service.dart';
import '../widgets/app_update_prompt.dart';
import '../widgets/ui_components.dart';
import 'leisure_playground_screen.dart';
import 'map_screen.dart';
import 'self_challenge_screen.dart';
import 'shop_screen.dart';
import 'stats_settings_screen.dart';
import 'study_materials_screen.dart';
import 'worksheet_library_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static bool playedLaunchPetVoice = false;
  static bool checkedUpdatesThisRun = false;
  static const voiceChannel = MethodChannel('guoguo_forward/voice');

  final aiService = AiService();
  final aiInputController = TextEditingController();
  final aiMessages = <_HomeAiMessage>[
    const _HomeAiMessage(isUser: false, text: '嗨！我是果果。今天想练什么？可以问我题目、知识点或学习方法。'),
  ];

  bool aiSending = false;
  bool voiceListening = false;
  bool aiExpanded = false;
  String? homeConversationId;

  @override
  void initState() {
    super.initState();
    voiceChannel.setMethodCallHandler(_handleVoiceCall);
    if (widget.store.progress.settings['music'] ?? false) {
      AudioService.playBgm(AppMusicScene.home);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_playLaunchPetVoice());
      unawaited(_checkUpdatesOnce());
    });
  }

  @override
  void dispose() {
    voiceChannel.setMethodCallHandler(null);
    aiInputController.dispose();
    aiService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.store.progress;
    final pet = petById(progress.selectedPet);
    return ExplorerScaffold(
      title: '',
      showAppBar: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _HomeTopBar(
              progress: progress,
              onShop: () => _openSceneScreen(
                AppMusicScene.shop,
                ShopScreen(store: widget.store),
              ),
              onSettings: _openSettings,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: aiExpanded
                  ? _HomeAiPanel(
                      pet: pet,
                      messages: aiMessages,
                      controller: aiInputController,
                      sending: aiSending,
                      voiceListening: voiceListening,
                      expanded: true,
                      onExpand: () => setState(() => aiExpanded = false),
                      onSend: _sendHomeAiMessage,
                      onVoice: _toggleVoiceInput,
                      onSpeak: _speakAiReply,
                      onShortcut: _sendShortcutMessage,
                    )
                  : Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: _HomeAiPanel(
                            pet: pet,
                            messages: aiMessages,
                            controller: aiInputController,
                            sending: aiSending,
                            voiceListening: voiceListening,
                            expanded: false,
                            onExpand: () => setState(() => aiExpanded = true),
                            onSend: _sendHomeAiMessage,
                            onVoice: _toggleVoiceInput,
                            onSpeak: _speakAiReply,
                            onShortcut: _sendShortcutMessage,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 8,
                          child: _HomeModuleGrid(
                            onOpenIsland: _openIsland,
                            onOpenSelfChallenge: () => _openSceneScreen(
                              AppMusicScene.selfChallenge,
                              SelfChallengeScreen(store: widget.store),
                            ),
                            onOpenWorksheet: () => _openSceneScreen(
                              AppMusicScene.home,
                              WorksheetLibraryScreen(store: widget.store),
                            ),
                            onOpenStudyMaterials: () => _openSceneScreen(
                              AppMusicScene.home,
                              const StudyMaterialsScreen(),
                            ),
                            onOpenLeisure: () => _openSceneScreen(
                              AppMusicScene.home,
                              LeisurePlaygroundScreen(store: widget.store),
                            ),
                            onLockedIsland: _showLockedIsland,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playLaunchPetVoice() async {
    if (!mounted || playedLaunchPetVoice) return;
    playedLaunchPetVoice = true;
    await AudioService.playSfx(
      AppSound.petCute,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
  }

  Future<void> _checkUpdatesOnce() async {
    if (!mounted || checkedUpdatesThisRun) return;
    checkedUpdatesThisRun = true;
    await checkForAppUpdate(context);
  }

  Future<void> _sendShortcutMessage(String text) async {
    aiInputController.text = text;
    await _sendHomeAiMessage();
  }

  Future<void> _handleVoiceCall(MethodCall call) async {
    if (call.method != 'speechEvent' || !mounted) return;
    final args = call.arguments is Map
        ? Map<String, dynamic>.from(call.arguments as Map)
        : <String, dynamic>{};
    final state = args['state']?.toString() ?? 'idle';
    final text = args['text']?.toString();
    setState(() {
      voiceListening = const {
        'starting',
        'listening',
        'speaking',
        'processing',
      }.contains(state);
      if (text != null && text.trim().isNotEmpty) {
        aiInputController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    });
    if (state == 'error' && text != null && text.isNotEmpty) {
      _showVoiceMessage(text);
    }
  }

  Future<void> _toggleVoiceInput() async {
    try {
      if (voiceListening) {
        await voiceChannel.invokeMethod<void>('stopListening');
      } else {
        await voiceChannel.invokeMethod<void>('startListening');
      }
    } on PlatformException catch (error) {
      if (mounted) _showVoiceMessage(error.message ?? '语音功能暂时不可用。');
    }
  }

  Future<void> _speakAiReply(String text) async {
    try {
      await voiceChannel.invokeMethod<void>('speakChinese', text);
    } on PlatformException catch (error) {
      if (mounted) _showVoiceMessage(error.message ?? '语音播放暂时不可用。');
    }
  }

  void _showVoiceMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendHomeAiMessage() async {
    final text = aiInputController.text.trim();
    if (text.isEmpty || aiSending) return;
    setState(() {
      aiInputController.clear();
      aiSending = true;
      aiMessages.add(_HomeAiMessage(isUser: true, text: text));
      if (aiMessages.length > 8) {
        aiMessages.removeRange(0, aiMessages.length - 8);
      }
    });
    try {
      final result = await aiService.chat(
        message: text,
        gradeLabel: gradeName(
          normalizeGradeCode(widget.store.progress.selectedGrade),
        ),
        conversationId: homeConversationId,
      );
      if (!mounted) return;
      setState(() {
        homeConversationId = result.conversationId;
        aiMessages.add(_HomeAiMessage(isUser: false, text: result.answer));
        if (aiMessages.length > 8) {
          aiMessages.removeRange(0, aiMessages.length - 8);
        }
      });
    } on AiServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        aiMessages.add(
          _HomeAiMessage(
            isUser: false,
            text: error.statusCode == 503
                ? 'AI 服务还没有配置好，等设置完成后果果就能回答啦。'
                : '果果暂时没连上：${error.message}',
          ),
        );
      });
    } finally {
      if (mounted) setState(() => aiSending = false);
    }
  }

  Future<void> _openIsland(Island island) async {
    _clearHomeInputFocus();
    if (widget.store.progress.settings['music'] ?? false) {
      final scene = switch (island) {
        Island.math => AppMusicScene.math,
        Island.chinese => AppMusicScene.chinese,
        Island.english => AppMusicScene.english,
        Island.sudoku => AppMusicScene.sudoku,
      };
      AudioService.playBgm(scene);
    }
    await pushScreen(context, MapScreen(store: widget.store, island: island));
    if (!mounted) return;
    _clearHomeInputFocus();
    if (widget.store.progress.settings['music'] ?? false) {
      AudioService.playBgm(AppMusicScene.home);
    }
  }

  Future<void> _openSceneScreen(AppMusicScene scene, Widget screen) async {
    _clearHomeInputFocus();
    if (widget.store.progress.settings['music'] ?? false) {
      AudioService.playBgm(scene);
    }
    await pushScreen(context, screen);
    if (!mounted) return;
    _clearHomeInputFocus();
    if (widget.store.progress.settings['music'] ?? false) {
      AudioService.playBgm(AppMusicScene.home);
    }
  }

  Future<void> _openSettings() async {
    _clearHomeInputFocus();
    await pushScreen(context, StatsSettingsScreen(store: widget.store));
    if (!mounted) return;
    _clearHomeInputFocus();
  }

  void _clearHomeInputFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  void _showLockedIsland(String name) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name 暂未开放，完善后再开启。')));
  }
}

class _HomeAiMessage {
  const _HomeAiMessage({required this.isUser, required this.text});

  final bool isUser;
  final String text;
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.progress,
    required this.onShop,
    required this.onSettings,
  });

  final AppProgress progress;
  final VoidCallback onShop;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        image: const DecorationImage(
          image: AssetImage('assets/home/resources/home_top_toolbar.png'),
          fit: BoxFit.cover,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F2D2A32),
            offset: Offset(0, 5),
            blurRadius: 14,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ResourceBadge(
                    symbol: '🍊',
                    label: '能量果',
                    value: '${progress.energyFruit}',
                    color: const Color(0xFFFF8C1A),
                  ),
                  const SizedBox(width: 12),
                  _ResourceBadge(
                    symbol: '⭐',
                    label: '星星',
                    value: '${progress.totalStars}',
                    color: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 12),
                  _ResourceBadge(
                    symbol: '🏅',
                    label: '勋章',
                    value: '${progress.badges.length}',
                    color: const Color(0xFFF97316),
                  ),
                  const SizedBox(width: 12),
                  _ResourceBadge(
                    symbol: '💎',
                    label: '钻石',
                    value: '${progress.diamonds}',
                    color: const Color(0xFF38BDF8),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _TopActionButton(
            icon: Icons.storefront,
            label: '魔法商店',
            color: const Color(0xFFFF8C42),
            onPressed: onShop,
          ),
          const SizedBox(width: 8),
          _IconOnlyTopButton(icon: Icons.settings, onPressed: onSettings),
        ],
      ),
    );
  }
}

class _ResourceBadge extends StatelessWidget {
  const _ResourceBadge({
    required this.symbol,
    required this.label,
    required this.value,
    required this.color,
  });

  final String symbol;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      constraints: const BoxConstraints(minWidth: 138),
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x162D2A32),
            offset: Offset(0, 3),
            blurRadius: 9,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: Text(symbol, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7C5A3B),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF3F2A18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final topColor = Color.lerp(color, Colors.white, 0.16)!;
    final bottomColor = Color.lerp(color, Colors.black, 0.12)!;
    return Material(
      color: Colors.transparent,
      elevation: onPressed == null ? 0 : 2,
      shadowColor: color.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(19),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: onPressed == null
                ? [color.withValues(alpha: 0.38), color.withValues(alpha: 0.3)]
                : [topColor, bottomColor],
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 27,
                  height: 27,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.26),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 17, color: Colors.white),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withValues(
                      alpha: onPressed == null ? 0.78 : 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconOnlyTopButton extends StatelessWidget {
  const _IconOnlyTopButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 46,
      child: Material(
        color: Colors.transparent,
        elevation: 2,
        shadowColor: const Color(0x282D2A32),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: Tooltip(
          message: '设置',
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Ink(
              decoration: const BoxDecoration(
                color: Color(0xFFFFF8EE),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, size: 23, color: Color(0xFF9A5428)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeAiPanel extends StatelessWidget {
  const _HomeAiPanel({
    required this.pet,
    required this.messages,
    required this.controller,
    required this.sending,
    required this.voiceListening,
    required this.expanded,
    required this.onExpand,
    required this.onSend,
    required this.onVoice,
    required this.onSpeak,
    required this.onShortcut,
  });

  final PetDefinition pet;
  final List<_HomeAiMessage> messages;
  final TextEditingController controller;
  final bool sending;
  final bool voiceListening;
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onSend;
  final VoidCallback onVoice;
  final ValueChanged<String> onSpeak;
  final ValueChanged<String> onShortcut;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAliasWithSaveLayer,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: AssetImage('assets/home/resources/home_ai_panel.png'),
          fit: BoxFit.cover,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F2D2A32),
            offset: Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                    child: ListView.separated(
                      itemCount: messages.length,
                      padding: const EdgeInsets.only(bottom: 10),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return _HomeChatBubble(
                          message: message,
                          petId: pet.id,
                          expanded: expanded,
                          onSpeak: message.isUser
                              ? null
                              : () => onSpeak(message.text),
                        );
                      },
                    ),
                  ),
                ),
                _HomeAiInputBar(
                  controller: controller,
                  sending: sending,
                  voiceListening: voiceListening,
                  onSend: onSend,
                  onVoice: onVoice,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Row(
                    children: [
                      _AiShortcutChip(
                        icon: Icons.menu_book,
                        label: '知识讲解',
                        onTap: () => onShortcut('请用一年级能听懂的话讲一个知识点。'),
                      ),
                      const SizedBox(width: 8),
                      _AiShortcutChip(
                        icon: Icons.edit_note,
                        label: '题目辅导',
                        onTap: () => onShortcut('我有一道题不会做，请一步一步教我。'),
                      ),
                      const SizedBox(width: 8),
                      _AiShortcutChip(
                        icon: Icons.lightbulb,
                        label: '学习方法',
                        onTap: () => onShortcut('请教我一个今天学习更专心的方法。'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (sending)
              const Positioned(
                right: 58,
                top: 16,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            Positioned(
              right: 10,
              top: 8,
              child: IconButton(
                onPressed: onExpand,
                tooltip: expanded ? '收起对话窗口' : '放大对话窗口',
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.82),
                  foregroundColor: const Color(0xFF8A4A26),
                  shape: const CircleBorder(),
                ),
                icon: Icon(
                  expanded
                      ? Icons.close_fullscreen_rounded
                      : Icons.open_in_full_rounded,
                  size: 19,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeChatBubble extends StatelessWidget {
  const _HomeChatBubble({
    required this.message,
    required this.petId,
    required this.expanded,
    required this.onSpeak,
  });

  final _HomeAiMessage message;
  final String petId;
  final bool expanded;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: expanded ? 760 : 330),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF8B5CF6) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 5),
            bottomRight: Radius.circular(isUser ? 5 : 16),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x122D2A32),
              offset: Offset(0, 3),
              blurRadius: 10,
            ),
          ],
        ),
        child: isUser
            ? Text(
                message.text,
                maxLines: null,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      message.text,
                      maxLines: null,
                      overflow: TextOverflow.visible,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3F2A18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: onSpeak,
                    tooltip: '播放果果的回答',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    icon: const Icon(
                      Icons.volume_up_rounded,
                      size: 19,
                      color: Color(0xFFE7863C),
                    ),
                  ),
                ],
              ),
      ),
    );

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(left: 54),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              bubble,
              const SizedBox(width: 8),
              ClipOval(
                child: Image.asset(
                  'assets/home/resources/user_avatar_girl.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD166),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.face_rounded,
                      color: Color(0xFF8A4A26),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(right: 38),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/pets/$petId.png',
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Image.asset(
                  'assets/pets/fifi.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(child: bubble),
          ],
        ),
      ),
    );
  }
}

class _HomeAiInputBar extends StatelessWidget {
  const _HomeAiInputBar({
    required this.controller,
    required this.sending,
    required this.voiceListening,
    required this.onSend,
    required this.onVoice,
  });

  final TextEditingController controller;
  final bool sending;
  final bool voiceListening;
  final VoidCallback onSend;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: '问果果一个问题...',
                  hintStyle: const TextStyle(fontWeight: FontWeight.w700),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: Color(0xFFE6A35F),
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: Color(0xFFFF8C42),
                      width: 1.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox.square(
            dimension: 44,
            child: Tooltip(
              message: voiceListening ? '结束语音输入' : '语音输入',
              child: IconButton.filledTonal(
                onPressed: sending ? null : onVoice,
                style: IconButton.styleFrom(
                  backgroundColor: voiceListening
                      ? const Color(0xFFE86A74)
                      : const Color(0xFFFFE7C7),
                  foregroundColor: voiceListening
                      ? Colors.white
                      : const Color(0xFF9A5428),
                  shape: const CircleBorder(),
                ),
                icon: Icon(
                  voiceListening ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox.square(
            dimension: 46,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF8C1A),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
                elevation: 2,
                shadowColor: const Color(0x302D2A32),
              ),
              onPressed: sending ? null : onSend,
              child: const Icon(Icons.send, size: 25),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiShortcutChip extends StatelessWidget {
  const _AiShortcutChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 36,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF7C3F1D),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 1,
            shadowColor: const Color(0x1E2D2A32),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          onPressed: onTap,
          icon: Icon(icon, size: 17),
          label: Text(label, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _HomeModuleGrid extends StatelessWidget {
  const _HomeModuleGrid({
    required this.onOpenIsland,
    required this.onOpenSelfChallenge,
    required this.onOpenWorksheet,
    required this.onOpenStudyMaterials,
    required this.onOpenLeisure,
    required this.onLockedIsland,
  });

  final ValueChanged<Island> onOpenIsland;
  final VoidCallback onOpenSelfChallenge;
  final VoidCallback onOpenWorksheet;
  final VoidCallback onOpenStudyMaterials;
  final VoidCallback onOpenLeisure;
  final ValueChanged<String> onLockedIsland;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _ModuleCardData(
        icon: Icons.calculate,
        assetPath: 'assets/home/modules/math_island.png',
        title: '数学岛',
        subtitle: '探索数学的奥秘',
        color: const Color(0xFFFFD4A3),
        accent: const Color(0xFFFF8C42),
        onTap: () => onOpenIsland(Island.math),
      ),
      _ModuleCardData(
        icon: Icons.menu_book,
        assetPath: 'assets/home/modules/chinese_island.png',
        title: '语文岛',
        subtitle: '感受汉字的魅力',
        color: const Color(0xFFFFE4E6),
        accent: const Color(0xFFE11D48),
        locked: true,
        onTap: () => onLockedIsland('语文岛'),
      ),
      _ModuleCardData(
        icon: Icons.translate,
        assetPath: 'assets/home/modules/english_island.png',
        title: '英语岛',
        subtitle: '快乐学英语',
        color: const Color(0xFFAEE2FF),
        accent: const Color(0xFF16A34A),
        locked: true,
        onTap: () => onLockedIsland('英语岛'),
      ),
      _ModuleCardData(
        icon: Icons.search,
        assetPath: 'assets/home/modules/sudoku_detective.png',
        title: '数独侦探所',
        subtitle: '逻辑推理训练',
        color: const Color(0xFFD9C7FF),
        accent: const Color(0xFF7C3AED),
        onTap: () => onOpenIsland(Island.sudoku),
      ),
      _ModuleCardData(
        icon: Icons.emoji_events,
        assetPath: 'assets/home/modules/self_challenge.png',
        title: '自我挑战',
        subtitle: '挑战自我，突破极限',
        color: const Color(0xFFA7F3D0),
        accent: const Color(0xFFB7791F),
        onTap: onOpenSelfChallenge,
      ),
      _ModuleCardData(
        icon: Icons.edit_note,
        assetPath: 'assets/home/modules/worksheet_practice.png',
        title: '试卷练习',
        subtitle: '同步试卷，巩固提升',
        color: const Color(0xFFFFE4B5),
        accent: const Color(0xFF2563EB),
        onTap: onOpenWorksheet,
      ),
      _ModuleCardData(
        icon: Icons.fact_check_rounded,
        assetPath: 'assets/home/modules/exam_focus.png',
        title: '考试重点',
        subtitle: '聚焦重点，高效备考',
        color: const Color(0xFFE3F2FD),
        accent: const Color(0xFF047857),
        onTap: onOpenStudyMaterials,
      ),
      _ModuleCardData(
        icon: Icons.extension,
        assetPath: 'assets/home/modules/leisure_playground.png',
        title: '休闲乐园',
        subtitle: '放松心情，快乐成长',
        color: const Color(0xFFFFC6D9),
        accent: const Color(0xFFE11D48),
        onTap: onOpenLeisure,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 600 ? 3 : 2;
        return GridView.builder(
          itemCount: cards.length,
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: crossAxisCount == 3 ? 1.12 : 0.78,
          ),
          itemBuilder: (context, index) => _ModuleCard(data: cards[index]),
        );
      },
    );
  }
}

class _ModuleCardData {
  const _ModuleCardData({
    required this.icon,
    required this.assetPath,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.accent,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String assetPath;
  final String title;
  final String subtitle;
  final Color color;
  final Color accent;
  final VoidCallback onTap;
  final bool locked;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.data});

  final _ModuleCardData data;

  @override
  Widget build(BuildContext context) {
    final cardRadius = BorderRadius.circular(18);
    return Material(
      color: Colors.transparent,
      elevation: 3,
      shadowColor: const Color(0x2A2D2A32),
      shape: RoundedRectangleBorder(borderRadius: cardRadius),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: InkWell(
        onTap: data.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              data.assetPath,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(
                color: data.color,
                child: Icon(data.icon, size: 64, color: data.accent),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xBFFFFFFF),
                    Color(0x10FFFFFF),
                    Color(0xEFFFF7E8),
                  ],
                  stops: [0, 0.42, 1],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              top: 9,
              child: Text(
                data.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  color: data.accent,
                  shadows: const [
                    Shadow(
                      color: Colors.white,
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Text(
                data.subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6B4B2C),
                ),
              ),
            ),
            if (data.locked)
              Positioned(
                right: 9,
                top: 8,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock,
                    size: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
