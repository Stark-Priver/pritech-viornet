import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/geo_theme.dart';

// ─── Dialog type presets ─────────────────────────────────────────────────────

enum GlassDialogType { error, warning, info, success }

extension _GlassDialogTypeX on GlassDialogType {
  IconData get icon => switch (this) {
        GlassDialogType.error => Icons.lock_outline_rounded,
        GlassDialogType.warning => Icons.warning_amber_rounded,
        GlassDialogType.info => Icons.info_outline_rounded,
        GlassDialogType.success => Icons.check_circle_outline_rounded,
      };

  Color get baseColor => switch (this) {
        GlassDialogType.error => const Color(0xFFFF4D4D),
        GlassDialogType.warning => const Color(0xFFFFAA00),
        GlassDialogType.info => kGeoAccent1,
        GlassDialogType.success => const Color(0xFF00E5A0),
      };

  Color get accentColor => switch (this) {
        GlassDialogType.error => const Color(0xFFFF6B6B),
        GlassDialogType.warning => const Color(0xFFFFCC55),
        GlassDialogType.info => kGeoAccent3,
        GlassDialogType.success => const Color(0xFF00FFB3),
      };

  List<Color> get dividerGradient => switch (this) {
        GlassDialogType.error => [
            const Color(0xFFFF6B6B),
            const Color(0xFFFF4D9A)
          ],
        GlassDialogType.warning => [
            const Color(0xFFFFAA00),
            const Color(0xFFFFCC55)
          ],
        GlassDialogType.info => [kGeoAccent1, kGeoAccent3],
        GlassDialogType.success => [const Color(0xFF00E5A0), kGeoAccent1],
      };
}

// ─── Reusable Glass Alert Dialog ─────────────────────────────────────────────

/// A glassmorphism-styled alert dialog that matches the app's geometric theme.
///
/// Usage:
/// ```dart
/// showGlassAlertDialog(
///   context: context,
///   type: GlassDialogType.error,
///   title: 'Authentication Failed',
///   message: 'Invalid credentials.',
///   confirmLabel: 'Try Again',
///   onConfirm: () { /* clear password, etc. */ },
/// );
/// ```
class GlassAlertDialog extends StatelessWidget {
  const GlassAlertDialog({
    super.key,
    this.type = GlassDialogType.error,
    required this.title,
    required this.message,
    this.icon,
    this.iconColor,
    this.glowColor,
    this.dividerGradient,
    this.closeLabel = 'Close',
    this.confirmLabel,
    this.onConfirm,
  });

  final GlassDialogType type;
  final String title;
  final String message;

  /// Override the icon. Defaults to the type's preset icon.
  final IconData? icon;

  /// Override the icon + border colour. Defaults to the type's accent colour.
  final Color? iconColor;

  /// Override the glow shadow colour. Defaults to the type's base colour.
  final Color? glowColor;

  /// Override the short divider line gradient. Defaults to the type's gradient.
  final List<Color>? dividerGradient;

  /// Label for the dismiss button.
  final String closeLabel;

  /// Label for the action button. When null, only the close button is shown.
  final String? confirmLabel;

  /// Callback for the action button. Pops the dialog first, then invokes this.
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final effectiveIcon = icon ?? type.icon;
    final effectiveIconColor = iconColor ?? type.accentColor;
    final effectiveGlowColor = glowColor ?? type.baseColor;
    final effectiveGradient = dividerGradient ?? type.dividerGradient;

    return Dialog(
      backgroundColor: Colors.transparent,
      // Large horizontal inset keeps it well away from screen edges.
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
      child: ConstrainedBox(
        // Hard cap so it never exceeds a compact card width on large screens.
        constraints: const BoxConstraints(maxWidth: 320),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: effectiveGlowColor.withValues(alpha: 0.20),
                    blurRadius: 36,
                    spreadRadius: -6,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.40),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Icon row: small pill layout ────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: effectiveGlowColor.withValues(alpha: 0.12),
                          border: Border.all(
                            color: effectiveIconColor.withValues(alpha: 0.50),
                            width: 1.3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: effectiveGlowColor.withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(effectiveIcon,
                            color: effectiveIconColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Accent divider ──────────────────────────────────────
                  Container(
                    width: 36,
                    height: 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(colors: effectiveGradient),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Message ─────────────────────────────────────────────
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.68),
                      height: 1.5,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Buttons ─────────────────────────────────────────────
                  Row(
                    children: [
                      // Close / dismiss
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.20),
                                ),
                              ),
                            ),
                            child: Text(
                              closeLabel,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Confirm / action
                      if (confirmLabel != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: const LinearGradient(
                                  colors: [kGeoAccent1, kGeoAccent2],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: kGeoAccent1.withValues(alpha: 0.32),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  onConfirm?.call();
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  confirmLabel!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
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

// ─── Convenience function ─────────────────────────────────────────────────────

/// Shows a [GlassAlertDialog] without needing to call [showDialog] manually.
Future<void> showGlassAlertDialog({
  required BuildContext context,
  GlassDialogType type = GlassDialogType.error,
  required String title,
  required String message,
  IconData? icon,
  Color? iconColor,
  Color? glowColor,
  List<Color>? dividerGradient,
  String closeLabel = 'Close',
  String? confirmLabel,
  VoidCallback? onConfirm,
}) =>
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => GlassAlertDialog(
        type: type,
        title: title,
        message: message,
        icon: icon,
        iconColor: iconColor,
        glowColor: glowColor,
        dividerGradient: dividerGradient,
        closeLabel: closeLabel,
        confirmLabel: confirmLabel,
        onConfirm: onConfirm,
      ),
    );
