import 'dart:async';

import 'package:flutter/material.dart';

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

  final aiService = AiService();
  final aiInputController = TextEditingController();
  final aiMessages = <_HomeAiMessage>[
    const _HomeAiMessage(isUser: false, text: '嗨！我是果果。今天想练什么？可以问我题目、知识点或学习方法。'),
  ];

  bool aiSending = false;
  String? homeConversationId;

  @override
  void initState() {
    super.initState();
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
    aiInputController.dispose();
    aiService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.store.progress;
    final pet = petById(progress.selectedPet);
    final grade = normalizeGradeCode(progress.selectedGrade);
    return ExplorerScaffold(
      title: '',
      showAppBar: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _HomeTopBar(
              progress: progress,
              onFeed: progress.energyFruit > 0 ? _feedPet : null,
              onShop: () => _openSceneScreen(
                AppMusicScene.shop,
                ShopScreen(store: widget.store),
              ),
              onSettings: _openSettings,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _HomeAiPanel(
                      pet: pet,
                      messages: aiMessages,
                      controller: aiInputController,
                      sending: aiSending,
                      onSend: _sendHomeAiMessage,
                      onShortcut: _sendShortcutMessage,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 8,
                    child: _HomeModuleGrid(
                      grade: grade,
                      progressText: _progressText,
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

  Future<void> _feedPet() async {
    final fed = await widget.store.feedPet();
    if (!fed) return;
    await AudioService.playSfx(
      AppSound.feed,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _sendShortcutMessage(String text) async {
    aiInputController.text = text;
    await _sendHomeAiMessage();
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

  String _progressText(Island island, int grade) {
    final total = totalLevelsForIsland(island, grade);
    final finished = island == Island.sudoku
        ? [
            'S-random-4',
            'S-random-6',
            'S-random-9',
          ].where(widget.store.progress.completedLevels.contains).length
        : levelsForIsland(island, grade)
              .where(
                (level) =>
                    widget.store.progress.completedLevels.contains(level.id),
              )
              .length;
    return '$finished/$total';
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
    required this.onFeed,
    required this.onShop,
    required this.onSettings,
  });

  final AppProgress progress;
  final VoidCallback? onFeed;
  final VoidCallback onShop;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF8B5A2B), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x222D2A32),
            offset: Offset(0, 4),
            blurRadius: 10,
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
            icon: Icons.restaurant,
            label: '喂食',
            color: const Color(0xFFE94B6B),
            onPressed: onFeed,
          ),
          const SizedBox(width: 8),
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
        border: Border.all(color: const Color(0xFFE6C8A2), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x142D2A32),
            offset: Offset(0, 3),
            blurRadius: 7,
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
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.42),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.86),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF8B5A2B), width: 1.2),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
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
      dimension: 48,
      child: IconButton.filledTonal(
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF7C3F1D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE6C8A2), width: 1.2),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
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
    required this.onSend,
    required this.onShortcut,
  });

  final PetDefinition pet;
  final List<_HomeAiMessage> messages;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final ValueChanged<String> onShortcut;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8B5A2B), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x202D2A32),
            offset: Offset(0, 6),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
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
                        return _HomeChatBubble(message: message, petId: pet.id);
                      },
                    ),
                  ),
                ),
                _HomeAiInputBar(
                  controller: controller,
                  sending: sending,
                  onSend: onSend,
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
                right: 18,
                top: 16,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeChatBubble extends StatelessWidget {
  const _HomeChatBubble({required this.message, required this.petId});

  final _HomeAiMessage message;
  final String petId;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubble = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 330),
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
          border: Border.all(
            color: isUser ? const Color(0xFF6D28D9) : const Color(0xFFE6C8A2),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x142D2A32),
              offset: Offset(0, 3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Text(
          message.text,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            height: 1.35,
            fontWeight: FontWeight.w800,
            color: isUser ? Colors.white : const Color(0xFF3F2A18),
          ),
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
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFF8B5CF6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 22),
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
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

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
          const SizedBox(width: 10),
          SizedBox.square(
            dimension: 46,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF8C1A),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                  side: const BorderSide(color: Color(0xFF8B5A2B), width: 1.1),
                ),
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
            side: const BorderSide(color: Color(0xFFE6C8A2), width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
    required this.grade,
    required this.progressText,
    required this.onOpenIsland,
    required this.onOpenSelfChallenge,
    required this.onOpenWorksheet,
    required this.onOpenStudyMaterials,
    required this.onOpenLeisure,
    required this.onLockedIsland,
  });

  final int grade;
  final String Function(Island island, int grade) progressText;
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
        progressText:
            '${gradeName(grade)} · ${progressText(Island.math, grade)}',
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
        final crossAxisCount = constraints.maxWidth >= 660 ? 4 : 2;
        return GridView.builder(
          itemCount: cards.length,
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: crossAxisCount == 4 ? 0.56 : 0.78,
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
    this.progressText,
    this.locked = false,
  });

  final IconData icon;
  final String assetPath;
  final String title;
  final String subtitle;
  final Color color;
  final Color accent;
  final VoidCallback onTap;
  final String? progressText;
  final bool locked;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.data});

  final _ModuleCardData data;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F2D2A32),
            offset: Offset(0, 7),
            blurRadius: 14,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: data.onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: data.accent.withValues(alpha: 0.72),
                width: 1.6,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            data.color.withValues(alpha: 0.2),
                            const Color(0xFFFFF7E8),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      top: 54,
                      bottom: 54,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Image.asset(
                          data.assetPath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              Icon(data.icon, size: 64, color: data.accent),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      right: 8,
                      top: 13,
                      child: Text(
                        data.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
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
                      bottom: 14,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            data.subtitle,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF6B4B2C),
                            ),
                          ),
                          if (data.progressText != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              data.progressText!,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: data.accent.withValues(alpha: 0.82),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (data.locked)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF9CA3AF)),
                          ),
                          child: const Icon(
                            Icons.lock,
                            size: 18,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
