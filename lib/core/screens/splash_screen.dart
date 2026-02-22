import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/geo_theme.dart';
import '../../features/auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final AnimationController _fadeCtrl;
  late final AnimationController _scaleCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _slideAnim;

  bool _minimumElapsed = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _scaleAnim = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut),
    );

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _slideAnim = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic),
    );

    // Minimum splash display time.
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _minimumElapsed = true);
      _maybeNavigate();
    });
  }

  // Called when minimum time passes OR when auth state settles.
  void _maybeNavigate() {
    if (!mounted || !_minimumElapsed) return;
    final authState = ref.read(authProvider);
    if (authState.isLoading) return; // wait for auth to finish
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    context.go('/');
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _fadeCtrl.dispose();
    _scaleCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When auth finishes loading, attempt to navigate (if minimum time passed).
    ref.listen<AuthState>(authProvider, (_, next) {
      if (!next.isLoading) _maybeNavigate();
    });

    return Scaffold(
      body: AnimatedBuilder(
        animation: _animCtrl,
        builder: (_, __) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Geometric background ────────────────────────────────────
              CustomPaint(painter: GeoBackgroundPainter(_animCtrl.value)),

              // ── Content ─────────────────────────────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // ── Glowing logo ───────────────────────────────────────
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: ScaleTransition(
                        scale: _scaleAnim,
                        child: Column(
                          children: [
                            // Outer glow ring
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [kGeoAccent1, kGeoAccent2],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: kGeoAccent1.withValues(alpha: 0.45),
                                    blurRadius: 40,
                                    spreadRadius: 8,
                                  ),
                                  BoxShadow(
                                    color: kGeoAccent2.withValues(alpha: 0.30),
                                    blurRadius: 60,
                                    spreadRadius: -4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.wifi_rounded,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // ── App name ────────────────────────────────────
                            AnimatedBuilder(
                              animation: _slideAnim,
                              builder: (_, __) => Transform.translate(
                                offset: Offset(0, _slideAnim.value),
                                child: const Text(
                                  'ViorNet',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // ── Tagline as glass pill ───────────────────────
                            ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.20),
                                    ),
                                  ),
                                  child: Text(
                                    'WiFi Reseller & ISP Management',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          Colors.white.withValues(alpha: 0.80),
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // ── Loading indicator ──────────────────────────────────
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(
                                kGeoAccent1.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Initialising…',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.45),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // ── Footer ────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 36),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          children: [
                            Text(
                              'developed & maintained by',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.35),
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [kGeoAccent1, kGeoAccent3],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ).createShader(bounds),
                              child: const Text(
                                'PRITECHVIOR',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 3.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Pritech Vior Softech',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withValues(alpha: 0.30),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
