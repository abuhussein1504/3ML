import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/user_profile.dart';

class PaydayCircleWidget extends StatefulWidget {
  final UserProfile profile;
  final double remaining;
  final double budget;
  final String currency;

  const PaydayCircleWidget({
    super.key,
    required this.profile,
    required this.remaining,
    required this.budget,
    required this.currency,
  });

  @override
  State<PaydayCircleWidget> createState() => _PaydayCircleWidgetState();
}

class _PaydayCircleWidgetState extends State<PaydayCircleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scaleAnim = Tween(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalDays = widget.profile.totalDaysInPeriod;
    final daysLeft = widget.profile.daysUntilPayday;
    final daysPassed = (totalDays - daysLeft).clamp(0, totalDays);
    final nextPayday = widget.profile.nextPayday;

    return Container(
      decoration: AppTheme.glassCard(context, radius: 24),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Circle visualization
          ScaleTransition(
            scale: _scaleAnim,
            child: SizedBox(
              width: 130,
              height: 130,
              child: CustomPaint(
                painter: _CirclePainter(
                  totalDays: totalDays,
                  daysPassed: daysPassed,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$daysLeft',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: context.appColors.textPrimary,
                          height: 1,
                        ),
                      ),
                      Text(
                        'days',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Info column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Until Payday'.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appColors.textMuted,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d').format(nextPayday),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.appColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  label: 'Budget',
                  value:
                      '${widget.currency} ${_fmtK(widget.budget)}',
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Remaining',
                  value:
                      '${widget.currency} ${_fmtK(widget.remaining)}',
                  color: widget.remaining >= 0
                      ? context.appColors.textPrimary
                      : AppTheme.danger,
                ),
                const SizedBox(height: 8),
                // Mini progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: widget.budget > 0
                        ? ((widget.budget - widget.remaining) / widget.budget)
                            .clamp(0.0, 1.0)
                        : 0.0,
                    backgroundColor: context.appColors.bgCardAlt,
                    valueColor: AlwaysStoppedAnimation(
                      widget.remaining >= 0
                          ? AppTheme.primary
                          : AppTheme.danger,
                    ),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtK(double v) {
    if (v.abs() >= 1000) {
      return '${(v / 1000).toStringAsFixed(1)}k';
    }
    return v.toStringAsFixed(0);
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12, color: context.appColors.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

class _CirclePainter extends CustomPainter {
  final int totalDays;
  final int daysPassed;

  _CirclePainter({required this.totalDays, required this.daysPassed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const dotRadius = 4.0;

    final total = totalDays.clamp(1, 31);

    for (int i = 0; i < total; i++) {
      final angle = (i / total) * 2 * pi - pi / 2;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);

      final isPast = i < daysPassed;
      final isToday = i == daysPassed;

      Color dotColor;
      double r = dotRadius;

      if (isPast) {
        dotColor = AppTheme.bgCardAlt;
      } else if (isToday) {
        dotColor = AppTheme.primary;
        r = 5.5;
      } else {
        // Color gradient for remaining days
        final fraction = (i - daysPassed) / (total - daysPassed).clamp(1, 31);
        dotColor = Color.lerp(
          AppTheme.primary,
          AppTheme.accent,
          fraction,
        )!;
      }

      final paint = Paint()
        ..color = dotColor
        ..style = PaintingStyle.fill;

      // Glow for today
      if (isToday) {
        final glowPaint = Paint()
          ..color = AppTheme.primary.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(Offset(x, y), r + 3, glowPaint);
      }

      canvas.drawCircle(Offset(x, y), r, paint);
    }

    // Inner ring
    final ringPaint = Paint()
      ..color = AppTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius - 12, ringPaint);
  }

  @override
  bool shouldRepaint(_CirclePainter oldDelegate) =>
      oldDelegate.totalDays != totalDays || oldDelegate.daysPassed != daysPassed;
}
