import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/app_store.dart';
import '../services/audio_service.dart';
import 'pet_selection_screen.dart';

class GradeSelectionScreen extends StatelessWidget {
  const GradeSelectionScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _GradeCardData(
        badge: '一上',
        title: '一年级上册',
        subtitle: 'M1-M6 · Y1-Y3 · E1-E2',
        color: const Color(0xFFFF8A1F),
        lightColor: const Color(0xFFFFF0D7),
        grade: gradeOneUp,
      ),
      _GradeCardData(
        badge: '一下',
        title: '一年级下册',
        subtitle: 'M7-M12 · Y4-Y5 · E3-E4',
        color: const Color(0xFFFFBE1F),
        lightColor: const Color(0xFFFFF7D8),
        grade: gradeOneDown,
      ),
      _GradeCardData(
        badge: '二上',
        title: '二年级上册',
        subtitle: 'M13-M18 · Y6-Y8 · E5-E6',
        color: const Color(0xFF67A83A),
        lightColor: const Color(0xFFEFF9E4),
        grade: gradeTwoUp,
      ),
      _GradeCardData(
        badge: '二下',
        title: '二年级下册',
        subtitle: 'M19-M24 · Y9 · E7-E8',
        color: const Color(0xFF2D9DE0),
        lightColor: const Color(0xFFE8F6FF),
        grade: gradeTwoDown,
      ),
      const _GradeCardData(badge: '三上', title: '三年级上册'),
      const _GradeCardData(badge: '三下', title: '三年级下册'),
      const _GradeCardData(badge: '四上', title: '四年级上册'),
      const _GradeCardData(badge: '四下', title: '四年级下册'),
      const _GradeCardData(badge: '五上', title: '五年级上册'),
      const _GradeCardData(badge: '五下', title: '五年级下册'),
      const _GradeCardData(badge: '六上', title: '六年级上册'),
      const _GradeCardData(badge: '六下', title: '六年级下册'),
    ];

    return Scaffold(
      body: _WarmBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                child: Column(
                  children: [
                    const _GradeHero(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.9,
                            ),
                        itemCount: cards.length,
                        itemBuilder: (context, index) {
                          final card = cards[index];
                          return _GradeCard(
                            data: card,
                            store: card.grade == null ? null : store,
                          );
                        },
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

class _GradeHero extends StatelessWidget {
  const _GradeHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 142,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 26,
            bottom: -4,
            child: Image.asset(
              'assets/pets/fifi.png',
              width: 150,
              height: 150,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const Positioned(left: 26, top: 46, child: _Spark(size: 16)),
          const Positioned(left: 210, top: 76, child: _Spark(size: 12)),
          Positioned(
            top: 18,
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Leaf(color: const Color(0xFFE4B36C), flip: true),
                    const SizedBox(width: 20),
                    Text(
                      '智慧小探险家',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF5A2E12),
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(width: 20),
                    _Leaf(color: const Color(0xFFE4B36C)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '请选择当前正在学习的年级和册别',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF684020),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({required this.data, required this.store});

  final _GradeCardData data;
  final AppStore? store;

  @override
  Widget build(BuildContext context) {
    final enabled = store != null && data.grade != null;
    final mainColor = enabled ? data.color : const Color(0xFF9AA0A6);
    final lightColor = enabled ? data.lightColor : const Color(0xFFF3F1EE);
    final textColor = enabled
        ? const Color(0xFF4D2B17)
        : const Color(0xFF666A70);

    return Opacity(
      opacity: enabled ? 1 : .76,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled
              ? () async {
                  final appStore = store!;
                  await AudioService.playSfx(
                    AppSound.reward,
                    enabled: appStore.progress.settings['sfx'] ?? true,
                  );
                  await appStore.selectGrade(data.grade!);
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => PetSelectionScreen(store: appStore),
                    ),
                  );
                }
              : null,
          child: Ink(
            decoration: BoxDecoration(
              color: lightColor.withValues(alpha: .96),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: enabled
                    ? mainColor.withValues(alpha: .72)
                    : const Color(0xFFC9C9C9),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B3D18).withValues(alpha: .16),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                const BoxShadow(
                  color: Colors.white,
                  blurRadius: 0,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CardCloudPainter(
                        color: mainColor,
                        muted: !enabled,
                      ),
                    ),
                  ),
                  if (!enabled)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.lock,
                          size: 17,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Row(
                      children: [
                        _GradeBadge(
                          label: data.badge,
                          color: mainColor,
                          enabled: enabled,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 23,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const _SubjectPills(),
                              const SizedBox(height: 8),
                              Text(
                                data.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: textColor.withValues(alpha: .82),
                                ),
                              ),
                              const Spacer(),
                              Align(
                                alignment: Alignment.centerRight,
                                child: _GradeActionPill(
                                  enabled: enabled,
                                  color: mainColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradeBadge extends StatelessWidget {
  const _GradeBadge({
    required this.label,
    required this.color,
    required this.enabled,
  });

  final String label;
  final Color color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: enabled
            ? RadialGradient(colors: [color.withValues(alpha: .72), color])
            : const RadialGradient(
                colors: [Color(0xFFD9D9D9), Color(0xFFAAAEB4)],
              ),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: enabled ? .35 : .1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 25,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 1))],
        ),
      ),
    );
  }
}

class _SubjectPills extends StatelessWidget {
  const _SubjectPills();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      runSpacing: 4,
      children: const [
        _MiniSubject(icon: Icons.calculate, label: '数学'),
        _MiniSubject(icon: Icons.menu_book_rounded, label: '语文'),
        _MiniSubject(icon: Icons.translate, label: '英语'),
      ],
    );
  }
}

class _MiniSubject extends StatelessWidget {
  const _MiniSubject({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF7B5B35)),
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF5E4633),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeActionPill extends StatelessWidget {
  const _GradeActionPill({required this.enabled, required this.color});

  final bool enabled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: enabled
              ? [color.withValues(alpha: .78), color]
              : const [Color(0xFFC9C9C9), Color(0xFF8E9399)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33000000), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            enabled ? '开始学习' : '待开放',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (enabled) ...[
            const SizedBox(width: 5),
            const Icon(Icons.chevron_right, size: 21, color: Colors.white),
          ],
        ],
      ),
    );
  }
}

