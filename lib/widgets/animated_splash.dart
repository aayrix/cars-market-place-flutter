import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../screens/main_shell.dart';

const Color kLogoGreen = Color(0xFF1FE06A);
const Color kLogoBg = Color(0xFF050608);

/// Loading screen:
/// 1) "a" draws itself   2) bubbles pop one by one   3) bubbles glide into place.
/// Use it as your splash/loading screen. Navigates to [MainShell] when done.
class AnimatedSplash extends StatefulWidget {
  const AnimatedSplash({super.key});

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  static const double _w = 690, _h = 470;

  static final List<_BubbleSpec> _specs = [
    _BubbleSpec(BubbleKind.group, const Rect.fromLTWH(125, 18, 115, 112),
        const Offset(-40, -70), -0.35),
    _BubbleSpec(BubbleKind.tire, const Rect.fromLTWH(440, 12, 120, 130),
        const Offset(50, -80), 0.40),
    _BubbleSpec(BubbleKind.map, const Rect.fromLTWH(22, 180, 108, 108),
        const Offset(-70, 50), -0.30),
    _BubbleSpec(BubbleKind.chat, const Rect.fromLTWH(555, 182, 117, 98),
        const Offset(70, 70), 0.35),
  ];

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _goHome());
      }
    });
    _c.forward();
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double t, double a, double b, [Curve curve = Curves.linear]) =>
      curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.8;
    return Scaffold(
      backgroundColor: kLogoBg,
      body: Center(
        child: SizedBox(
          width: width,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = _c.value;
              return FittedBox(
                child: SizedBox(
                  width: _w,
                  height: _h,
                  child: Stack(
                    children: [
                      // PHASE 1: the "a" draws from start
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _LetterPainter(
                            arch: _seg(t, 0.00, 0.18, Curves.easeInOut),
                            bowl: _seg(t, 0.15, 0.40, Curves.easeInOut),
                          ),
                        ),
                      ),
                      // PHASE 2 + 3: bubbles pop one by one, then align
                      for (int i = 0; i < _specs.length; i++)
                        _bubble(i, t),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _bubble(int i, double t) {
    final s = _specs[i];
    final start = 0.42 + i * 0.09; // one by one
    final pop = _seg(t, start, start + 0.12, Curves.elasticOut);
    final fade = _seg(t, start, start + 0.04);
    final align = _seg(t, 0.82, 1.0, Curves.easeInOutCubic); // align phase
    final dot = _seg(t, 0.86 + i * 0.025, 0.92 + i * 0.025, Curves.elasticOut);

    return Positioned(
      left: s.rect.left,
      top: s.rect.top,
      width: s.rect.width,
      height: s.rect.height,
      child: Opacity(
        opacity: fade,
        child: Transform.translate(
          offset: s.from * (1 - align),
          child: Transform.rotate(
            angle: s.rot * (1 - align),
            child: Transform.scale(
              scale: pop,
              child: CustomPaint(painter: _BubblePainter(s.kind, dot)),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubbleSpec {
  _BubbleSpec(this.kind, this.rect, this.from, this.rot);
  final BubbleKind kind;
  final Rect rect;
  final Offset from;
  final double rot;
}

class _LetterPainter extends CustomPainter {
  _LetterPainter({required this.arch, required this.bowl});
  final double arch, bowl;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(135, 115);

    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter;

    final archPath = Path()
      ..moveTo(75, 125)
      ..cubicTo(75, 70, 130, 42, 195, 42)
      ..cubicTo(260, 42, 292, 80, 292, 125)
      ..lineTo(292, 340);
    white.strokeWidth = 66;
    for (final m in archPath.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * arch), white);
    }

    final bowlPath = Path()
      ..moveTo(292, 292)
      ..cubicTo(270, 312, 220, 310, 160, 310)
      ..cubicTo(90, 310, 42, 270, 42, 225)
      ..cubicTo(42, 180, 85, 152, 150, 152)
      ..cubicTo(210, 152, 250, 158, 300, 166)
      ..cubicTo(350, 175, 385, 205, 412, 248);

    final seg = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final m in bowlPath.computeMetrics()) {
      final end = m.length * bowl;
      for (double d = 0; d < end; d += 3) {
        final p = d / m.length;
        double w;
        if (p < 0.5) {
          w = 62;
        } else if (p < 0.68) {
          w = _lerp(62, 40, (p - 0.5) / 0.18);
        } else {
          w = _lerp(40, 4, Curves.easeIn.transform((p - 0.68) / 0.32));
        }
        seg.strokeWidth = w;
        final a = m.getTangentForOffset(d)!.position;
        final b = m.getTangentForOffset(math.min(d + 3.5, end))!.position;
        canvas.drawLine(a, b, seg);
      }
    }
    canvas.restore();
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0, 1);

  @override
  bool shouldRepaint(_LetterPainter old) =>
      old.arch != arch || old.bowl != bowl;
}

enum BubbleKind { group, tire, map, chat }

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.kind, this.dotT);
  final BubbleKind kind;
  final double dotT;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final green = Paint()..color = kLogoGreen;
    final white = Paint()..color = Colors.white;
    final black = Paint()..color = kLogoBg;

    final isCircle = kind == BubbleKind.tire || kind == BubbleKind.map;
    final bodyBottom = h - 22;
    late Rect body;
    late Offset c;
    late double r;

    final tail = Path()
      ..moveTo(w * 0.28, bodyBottom - 6)
      ..lineTo(w * 0.30, h)
      ..lineTo(w * 0.52, bodyBottom - 4)
      ..close();

    if (isCircle) {
      r = math.min(w - 14, bodyBottom - 8) / 2;
      c = Offset(w / 2 - 4, 8 + r);
      body = Rect.fromCircle(center: c, radius: r);
    } else {
      body = Rect.fromLTRB(0, 10, w - 4, bodyBottom);
      c = body.center;
      r = 0;
    }

    if (kind == BubbleKind.map) {
      final stroke = Paint()
        ..color = kLogoGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawCircle(c, r - 2, stroke);
      canvas.drawPath(tail, green);
    } else if (isCircle) {
      canvas.drawCircle(c, r, green);
      canvas.drawPath(tail, green);
    } else {
      canvas.drawRRect(
          RRect.fromRectAndRadius(body, const Radius.circular(26)), green);
      canvas.drawPath(tail, green);
    }

    switch (kind) {
      case BubbleKind.group:
        _person(canvas, white, c.dx - 26, c.dy + 4, 26);
        _person(canvas, white, c.dx + 26, c.dy + 4, 26);
        _person(canvas, white, c.dx, c.dy + 6, 34);
        break;
      case BubbleKind.chat:
        for (int i = -1; i <= 1; i++) {
          canvas.drawCircle(Offset(c.dx + i * 22, c.dy), 6.5, white);
        }
        break;
      case BubbleKind.tire:
        canvas.drawCircle(c, r * 0.74, black);
        final ring = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(c, r * 0.56, ring);
        canvas.drawCircle(c, r * 0.12, white);
        for (int i = 0; i < 5; i++) {
          final a = i * 2 * math.pi / 5 - math.pi / 2;
          canvas.drawLine(
            c + Offset(math.cos(a), math.sin(a)) * (r * 0.14),
            c + Offset(math.cos(a), math.sin(a)) * (r * 0.54),
            ring..strokeWidth = 4,
          );
        }
        break;
      case BubbleKind.map:
        _pakistan(canvas, green, c, r * 1.15);
        break;
    }

    if (dotT > 0) {
      final dc = Offset(w - 10, 12);
      canvas.drawCircle(dc, 16 * dotT, black);
      canvas.drawCircle(dc, 12 * dotT, green);
    }
  }

  void _person(Canvas canvas, Paint p, double cx, double cy, double s) {
    canvas.drawCircle(Offset(cx, cy - s * 0.30), s * 0.20, p);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(cx - s * 0.36, cy - s * 0.02, cx + s * 0.36, cy + s * 0.30),
        topLeft: Radius.circular(s * 0.3),
        topRight: Radius.circular(s * 0.3),
        bottomLeft: Radius.circular(s * 0.08),
        bottomRight: Radius.circular(s * 0.08),
      ),
      p,
    );
  }

  void _pakistan(Canvas canvas, Paint p, Offset c, double size) {
    const pts = [
      [0.46, 0.00], [0.62, 0.08], [0.58, 0.20], [0.74, 0.24], [0.86, 0.34],
      [0.72, 0.42], [0.78, 0.50], [0.66, 0.58], [0.60, 0.74], [0.66, 0.86],
      [0.50, 0.84], [0.42, 1.00], [0.30, 0.88], [0.38, 0.72], [0.22, 0.66],
      [0.00, 0.62], [0.06, 0.50], [0.24, 0.44], [0.18, 0.32], [0.34, 0.28],
      [0.36, 0.12],
    ];
    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      final x = c.dx + (pts[i][0] - 0.5) * size * 0.8;
      final y = c.dy + (pts[i][1] - 0.5) * size * 0.8;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.dotT != dotT;
}
