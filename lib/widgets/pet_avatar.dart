import 'dart:math';

import 'package:flutter/material.dart';

import '../models/app_models.dart';

enum PetMood { normal, happy, sad }

class PetAvatar extends StatefulWidget {
  const PetAvatar({
    super.key,
    required this.pet,
    required this.level,
    this.size = 140,
    this.cheering = false,
    this.mood = PetMood.normal,
    this.cosmeticIds,
  });

  final PetDefinition pet;
  final int level;
  final double size;
  final bool cheering;
  final PetMood mood;
  final Set<String>? cosmeticIds;

  @override
  State<PetAvatar> createState() => _PetAvatarState();
}

class _PetAvatarState extends State<PetAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController idleController;

  @override
  void initState() {
    super.initState();
    idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cosmetics = widget.cosmeticIds ?? _cosmeticsForLevel(widget.level);
    final skinAsset = _premiumSkinAsset(widget.pet.id, cosmetics);
    return AnimatedBuilder(
      animation: idleController,
      builder: (context, child) {
        final t = idleController.value * 2 * pi;
        final floatY = sin(t) * widget.size * 0.018;
        final tilt = sin(t + pi / 4) * 0.025;
        return Transform.translate(
          offset: Offset(0, floatY),
          child: Transform.rotate(
            angle: widget.cheering ? -0.045 : tilt,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              scale: widget.cheering ? 1.09 : 1,
              child: child,
            ),
          ),
        );
      },
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (skinAsset == null && cosmetics.isNotEmpty)
              CustomPaint(
                size: Size.square(widget.size),
                painter: _PetCosmeticPainter(
                  cosmeticIds: cosmetics,
                  petId: widget.pet.id,
                  pulse: idleController.value,
                  layer: _CosmeticLayer.back,
                ),
              ),
            Image.asset(
              skinAsset ?? 'assets/pets/${widget.pet.id}.png',
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => CustomPaint(
                size: Size.square(widget.size),
                painter: _PetPainter(
                  color: Color(widget.pet.primaryColor),
                  petId: widget.pet.id,
                  cosmeticIds: {},
                ),
              ),
            ),
            if (skinAsset == null && cosmetics.isNotEmpty)
              CustomPaint(
                size: Size.square(widget.size),
                painter: _PetCosmeticPainter(
                  cosmeticIds: cosmetics,
                  petId: widget.pet.id,
                  pulse: idleController.value,
                  layer: _CosmeticLayer.front,
                ),
              ),
            if (widget.mood != PetMood.normal)
              CustomPaint(
                size: Size.square(widget.size),
                painter: _PetMoodPainter(mood: widget.mood),
              ),
          ],
        ),
      ),
    );
  }

  Set<String> _cosmeticsForLevel(int _) {
    return {};
  }

  String? _premiumSkinAsset(String petId, Set<String> cosmetics) {
    const skinPets = {'fifi', 'magic_star', 'magic_moon', 'magic_flower'};
    if (!skinPets.contains(petId) || cosmetics.isEmpty) return null;
    const fullSet = {'hat', 'backpack', 'cape', 'crown', 'halo', 'ultimate'};
    if (fullSet.every(cosmetics.contains)) {
      return 'assets/pets/cosmetics/${petId}_full.jpg';
    }
    if (cosmetics.length == 1) {
      return 'assets/pets/cosmetics/${petId}_${cosmetics.first}.jpg';
    }
    for (final id in const [
      'ultimate',
      'halo',
      'crown',
      'cape',
      'backpack',
      'hat',
    ]) {
      if (cosmetics.contains(id)) {
        return 'assets/pets/cosmetics/${petId}_$id.jpg';
      }
    }
    return null;
  }
}

class _PetMoodPainter extends CustomPainter {
  _PetMoodPainter({required this.mood});

  final PetMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round;
    final ink = const Color(0xFF2D2A32);

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .035
      ..color = ink;

