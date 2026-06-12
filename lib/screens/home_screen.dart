import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../models/app_models.dart';
import '../services/app_store.dart';
import '../services/audio_service.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/ui_components.dart';
import 'map_screen.dart';
import 'self_challenge_screen.dart';
import 'shop_screen.dart';
import 'stats_settings_screen.dart';
import 'worksheet_library_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static bool playedLaunchPetVoice = false;

  String bubble = '今天想去哪个岛探险？';
  bool cheering = false;
  bool petTapVoicePlaying = false;
  Timer? bubbleTimer;

  @override
  void initState() {
    super.initState();
    if (widget.store.progress.settings['music'] ?? false) {
      AudioService.playBgm(AppMusicScene.home);
    }
    bubbleTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      setState(() => bubble = _randomBubble());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _playLaunchPetVoice());
  }

  @override
  void dispose() {
    bubbleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.store.progress;
    final pet = petById(progress.selectedPet);
    final grade = normalizeGradeCode(progress.selectedGrade);
    return ExplorerScaffold(
      title: '菲菲加油！',
      actions: [
        IconButton(
          tooltip: '设置',
          icon: const Icon(Icons.settings),
          onPressed: () =>
              pushScreen(context, StatsSettingsScreen(store: widget.store)),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatPill(
                          icon: Icons.energy_savings_leaf,
                          label: '能量果',
                          value: '${progress.energyFruit}',
                          color: const Color(0xFFA7F3D0),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatPill(
                          icon: Icons.star,
                          label: '星星',
                          value: '${progress.totalStars}',
                          color: const Color(0xFFFFE08A),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatPill(
                          icon: Icons.workspace_premium,
                          label: '勋章',
                          value: '${progress.badges.length}',
                          color: const Color(0xFFBFDBFE),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SoftCard(
                      color: const Color(0xFFFFF8E1),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                const petSize = 180.0;
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: _petTap,
                                      child: PetAvatar(
                                        pet: pet,
                                        level: progress.petLevel,
                                        size: petSize,
                                        cheering: cheering,
                                        cosmeticIds: widget.store
                                            .equippedCosmeticsForPet(pet.id),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: constraints.maxWidth.clamp(
                                        220,
                                        360,
                                      ),
                                      child: Text(
                                        bubble,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF5B4636),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${pet.name} Lv.${progress.petLevel}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress.petLevel >= 7
                                  ? 1
                                  : (progress.petExp / progress.nextLevelExp)
                                        .clamp(0, 1)
                                        .toDouble(),
                              minHeight: 10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '成长值 ${progress.petExp}/${progress.nextLevelExp}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              runSpacing: 10,
                              children: [
                                _PetHomeButton(
                                  icon: const EnergyFruit(size: 24),
                                  label: '喂能量果',
                                  color: const Color(0xFF22C55E),
                                  onPressed: progress.energyFruit > 0
                                      ? _feedPet
                                      : null,
                                ),
                                _PetHomeButton(
                                  icon: const Icon(Icons.storefront, size: 23),
                                  label: '魔法商店',
                                  color: const Color(0xFFFF8C42),
                                  onPressed: () => _openSceneScreen(
                                    AppMusicScene.shop,
                                    ShopScreen(store: widget.store),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 7,
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 2.45,
                children: [
                  _HomeAction(
                    icon: Icons.calculate,
                    title: '数学岛',
                    subtitle:
                        '${gradeName(grade)} · ${_progressText(Island.math, grade)}',
                    color: const Color(0xFFFFD4A3),
                    onTap: () => _openIsland(Island.math),
                  ),
                  _HomeAction(
                    icon: Icons.menu_book,
                    title: '语文岛',
                    subtitle: '暂未开放',
                    color: const Color(0xFFFFF8E1),
                    locked: true,
                    onTap: () => _showLockedIsland('语文岛'),
                  ),
                  _HomeAction(
                    icon: Icons.translate,
                    emblem: const _EnglishIslandEmblem(),
                    title: '英语岛',
                    subtitle: '暂未开放',
                    color: const Color(0xFFAEE2FF),
                    locked: true,
                    onTap: () => _showLockedIsland('英语岛'),
                  ),
                  _HomeAction(
                    icon: Icons.search,
                    title: '数独侦探所',
                    subtitle: '4×4 到 9×9 逻辑案件',
                    color: const Color(0xFFD9C7FF),
                    onTap: () => _openIsland(Island.sudoku),
                  ),
                  _HomeAction(
                    icon: Icons.emoji_events,
                    title: '自我挑战',
                    subtitle: '今日挑战、错题秘境、速度之星、连胜纪录',
                    color: const Color(0xFFA7F3D0),
                    onTap: () => _openSceneScreen(
                      AppMusicScene.selfChallenge,
                      SelfChallengeScreen(store: widget.store),
                    ),
                  ),
                  _HomeAction(
                    icon: Icons.edit_note,
                    title: '试卷练习',
                    subtitle: '导入试卷 · 计算题自动批改',
                    color: const Color(0xFFFFE4B5),
                    onTap: () => _openSceneScreen(
                      AppMusicScene.home,
                      WorksheetLibraryScreen(store: widget.store),
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

  Future<void> _petTap() async {
    if (petTapVoicePlaying) return;
    setState(() {
      bubble = _randomBubble();
      cheering = true;
      petTapVoicePlaying = true;
    });
    await AudioService.playOneShot(
      AppSound.petClick,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
    if (!mounted) return;
    setState(() => petTapVoicePlaying = false);
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => cheering = false);
    });
  }

  Future<void> _playLaunchPetVoice() async {
    if (!mounted || playedLaunchPetVoice) return;
    playedLaunchPetVoice = true;
    await AudioService.playSfx(
      AppSound.petCute,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
    if (!mounted) return;
    setState(() {
      bubble = _randomBubble();
      cheering = true;
    });
    Future.delayed(const Duration(milliseconds: 420), () {
      if (mounted) setState(() => cheering = false);
    });
  }

  Future<void> _feedPet() async {
    final fed = await widget.store.feedPet();
    if (!fed) return;
    await AudioService.playSfx(
      AppSound.feed,
      enabled: widget.store.progress.settings['sfx'] ?? true,
    );
    if (!mounted) return;
    setState(() {
      bubble = '谢谢！成长值 +1，我感觉更有精神了。';
      cheering = true;
    });
    Future.delayed(const Duration(milliseconds: 360), () {
      if (mounted) setState(() => cheering = false);
    });
  }

  Future<void> _openIsland(Island island) async {
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
    if (widget.store.progress.settings['music'] ?? false) {
      AudioService.playBgm(AppMusicScene.home);
    }
  }

  Future<void> _openSceneScreen(AppMusicScene scene, Widget screen) async {
    if (widget.store.progress.settings['music'] ?? false) {
      AudioService.playBgm(scene);
    }
    await pushScreen(context, screen);
    if (!mounted) return;
    if (widget.store.progress.settings['music'] ?? false) {
      AudioService.playBgm(AppMusicScene.home);
    }
  }

  void _showLockedIsland(String name) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$name 暂未开放，完善后再开启。')));
  }

  String _randomBubble() {
    final lines = [
      '我准备好啦，去探险吧！',
      '今天先挑战哪个岛？',
      '答错也没关系，我陪你重来。',
      '能量果闻起来甜甜的。',
      'Great job!',
      '侦探雷达启动！',
      '学一点点，也是在变强。',
    ];
    return lines[Random().nextInt(lines.length)];
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

class _PetHomeButton extends StatelessWidget {
  const _PetHomeButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      height: 48,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          elevation: 2,
          shadowColor: const Color(0x552D2A32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF2D2A32), width: 1.4),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        icon: icon,
        label: Text(label, overflow: TextOverflow.ellipsis),
        onPressed: onPressed,
      ),
    );
  }
}

class _EnglishIslandEmblem extends StatelessWidget {
  const _EnglishIslandEmblem();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFAEE2FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2D2A32), width: 1.4),
            ),
          ),
          const Positioned(
            left: 9,
            top: 9,
            child: Text(
              'A',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          const Positioned(
            right: 8,
            bottom: 8,
            child: Text(
              'B',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
          const Positioned(
            right: 5,
            top: 5,
            child: Icon(Icons.volume_up, size: 16, color: Color(0xFF2563EB)),
          ),
          const Positioned(
            left: 6,
            bottom: 5,
            child: Icon(Icons.music_note, size: 15, color: Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }
}

class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.emblem,
    this.locked = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final Widget? emblem;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: color,
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: locked
                ? const Icon(Icons.lock, size: 32, color: Color(0xFF6B7280))
                : emblem ??
                      Icon(icon, size: 34, color: const Color(0xFF2D2A32)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          Icon(locked ? Icons.lock_outline : Icons.chevron_right),
        ],
      ),
    );
  }
}
