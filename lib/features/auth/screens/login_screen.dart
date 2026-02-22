import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

// ─── Colour palette ──────────────────────────────────────────────────────────
const _kBg1 = Color(0xFF0A0E27);
const _kBg2 = Color(0xFF0D1B3E);
const _kAccent1 = Color(0xFF00D4FF); // cyan
const _kAccent2 = Color(0xFF7B2FBE); // purple
const _kAccent3 = Color(0xFF00FFB3); // teal-green

// ─── Geometric background painter ────────────────────────────────────────────
class _GeometricPainter extends CustomPainter {
  final double t; // 0..1 animation progress

  _GeometricPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Gradient background
    final bgRect = Offset.zero & size;
    canvas.drawRect(
      bgRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kBg1, _kBg2, Color(0xFF12102A)],
        ).createShader(bgRect),
    );

    // ── Floating orbs ──────────────────────────────────────────────────────
    _drawOrb(
        canvas,
        Offset(w * 0.15, h * 0.18 + math.sin(t * math.pi * 2) * 18),
        w * 0.38,
        _kAccent2.withValues(alpha: 0.18));
    _drawOrb(
        canvas,
        Offset(w * 0.82, h * 0.72 + math.cos(t * math.pi * 2) * 22),
        w * 0.42,
        _kAccent1.withValues(alpha: 0.14));
    _drawOrb(
        canvas,
        Offset(w * 0.55, h * 0.1 + math.sin(t * math.pi * 2 + 1) * 14),
        w * 0.22,
        _kAccent3.withValues(alpha: 0.12));
    _drawOrb(
        canvas,
        Offset(w * 0.08, h * 0.85 + math.cos(t * math.pi * 2 + 2) * 16),
        w * 0.3,
        _kAccent1.withValues(alpha: 0.10));

    // ── Grid lines ─────────────────────────────────────────────────────────
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

    // ── Diagonal accent lines ───────────────────────────────────────────────
    final linePaint = Paint()
      ..color = _kAccent1.withValues(alpha: 0.08)
      ..strokeWidth = 1.2;
    for (int i = -4; i < 12; i++) {
      final offset = i * 80.0 + (t * 80);
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset + h * 0.6, h),
        linePaint,
      );
    }

    // ── Hexagon ring decorations ────────────────────────────────────────────
    _drawHexRing(canvas, Offset(w * 0.88, h * 0.12), 44,
        _kAccent1.withValues(alpha: 0.18));
    _drawHexRing(canvas, Offset(w * 0.06, h * 0.6), 32,
        _kAccent2.withValues(alpha: 0.20));
    _drawHexRing(canvas, Offset(w * 0.72, h * 0.92), 52,
        _kAccent3.withValues(alpha: 0.14));

    // ── Corner accent triangles ─────────────────────────────────────────────
    _drawTriangle(canvas, Offset(0, 0), Offset(w * 0.22, 0),
        Offset(0, h * 0.14), _kAccent1.withValues(alpha: 0.07));
    _drawTriangle(canvas, Offset(w, h), Offset(w * 0.78, h),
        Offset(w, h * 0.86), _kAccent2.withValues(alpha: 0.09));
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
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
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
          ..strokeWidth = 1.5
          ..color = color);
    // inner ring
    final path2 = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6;
      final x = center.dx + (r * 0.6) * math.cos(angle);
      final y = center.dy + (r * 0.6) * math.sin(angle);
      if (i == 0) {
        path2.moveTo(x, y);
      } else {
        path2.lineTo(x, y);
      }
    }
    path2.close();
    canvas.drawPath(
        path2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = color.withValues(alpha: color.a * 0.6));
  }

  void _drawTriangle(Canvas canvas, Offset a, Offset b, Offset c, Color color) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GeometricPainter old) => old.t != t;
}

// ─── Login Screen ─────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final success = await ref
          .read(authProvider.notifier)
          .login(_emailController.text.trim(), _passwordController.text);
      if (success && mounted) context.go('/');
    }
  }

  // ── Glassmorphism input decoration ────────────────────────────────────────
  InputDecoration _glassInput(String label, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        prefixIcon: Icon(icon, color: _kAccent1.withValues(alpha: 0.8)),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.18), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kAccent1, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.red.withValues(alpha: 0.7), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.red.withValues(alpha: 0.9), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFF6B6B)),
      );

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _animCtrl,
        builder: (_, __) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Geometric background ──────────────────────────────────────
              CustomPaint(
                painter: _GeometricPainter(_animCtrl.value),
              ),

              // ── Scrollable form ───────────────────────────────────────────
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _kAccent2.withValues(alpha: 0.18),
                                  blurRadius: 40,
                                  spreadRadius: -4,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 40),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // ── Logo ─────────────────────────────────
                                  Center(
                                    child: Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [_kAccent1, _kAccent2],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _kAccent1.withValues(
                                                alpha: 0.4),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.wifi_rounded,
                                          size: 38, color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // ── Title ────────────────────────────────
                                  const Text(
                                    'ViorNet',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ISP Management System',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          Colors.white.withValues(alpha: 0.55),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 36),

                                  // ── Email ────────────────────────────────
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.text,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _glassInput('Email or Phone',
                                        Icons.person_outline_rounded),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Please enter your email or phone';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // ── Password ─────────────────────────────
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _glassInput(
                                      'Password',
                                      Icons.lock_outline_rounded,
                                      suffix: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: Colors.white
                                              .withValues(alpha: 0.55),
                                        ),
                                        onPressed: () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Please enter your password';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // ── Error ─────────────────────────────────
                                  if (authState.error != null)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.red.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.red
                                              .withValues(alpha: 0.45),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline,
                                              color: Color(0xFFFF6B6B),
                                              size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              authState.error!,
                                              style: const TextStyle(
                                                  color: Color(0xFFFF6B6B),
                                                  fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  const SizedBox(height: 8),

                                  // ── Login button ──────────────────────────
                                  SizedBox(
                                    height: 52,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        gradient: authState.isLoading
                                            ? null
                                            : const LinearGradient(
                                                colors: [_kAccent1, _kAccent2],
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                              ),
                                        boxShadow: authState.isLoading
                                            ? null
                                            : [
                                                BoxShadow(
                                                  color: _kAccent1.withValues(
                                                      alpha: 0.35),
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: authState.isLoading
                                            ? null
                                            : _handleLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                        child: authState.isLoading
                                            ? const SizedBox(
                                                height: 22,
                                                width: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  valueColor:
                                                      AlwaysStoppedAnimation(
                                                          Colors.white),
                                                ),
                                              )
                                            : const Text(
                                                'Sign In',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.8,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 28),

                                  // ── Divider ────────────────────────────────
                                  Row(
                                    children: [
                                      Expanded(
                                          child: Divider(
                                              color: Colors.white
                                                  .withValues(alpha: 0.15))),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text(
                                          '© 2026 Pritech Vior Softech',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white
                                                .withValues(alpha: 0.35),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                          child: Divider(
                                              color: Colors.white
                                                  .withValues(alpha: 0.15))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