    if (mood == PetMood.happy) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(s * .39, s * .47),
          width: s * .12,
          height: s * .08,
        ),
        pi,
        pi,
        false,
        paint,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(s * .61, s * .47),
          width: s * .12,
          height: s * .08,
        ),
        pi,
        pi,
        false,
        paint,
      );
      paint.strokeWidth = s * .04;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(s * .5, s * .6),
          width: s * .26,
          height: s * .16,
        ),
        0,
        pi,
        false,
        paint,
      );
      _drawSpark(canvas, Offset(s * .73, s * .3), s * .055);
      _drawSpark(canvas, Offset(s * .26, s * .31), s * .04);
      return;
    }

    canvas.drawLine(Offset(s * .34, s * .44), Offset(s * .44, s * .5), paint);
    canvas.drawLine(Offset(s * .44, s * .44), Offset(s * .34, s * .5), paint);
    canvas.drawLine(Offset(s * .56, s * .44), Offset(s * .66, s * .5), paint);
    canvas.drawLine(Offset(s * .66, s * .44), Offset(s * .56, s * .5), paint);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s * .5, s * .66),
        width: s * .24,
        height: s * .14,
      ),
      pi,
      pi,
      false,
      paint,
    );

    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF60A5FA).withValues(alpha: .86);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * .35, s * .58),
        width: s * .055,
        height: s * .11,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * .65, s * .58),
        width: s * .055,
        height: s * .11,
      ),
      paint,
    );
  }

  void _drawSpark(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * .28
      ..color = const Color(0xFFFFD166);
    canvas.drawLine(
      center + Offset(-radius, 0),
      center + Offset(radius, 0),
      paint,
    );
    canvas.drawLine(
      center + Offset(0, -radius),
      center + Offset(0, radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PetMoodPainter oldDelegate) {
    return oldDelegate.mood != mood;
  }
}

enum _CosmeticLayer { back, front }

class _PetCosmeticPainter extends CustomPainter {
  _PetCosmeticPainter({
    required this.cosmeticIds,
    required this.petId,
    required this.pulse,
    required this.layer,
  });

  final Set<String> cosmeticIds;
  final String petId;
  final double pulse;
  final _CosmeticLayer layer;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final scheme = _cosmeticScheme(petId);

    if (layer == _CosmeticLayer.back) {
      if (cosmeticIds.contains('ultimate')) {
        _drawUltimateBack(canvas, size, paint, scheme);
      }
      if (cosmeticIds.contains('halo')) {
        _drawHalo(canvas, size, paint, scheme);
      }
      if (cosmeticIds.contains('cape')) {
        _drawCape(canvas, size, paint, scheme);
      }
      return;
    }

    if (cosmeticIds.contains('backpack')) {
      _drawSatchel(canvas, size, paint, scheme);
    }
    if (cosmeticIds.contains('hat')) {
      _drawHat(canvas, size, paint, scheme);
    }
    if (cosmeticIds.contains('crown')) {
      _drawCrown(canvas, size, paint, scheme);
    }
    if (cosmeticIds.contains('ultimate')) {
      _drawUltimateFront(canvas, size, paint, scheme);
    }
  }

  void _drawHalo(
    Canvas canvas,
    Size size,
    Paint paint,
    _CosmeticScheme scheme,
  ) {
    final s = size.width;
    final center = Offset(s * .5, s * (petId == 'fifi' ? .5 : .52));
    final glow = .54 + sin(pulse * 2 * pi) * .24;
    final orbit = Rect.fromCenter(
      center: center,
      width: s * .92,
      height: s * .64,
    );

    paint
      ..shader = RadialGradient(
        colors: [
          scheme.glow.withValues(alpha: .22 + glow * .16),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: s * .55))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, s * .54, paint);
    paint.shader = null;

    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * .018
      ..color = scheme.glow.withValues(alpha: .55 + glow * .25);
    canvas.drawOval(orbit, paint);

    final start = pulse * 2 * pi;
    paint
      ..strokeWidth = s * .032
      ..color = scheme.gold.withValues(alpha: .88);
    canvas.drawArc(orbit.inflate(s * .02), start, pi * .42, false, paint);
    canvas.drawArc(
      orbit.inflate(s * .02),
      start + pi * 1.08,
      pi * .42,
      false,
      paint,
    );

    for (var i = 0; i < 7; i++) {
      final angle = start + i * 2 * pi / 7;
      final p = Offset(
        center.dx + cos(angle) * orbit.width * .5,
        center.dy + sin(angle) * orbit.height * .5,
      );
      _drawMotif(canvas, p, s * (i.isEven ? .035 : .026), scheme, i);
    }
  }

  void _drawCape(
    Canvas canvas,
    Size size,
    Paint paint,
    _CosmeticScheme scheme,
  ) {
    final s = size.width;
    final top = petId.startsWith('magic_') ? .49 : .51;
    final cape = Path()
      ..moveTo(s * .28, s * top)
      ..cubicTo(s * .13, s * .65, s * .17, s * .86, s * .31, s * .97)
      ..quadraticBezierTo(s * .5, s * .89, s * .69, s * .97)
      ..cubicTo(s * .83, s * .86, s * .87, s * .65, s * .72, s * top)
      ..quadraticBezierTo(
        s * .5,
        s * (.58 + sin(pulse * 2 * pi) * .015),
        s * .28,
        s * top,
      )
      ..close();
    final capeBounds = Rect.fromLTWH(s * .14, s * .46, s * .72, s * .52);

    paint
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          scheme.secondary.withValues(alpha: .92),
          scheme.primary.withValues(alpha: .78),
          scheme.glow.withValues(alpha: .32),
        ],
      ).createShader(capeBounds)
      ..style = PaintingStyle.fill;
    canvas.drawPath(cape, paint);
    paint.shader = null;

    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * .026
      ..color = scheme.gold.withValues(alpha: .9);
    canvas.drawPath(cape, paint);

    paint
      ..strokeWidth = s * .012
      ..color = Colors.white.withValues(alpha: .42);
    canvas.drawLine(Offset(s * .36, s * .61), Offset(s * .31, s * .9), paint);
    canvas.drawLine(Offset(s * .64, s * .61), Offset(s * .69, s * .9), paint);
    _drawMotif(canvas, Offset(s * .5, s * .77), s * .04, scheme, 0);
  }

  void _drawHat(Canvas canvas, Size size, Paint paint, _CosmeticScheme scheme) {
    final s = size.width;
    final center = switch (petId) {
      'fifi' => Offset(s * .47, s * .23),
      'magic_moon' => Offset(s * .53, s * .18),
      'magic_flower' => Offset(s * .5, s * .17),
      _ => Offset(s * .5, s * .19),
    };

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(petId == 'fifi' ? -.18 : .08);
    paint
      ..shader =
          LinearGradient(
            colors: [scheme.gold, scheme.accent, scheme.secondary],
          ).createShader(
            Rect.fromCenter(
              center: Offset.zero,
              width: s * .44,
              height: s * .24,
            ),
          )
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: s * .38, height: s * .14),
        Radius.circular(s * .07),
      ),
      paint,
    );
    paint.shader = null;

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .012
      ..color = Colors.white.withValues(alpha: .72);
    canvas.drawArc(
      Rect.fromCenter(center: Offset.zero, width: s * .32, height: s * .1),
      pi * 1.08,
      pi * .58,
      false,
      paint,
    );

    paint
      ..style = PaintingStyle.fill
      ..color = scheme.primary.withValues(alpha: .95);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(s * .03, s * .055),
          width: s * .46,
          height: s * .055,
        ),
        Radius.circular(s * .028),
      ),
      paint,
    );
    _drawMotif(canvas, Offset(s * .14, -s * .025), s * .035, scheme, 1);
    canvas.restore();
  }

  void _drawSatchel(
    Canvas canvas,
    Size size,
    Paint paint,
    _CosmeticScheme scheme,
  ) {
    final s = size.width;
    final strapStart = petId.startsWith('magic_')
        ? Offset(s * .34, s * .43)
        : Offset(s * .34, s * .48);
    final strapEnd = petId.startsWith('magic_')
        ? Offset(s * .7, s * .72)
        : Offset(s * .7, s * .77);

    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * .03
      ..color = scheme.gold.withValues(alpha: .74);
    canvas.drawLine(strapStart, strapEnd, paint);
    paint
      ..strokeWidth = s * .013
      ..color = Colors.white.withValues(alpha: .45);
    canvas.drawLine(
      strapStart + Offset(s * .018, 0),
      strapEnd + Offset(s * .018, 0),
      paint,
    );

    final bag = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(s * .72, s * (petId.startsWith('magic_') ? .68 : .72)),
        width: s * .22,
        height: s * .19,
      ),
      Radius.circular(s * .045),
    );
    paint
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.secondary,
          scheme.primary.withValues(alpha: .92),
          scheme.gold.withValues(alpha: .72),
        ],
      ).createShader(bag.outerRect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bag, paint);
    paint.shader = null;

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .012
      ..color = Colors.white.withValues(alpha: .58);
    canvas.drawRRect(bag.deflate(s * .012), paint);
    _drawMotif(canvas, bag.outerRect.center, s * .035, scheme, 2);
  }

  void _drawCrown(
    Canvas canvas,
    Size size,
    Paint paint,
    _CosmeticScheme scheme,
  ) {
    final s = size.width;
    final y = switch (petId) {
      'fifi' => s * .17,
      'magic_moon' => s * .1,
      'magic_flower' => s * .09,
      _ => s * .12,
    };
    final centerX = petId == 'fifi' ? s * .53 : s * .5;
    final crown = Path()
      ..moveTo(centerX - s * .2, y + s * .095)
      ..lineTo(centerX - s * .145, y + s * .005)
      ..lineTo(centerX - s * .06, y + s * .075)
      ..lineTo(centerX, y - s * .035)
      ..lineTo(centerX + s * .06, y + s * .075)
      ..lineTo(centerX + s * .145, y + s * .005)
      ..lineTo(centerX + s * .2, y + s * .095)
      ..quadraticBezierTo(centerX, y + s * .15, centerX - s * .2, y + s * .095)
      ..close();

    paint
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: .98),
              scheme.gold,
              const Color(0xFFFFA726),
            ],
          ).createShader(
            Rect.fromCenter(
              center: Offset(centerX, y + s * .06),
              width: s * .45,
              height: s * .22,
            ),
          )
      ..style = PaintingStyle.fill;
    canvas.drawPath(crown, paint);
    paint.shader = null;

    paint
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = s * .011
      ..color = const Color(0xFFFFF3B0);
    canvas.drawPath(crown, paint);

    final jewels = [
      Offset(centerX - s * .13, y + s * .07),
      Offset(centerX, y + s * .045),
      Offset(centerX + s * .13, y + s * .07),
    ];
    for (var i = 0; i < jewels.length; i++) {
      _drawGem(canvas, jewels[i], s * (i == 1 ? .033 : .024), scheme, i);
    }
  }

  void _drawUltimateBack(
    Canvas canvas,
    Size size,
    Paint paint,
    _CosmeticScheme scheme,
  ) {
    final s = size.width;
    final center = Offset(s * .5, s * .52);
    final phase = pulse * 2 * pi;
    paint
      ..shader = RadialGradient(
        colors: [
          scheme.glow.withValues(alpha: .48),
          scheme.primary.withValues(alpha: .22),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: s * .66))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, s * .63, paint);
    paint.shader = null;

    for (var i = 0; i < 12; i++) {
      final angle = phase + i * 2 * pi / 12;
      final inner = Offset(
        center.dx + cos(angle) * s * .37,
        center.dy + sin(angle) * s * .34,
      );
      final outer = Offset(
        center.dx + cos(angle) * s * (.54 + .035 * sin(phase + i)),
        center.dy + sin(angle) * s * (.5 + .025 * cos(phase + i)),
      );
      paint
        ..shader = null
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * .018
        ..color = (i.isEven ? scheme.gold : scheme.glow).withValues(alpha: .52);
      canvas.drawLine(inner, outer, paint);
    }

    switch (petId) {
      case 'fifi':
        _drawFoxFlames(canvas, size, paint, scheme);
      case 'magic_moon':
        _drawMoonAura(canvas, size, paint, scheme);
      case 'magic_flower':
        _drawPetalAura(canvas, size, paint, scheme);
      default:
        _drawStarAura(canvas, size, paint, scheme);
    }
  }

  void _drawUltimateFront(
    Canvas canvas,
    Size size,
    Paint paint,
    _CosmeticScheme scheme,
  ) {
    final s = size.width;
    final phase = pulse * 2 * pi;
    final emblem = Offset(s * .5, s * (petId.startsWith('magic_') ? .53 : .62));
    paint
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [Colors.white, scheme.glow, scheme.primary],
      ).createShader(Rect.fromCircle(center: emblem, radius: s * .065));
    canvas.drawCircle(emblem, s * .046, paint);
    paint.shader = null;
    _drawMotif(canvas, emblem, s * .035, scheme, 3);

    for (var i = 0; i < 5; i++) {
      final angle = phase + i * 2 * pi / 5;
      final p = Offset(
        s * .5 + cos(angle) * s * .39,
        s * .49 + sin(angle) * s * .39,
      );
      _drawMotif(canvas, p, s * .025, scheme, i);
    }
  }

  void _drawFoxFlames(
    Canvas canvas,
    Size size,
    Paint paint,
    _CosmeticScheme scheme,
  ) {
    final s = size.width;
    for (final data in [
      (Offset(s * .22, s * .72), s * .2, -.45),
      (Offset(s * .78, s * .72), s * .2, .45),
      (Offset(s * .5, s * .86), s * .24, 0.0),
    ]) {
      canvas.save();
      canvas.translate(data.$1.dx, data.$1.dy);
      canvas.rotate(data.$3 + sin(pulse * 2 * pi) * .04);
      final flame = Path()
        ..moveTo(0, -data.$2)
        ..cubicTo(
          data.$2 * .62,
          -data.$2 * .52,
          data.$2 * .48,
          data.$2 * .28,
          0,
          data.$2 * .48,
        )
        ..cubicTo(
          -data.$2 * .48,
          data.$2 * .28,
          -data.$2 * .62,
          -data.$2 * .52,
          0,
          -data.$2,
        )
        ..close();
      paint
        ..shader = RadialGradient(
          colors: [
            scheme.gold.withValues(alpha: .9),
            scheme.primary.withValues(alpha: .48),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: data.$2))
        ..style = PaintingStyle.fill;
      canvas.drawPath(flame, paint);
      paint.shader = null;
      canvas.restore();
    }
  }

  void _drawStarAura(
    Canvas canvas,
    Size size,
    Paint paint,
    _CosmeticScheme scheme,
  ) {
    final s = size.width;
    for (var i = 0; i < 8; i++) {
      final angle = pulse * 2 * pi + i * pi / 4;
      final p = Offset(
        s * .5 + cos(angle) * s * .5,
        s * .5 + sin(angle) * s * .44,
      );
      _drawStar(
        canvas,
        p,
        s * (i.isEven ? .047 : .034),
        scheme.gold.withValues(alpha: .86),
      );
    }
  }

  void _drawMoonAura(
    Canvas canvas,
    Size size,
    Paint paint,
    _CosmeticScheme scheme,
  ) {
    final s = size.width;
    for (var i = 0; i < 4; i++) {
      final p = Offset(s * (.22 + i * .19), s * (.2 + (i.isEven ? .1 : -.02)));
      _drawCrescent(canvas, p, s * .055, scheme);
    }
  }

  void _drawPetalAura(
    Canvas canvas,
    Size size,
    Paint paint,
    _CosmeticScheme scheme,
  ) {
    final s = size.width;
    final center = Offset(s * .5, s * .52);
    for (var i = 0; i < 10; i++) {
      final angle = pulse * 2 * pi * .35 + i * 2 * pi / 10;
      final p = Offset(
        center.dx + cos(angle) * s * .48,
        center.dy + sin(angle) * s * .43,
      );
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(angle);
      paint
        ..shader =
            LinearGradient(
              colors: [
                scheme.accent.withValues(alpha: .85),
                scheme.glow.withValues(alpha: .3),
              ],
            ).createShader(
              Rect.fromCenter(
                center: Offset.zero,
                width: s * .055,
                height: s * .11,
              ),
            )
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * .045, height: s * .1),
        paint,
      );
      paint.shader = null;
      canvas.restore();
    }
  }

  void _drawMotif(
    Canvas canvas,
    Offset center,
    double radius,
    _CosmeticScheme scheme,
    int index,
  ) {
    if (petId == 'magic_moon') {
      _drawCrescent(canvas, center, radius * 1.2, scheme);
    } else if (petId == 'magic_flower') {
      _drawFlower(canvas, center, radius, scheme);
    } else {
      _drawStar(
        canvas,
        center,
        radius,
        index.isEven ? scheme.gold : scheme.accent,
      );
    }
  }

  void _drawGem(
    Canvas canvas,
    Offset center,
    double radius,
    _CosmeticScheme scheme,
    int index,
  ) {
    final paint = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          index == 1 ? scheme.accent : scheme.glow,
          scheme.primary,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    final gem = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * .85, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * .85, center.dy)
      ..close();
    canvas.drawPath(gem, paint);
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..color = color;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? radius : radius * .45;
      final angle = -pi / 2 + i * pi / 5;
      final p = Offset(center.dx + cos(angle) * r, center.dy + sin(angle) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawCrescent(
    Canvas canvas,
    Offset center,
    double radius,
    _CosmeticScheme scheme,
  ) {
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * .42
      ..color = scheme.gold.withValues(alpha: .9);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi * .62,
      pi * 1.25,
      false,
      paint,
    );
  }

  void _drawFlower(
    Canvas canvas,
    Offset center,
    double radius,
    _CosmeticScheme scheme,
  ) {
    final paint = Paint()..isAntiAlias = true;
    for (var i = 0; i < 5; i++) {
      final angle = i * 2 * pi / 5;
      canvas.save();
      canvas.translate(
        center.dx + cos(angle) * radius * .42,
        center.dy + sin(angle) * radius * .42,
      );
      canvas.rotate(angle);
      paint
        ..style = PaintingStyle.fill
        ..color = (i.isEven ? scheme.accent : scheme.glow).withValues(
          alpha: .86,
        );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * .75,
          height: radius * 1.2,
        ),
        paint,
      );
      canvas.restore();
    }
    paint.color = scheme.gold;
    canvas.drawCircle(center, radius * .35, paint);
  }

  @override
  bool shouldRepaint(covariant _PetCosmeticPainter oldDelegate) {
    return oldDelegate.cosmeticIds != cosmeticIds ||
        oldDelegate.petId != petId ||
        oldDelegate.pulse != pulse ||
        oldDelegate.layer != layer;
  }

  _CosmeticScheme _cosmeticScheme(String petId) {
    return switch (petId) {
      'fifi' => const _CosmeticScheme(
        primary: Color(0xFFFF8C42),
        secondary: Color(0xFF8B5CF6),
        accent: Color(0xFFFFD166),
        glow: Color(0xFFFFE08A),
        gold: Color(0xFFFFC84D),
      ),
      'magic_star' => const _CosmeticScheme(
        primary: Color(0xFFFF5BA7),
        secondary: Color(0xFFB388FF),
        accent: Color(0xFFFFD166),
        glow: Color(0xFFFF80AB),
        gold: Color(0xFFFFD166),
      ),
      'magic_moon' => const _CosmeticScheme(
        primary: Color(0xFF5B3FD6),
        secondary: Color(0xFF1F2A68),
        accent: Color(0xFF7DD3FC),
        glow: Color(0xFFB388FF),
        gold: Color(0xFFFFD166),
      ),
      'magic_flower' => const _CosmeticScheme(
        primary: Color(0xFF34D399),
        secondary: Color(0xFF2DD4BF),
        accent: Color(0xFFFF80AB),
        glow: Color(0xFF99F6E4),
        gold: Color(0xFFFBBF24),
      ),
      _ => const _CosmeticScheme(
        primary: Color(0xFF42A5F5),
        secondary: Color(0xFF8B5CF6),
        accent: Color(0xFFFFD166),
        glow: Color(0xFFFFE08A),
        gold: Color(0xFFFFD700),
      ),
    };
  }
}

