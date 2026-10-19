import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/route_paths.dart';
import '../../../core/security/device_id_service.dart';
import '../../../core/theme/app_colors.dart';

/// Cinema-themed splash screen with "Premia BY LUMINA" branding.
///
/// Pre-warms device registration and session security in the background while
/// running a cinematic entrance animation (fade-in, slow camera tracking,
/// atmospheric red projector glow pulse, and specular lens sheen).
///
/// After the display duration, resolves navigation to the marquee screen.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({
    super.key,
    this.displayDuration = const Duration(milliseconds: 3400),
  });

  /// Duration before the splash transitions to the main app.
  final Duration displayDuration;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  late final AnimationController _sheenController;
  late final Animation<double> _sheenAnimation;

  Timer? _navigationTimer;
  Timer? _sheenTimer;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    // 1. Pre-warm per-install device ID silently in the background so network
    //    requests during the user's first action already have it cached.
    _prewarmServices();

    // 2. Entrance animation: fade-in and subtle cinematic camera dolly.
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 1.06, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );

    // 3. Ambient atmospheric cinema glow pulse (projector / hall lighting).
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _glowAnimation = Tween<double>(begin: 0.18, end: 0.42).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    // 4. Subtle specular lens sheen across the Premia wordmark.
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _sheenAnimation = CurvedAnimation(
      parent: _sheenController,
      curve: Curves.easeInOutQuad,
    );

    // Start entrance and loop ambient atmospheric pulse.
    _entranceController.forward();
    _glowController.repeat(reverse: true);

    // Trigger the specular sheen once the logo is fully faded in.
    _sheenTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        _sheenController.forward();
      }
    });

    // Schedule navigation to destination.
    _navigationTimer = Timer(widget.displayDuration, () {
      if (mounted) _resolveDestination();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-cache the splash image to ensure instantaneous, stutter-free display.
    precacheImage(const AssetImage('assets/images/splash_screen.png'), context);
  }

  void _prewarmServices() {
    // Fire silently in background — no await needed.
    DeviceIdService().getOrCreate();
  }

  Future<void> _resolveDestination() async {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    _navigationTimer?.cancel();
    _sheenTimer?.cancel();

    // Gracefully navigate to the marquee screen.
    context.go(RoutePaths.marquee);
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _sheenTimer?.cancel();
    _entranceController.dispose();
    _glowController.dispose();
    _sheenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Allow user to tap anywhere to skip splash immediately.
        onTap: _resolveDestination,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _entranceController,
            _glowController,
            _sheenController,
          ]),
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Deep cinema black base
                    const ColoredBox(color: AppColors.background),

                    // Main splash artwork (theater seats, background, Premia logo)
                    Image.asset(
                      'assets/images/splash_screen.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),

                    // Atmospheric crimson projector glow
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.25, -0.55),
                          radius: 0.95,
                          colors: [
                            AppColors.primary.withValues(
                              alpha: _glowAnimation.value,
                            ),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),

                    // Cinematic specular sheen sweep over logo region
                    CustomPaint(
                      painter: _CinemaSheenPainter(
                        progress: _sheenAnimation.value,
                      ),
                      size: Size.infinite,
                    ),

                    // Soft vignette around edges for smooth blending on all screen sizes
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.3),
                          ],
                          stops: const [0.0, 0.15, 0.85, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Draws an elegant specular shimmer passing across the center branding area.
class _CinemaSheenPainter extends CustomPainter {
  const _CinemaSheenPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final width = size.width;
    final height = size.height;

    // Approximate center Y where the "Premia BY LUMINA" logo rests
    final centerY = height * 0.485;
    final bandHeight = height * 0.22;

    // Travel from left to right with a wide range for smooth entry and exit
    final sweepX = -width * 0.4 + progress * (width * 1.8);

    final rect = Rect.fromCenter(
      center: Offset(sweepX, centerY),
      width: width * 0.75,
      height: bandHeight,
    );

    final paint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = LinearGradient(
        begin: const Alignment(-0.8, -1.0),
        end: const Alignment(0.8, 1.0),
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.05),
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      ).createShader(rect);

    canvas.drawRect(
      Rect.fromLTWH(0, centerY - bandHeight / 2, width, bandHeight),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CinemaSheenPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
