import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../services/budget_service.dart';
import '../models/user_profile.dart';
import '../providers/app_provider.dart';

class SafeToSpendCard extends StatelessWidget {
  final BudgetResult budget;
  final UserProfile profile;

  const SafeToSpendCard({
    super.key,
    required this.budget,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isHealthy = budget.isHealthy;
    final mainColor = isHealthy ? AppTheme.primary : AppTheme.danger;
    final currency = profile.currency;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final bufferAmt = provider.buffer.amount;

        return GestureDetector(
      onTap: () => _showJustification(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isHealthy
                ? [
                    const Color(0xFF00D4A1)
                        .withValues(alpha: isDark ? 0.15 : 0.12),
                    isDark ? const Color(0xFF141D35) : const Color(0xFFFFFFFF),
                  ]
                : [
                    const Color(0xFFFF5252)
                        .withValues(alpha: isDark ? 0.15 : 0.10),
                    isDark ? const Color(0xFF141D35) : const Color(0xFFFFFFFF),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: mainColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: mainColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isHealthy
                              ? Icons.check_circle_outline_rounded
                              : Icons.warning_amber_rounded,
                          color: mainColor,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isHealthy ? 'ON TRACK' : 'OVER BUDGET',
                          style: TextStyle(
                            color: mainColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'TAP TO JUSTIFY',
                    style: TextStyle(
                      color: mainColor.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.info_outline_rounded,
                      color: mainColor.withValues(alpha: 0.6), size: 14),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Safe to Spend Today',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currency,
                      style: TextStyle(
                        color: mainColor.withValues(alpha: 0.7),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      budget.safeToSpend.abs().toStringAsFixed(2),
                      style: TextStyle(
                        color: mainColor,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Safety buffer row
              Row(
                children: [
                  Icon(
                    budget.safetyBuffer >= 0
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: budget.safetyBuffer >= 0
                        ? AppTheme.primary
                        : AppTheme.danger,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      budget.safetyBuffer >= 0
                          ? '$currency ${budget.safetyBuffer.abs().toStringAsFixed(2)} above daily average'
                          : '$currency ${budget.safetyBuffer.abs().toStringAsFixed(2)} below daily average',
                      style: TextStyle(
                        color: budget.safetyBuffer >= 0
                            ? c.textSecondary
                            : AppTheme.danger.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              // Buffer row — not part of safe-to-spend pacing (see [BudgetService.calculate]).
              const SizedBox(height: 12),
              _BufferRow(
                bufferAmount: bufferAmt,
                currency: currency,
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }

  void _showJustification(BuildContext context) {
    final c = context.appColors;
    final lines = BudgetService.justify(
      profile,
      budget,
      bufferAmount: context.read<AppProvider>().buffer.amount,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: c.bgSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: c.border),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, sc) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    'How We Calculated This',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'FORMULA',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                controller: sc,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: lines.length,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (_, i) {
                  final line = lines[i];
                  if (line.label.startsWith('━')) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: c.border, height: 1),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            line.label,
                            style: TextStyle(
                              color:
                                  line.bold ? c.textPrimary : c.textSecondary,
                              fontSize: line.bold ? 15 : 14,
                              fontWeight:
                                  line.bold ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (line.value.isNotEmpty)
                          Flexible(
                            child: Text(
                              line.value,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: line.bold
                                    ? AppTheme.primary
                                    : c.textSecondary,
                                fontSize: line.bold ? 16 : 14,
                                fontWeight: line.bold
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 3,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Buffer Row widget ──────────────────────────────────────────
class _BufferRow extends StatelessWidget {
  final double bufferAmount;
  final String currency;

  const _BufferRow({required this.bufferAmount, required this.currency});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: () => _showEditBuffer(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Text('🏦', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buffer (unspent daily + your edits)',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    bufferAmount > 0
                        ? '$currency ${bufferAmount.toStringAsFixed(2)}'
                        : 'None accumulated yet',
                    style: const TextStyle(
                      color: Color(0xFF6C63FF),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'EDIT',
                style: TextStyle(
                  color: Color(0xFF6C63FF),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBuffer(BuildContext context) {
    final provider = context.read<AppProvider>();
    final c = context.appColors;
    final ctrl = TextEditingController(
      text: bufferAmount > 0 ? bufferAmount.toStringAsFixed(2) : '',
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: c.bgSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🏦', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text(
                  'Edit Buffer Amount',
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Buffer holds money that did not count as spent against your daily '
              'pace (including amounts moved here automatically at day change, and '
              'anything you set manually). It is never added to safe-to-spend — '
              'only you change this when you move money in or out.',
              style:
                  TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: c.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Buffer Amount',
                prefixText: '$currency  ',
                prefixStyle: TextStyle(color: c.textMuted),
                hintText: '0.00',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await provider.updateBuffer(0);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                        side: BorderSide(
                            color: AppTheme.danger.withValues(alpha: 0.5))),
                    child: const Text('Reset to 0'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final val = double.tryParse(ctrl.text.trim());
                      if (val != null && val >= 0) {
                        await provider.updateBuffer(val);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
