import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─── Shared colour palette ────────────────────────────────────────────────────
const kGeoBg1 = Color(0xFF0A0E27);
const kGeoBg2 = Color(0xFF0D1B3E);
const kGeoAccent1 = Color(0xFF00D4FF); // cyan
const kGeoAccent2 = Color(0xFF7B2FBE); // purple
const kGeoAccent3 = Color(0xFF00FFB3); // teal-green

// ─── Animated geometric background painter ───────────────────────────────────
/// [t] is the 0..1 animation value from a repeating AnimationController.
class GeoBackgroundPainter extends CustomPainter {
  final double t;

  const GeoBackgroundPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Gradient fill
    final bgRect = Offset.zero & size;
    canvas.drawRect(
      bgRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kGeoBg1, kGeoBg2, Color(0xFF12102A)],
        ).createShader(bgRect),
    );

    // ── Floating orbs ─────────────────────────────────────────────────────
    _drawOrb(
        canvas,
        Offset(w * 0.15, h * 0.18 + math.sin(t * math.pi * 2) * 18),
        w * 0.38,
        kGeoAccent2.withValues(alpha: 0.18));
    _drawOrb(
        canvas,
        Offset(w * 0.82, h * 0.72 + math.cos(t * math.pi * 2) * 22),
        w * 0.42,
        kGeoAccent1.withValues(alpha: 0.14));
    _drawOrb(
        canvas,
        Offset(w * 0.55, h * 0.1 + math.sin(t * math.pi * 2 + 1) * 14),
        w * 0.22,
        kGeoAccent3.withValues(alpha: 0.12));
    _drawOrb(
        canvas,
        Offset(w * 0.08, h * 0.85 + math.cos(t * math.pi * 2 + 2) * 16),
        w * 0.30,
        kGeoAccent1.withValues(alpha: 0.10));

    // ── Grid lines ────────────────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    const step = 48.0;
    for (double x = 0; x < w; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 0; y < h; y += step) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // ── Diagonal sweep lines ──────────────────────────────────────────────
    final linePaint = Paint()
      ..color = kGeoAccent1.withValues(alpha: 0.08)
      ..strokeWidth = 1.2;
    for (int i = -4; i < 12; i++) {
      final offset = i * 80.0 + (t * 80);
      canvas.drawLine(
          Offset(offset, 0), Offset(offset + h * 0.6, h), linePaint);
    }

    // ── Double-ring hexagons ──────────────────────────────────────────────
    _drawHexRing(canvas, Offset(w * 0.88, h * 0.12), 44,
        kGeoAccent1.withValues(alpha: 0.18));
    _drawHexRing(canvas, Offset(w * 0.06, h * 0.60), 32,
        kGeoAccent2.withValues(alpha: 0.20));
    _drawHexRing(canvas, Offset(w * 0.72, h * 0.92), 52,
        kGeoAccent3.withValues(alpha: 0.14));

    // ── Corner triangles ──────────────────────────────────────────────────
    _drawTriangle(canvas, Offset.zero, Offset(w * 0.22, 0), Offset(0, h * 0.14),
        kGeoAccent1.withValues(alpha: 0.07));
    _drawTriangle(canvas, Offset(w, h), Offset(w * 0.78, h),
        Offset(w, h * 0.86), kGeoAccent2.withValues(alpha: 0.09));
  }

  void _drawOrb(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _drawHexRing(Canvas canvas, Offset center, double r, Color color) {
    for (final scale in [1.0, 0.6]) {
      final path = Path();
      for (int i = 0; i < 6; i++) {
        final angle = (math.pi / 3) * i - math.pi / 6;
        final x = center.dx + r * scale * math.cos(angle);
        final y = center.dy + r * scale * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = scale == 1.0 ? 1.5 : 0.8
            ..color =
                scale == 1.0 ? color : color.withValues(alpha: color.a * 0.6));
    }
  }

  void _drawTriangle(Canvas canvas, Offset a, Offset b, Offset c, Color color) {
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(GeoBackgroundPainter old) => old.t != t;
}