class _GradeCardData {
  const _GradeCardData({
    required this.badge,
    required this.title,
    this.subtitle = '数学 · 语文 · 英语',
    this.color = const Color(0xFF9AA0A6),
    this.lightColor = const Color(0xFFF3F1EE),
    this.grade,
  });

  final String badge;
  final String title;
  final String subtitle;
  final Color color;
  final Color lightColor;
  final int? grade;
}

class _WarmBackdrop extends StatelessWidget {
  const _WarmBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.15,
          colors: [Color(0xFFFFFDF7), Color(0xFFFFF4D9), Color(0xFFFFF9EE)],
        ),
      ),
      child: child,
    );
  }
}

class _Spark extends StatelessWidget {
  const _Spark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.star_rounded, size: size, color: const Color(0xFFFFC43D));
  }
}

class _Leaf extends StatelessWidget {
  const _Leaf({required this.color, this.flip = false});

  final Color color;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: flip ? -1 : 1,
      child: Icon(
        Icons.eco_rounded,
        size: 38,
        color: color.withValues(alpha: .78),
      ),
    );
  }
}

class _CardCloudPainter extends CustomPainter {
  const _CardCloudPainter({required this.color, required this.muted});

  final Color color;
  final bool muted;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = true
      ..color = (muted ? Colors.white : color).withValues(
        alpha: muted ? .42 : .16,
      );
    final y = size.height - 6;
    for (final data in [
      (Offset(size.width * .05, y), 26.0),
      (Offset(size.width * .13, y + 3), 20.0),
      (Offset(size.width * .25, y + 2), 30.0),
      (Offset(size.width * .36, y + 6), 18.0),
    ]) {
      canvas.drawCircle(data.$1, data.$2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CardCloudPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.muted != muted;
  }
}