class _CosmeticScheme {
  const _CosmeticScheme({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.glow,
    required this.gold,
  });

  final Color primary;
  final Color secondary;
  final Color accent;
  final Color glow;
  final Color gold;
}

class _PetPainter extends CustomPainter {
  _PetPainter({
    required this.color,
    required this.petId,
    required this.cosmeticIds,
  });

  final Color color;
  final String petId;
  final Set<String> cosmeticIds;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()..isAntiAlias = true;
    final center = Offset(s * .5, s * .52);

    if (cosmeticIds.contains('halo')) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .035
        ..color = const Color(0xAAFFD166);
      canvas.drawCircle(center, s * .45, paint);
      paint.style = PaintingStyle.fill;
    }

    paint.color = color;
    if (petId == 'apollo') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: s * .66, height: s * .72),
          Radius.circular(s * .28),
        ),
        paint,
      );
      paint.color = Colors.white;
      canvas.drawCircle(Offset(s * .5, s * .42), s * .2, paint);
      paint.color = const Color(0xFFBEE9FF);
      canvas.drawCircle(Offset(s * .5, s * .42), s * .15, paint);
    } else {
      canvas.drawCircle(center, s * .34, paint);
      final ear = Path()
        ..moveTo(s * .28, s * .28)
        ..lineTo(s * .18, s * .08)
        ..lineTo(s * .42, s * .2)
        ..close()
        ..moveTo(s * .72, s * .28)
        ..lineTo(s * .82, s * .08)
        ..lineTo(s * .58, s * .2)
        ..close();
      canvas.drawPath(ear, paint);
    }

    if (petId == 'dino') {
      paint.color = const Color(0xFF2E7D32);
      for (var i = 0; i < 4; i++) {
        final x = s * (.34 + i * .11);
        final spike = Path()
          ..moveTo(x, s * .16)
          ..lineTo(x + s * .05, s * .03)
          ..lineTo(x + s * .1, s * .16)
          ..close();
        canvas.drawPath(spike, paint);
      }
    }

    if (cosmeticIds.contains('hat')) {
      paint.color = const Color(0xFFFFD166);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(s * .5, s * .24),
          width: s * .44,
          height: s * .18,
        ),
        pi,
        pi,
        false,
        paint,
      );
    }

    paint.color = Colors.white;
    canvas.drawCircle(Offset(s * .39, s * .47), s * .065, paint);
    canvas.drawCircle(Offset(s * .61, s * .47), s * .065, paint);
    paint.color = const Color(0xFF2D2A32);
    canvas.drawCircle(Offset(s * .4, s * .48), s * .03, paint);
    canvas.drawCircle(Offset(s * .6, s * .48), s * .03, paint);

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * .025
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2D2A32);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(s * .5, s * .61),
        width: s * .22,
        height: s * .12,
      ),
      0,
      pi,
      false,
      paint,
    );
    paint.style = PaintingStyle.fill;

    if (cosmeticIds.contains('backpack')) {
      paint.color = const Color(0xFF42A5F5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * .68, s * .52, s * .18, s * .22),
          Radius.circular(s * .04),
        ),
        paint,
      );
    }
    if (cosmeticIds.contains('ultimate')) {
      paint.color = const Color(0x66FFFFFF);
      canvas.drawCircle(Offset(s * .3, s * .3), s * .04, paint);
      canvas.drawCircle(Offset(s * .72, s * .72), s * .035, paint);
      canvas.drawCircle(Offset(s * .22, s * .68), s * .025, paint);
    }
    if (cosmeticIds.contains('cape')) {
      paint.color = const Color(0xCCEF4444);
      canvas.drawOval(Rect.fromLTWH(s * .25, s * .72, s * .5, s * .18), paint);
    }
    if (cosmeticIds.contains('crown')) {
      paint.color = const Color(0xFFFFD700);
      canvas.drawRect(Rect.fromLTWH(s * .36, s * .15, s * .28, s * .08), paint);
      canvas.drawCircle(Offset(s * .4, s * .13), s * .035, paint);
      canvas.drawCircle(Offset(s * .5, s * .1), s * .04, paint);
      canvas.drawCircle(Offset(s * .6, s * .13), s * .035, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PetPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.petId != petId ||
        oldDelegate.cosmeticIds != cosmeticIds;
  }
}
