import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_theme.dart';
import '../../providers/app_provider.dart';
import '../../services/budget_service.dart';
import '../../widgets/safe_to_spend_card.dart';
import '../../widgets/payday_circle.dart';
import '../../widgets/transaction_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showAllTransactions(BuildContext context, AppProvider _) {
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bgSecondary,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => Consumer<AppProvider>(
        builder: (_, live, __) {
          final list = live.transactions.where((t) => !t.isUnknown).toList();
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (_, ctrl) => Column(
              children: [
                const SizedBox(height: 8),
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: c.border,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text('All Transactions',
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text('${list.length} total',
                          style: TextStyle(color: c.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text('No transactions yet',
                          style: TextStyle(color: c.textSecondary)),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: ctrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      itemCount: list.length,
                      itemBuilder: (_, i) => TransactionTile(tx: list[i]),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final profile = provider.profile;
        final budget = provider.budget;

        if (profile == null || budget == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          );
        }

        final currency = profile.currency;
        final recent = provider.recentTransactions;

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: c.bgPrimary,
              floating: true,
              pinned: false,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hey, ${profile.name} 👋',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Your Budget',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: CircleAvatar(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                    radius: 20,
                    child: Text(
                      profile.name.isNotEmpty
                          ? profile.name[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeToSpendCard(budget: budget, profile: profile),

                    const SizedBox(height: 16),

                    _StatsRow(
                        budget: budget, currency: currency, profile: profile),

                    const SizedBox(height: 16),

                    PaydayCircleWidget(
                      profile: profile,
                      remaining: budget.remaining,
                      budget: budget.disposableIncome,
                      currency: currency,
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Transactions',
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (recent.isNotEmpty)
                          TextButton(
                            onPressed: () =>
                                _showAllTransactions(context, provider),
                            child: const Text('See All'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (recent.isEmpty)
                      _EmptyTransactions()
                    else
                      ...recent.map((tx) => TransactionTile(tx: tx)),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatsRow extends StatelessWidget {
  final BudgetResult budget;
  final String currency;
  final dynamic profile;
  const _StatsRow(
      {required this.budget, required this.currency, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatButton(
            label: 'Spent',
            shortValue: _fmtK(budget.totalSpent),
            icon: Icons.arrow_upward_rounded,
            iconColor: AppTheme.danger,
            currency: currency,
            onTap: () => _showDetail(
              context,
              title: 'Total Spent',
              icon: Icons.arrow_upward_rounded,
              iconColor: AppTheme.danger,
              rows: [
                _Row('This Period',
                    '$currency ${budget.totalSpent.toStringAsFixed(2)}'),
                _Row('% of Budget',
                    '${budget.percentSpent.toStringAsFixed(1)}%'),
                _Row('Remaining',
                    '$currency ${budget.remaining.toStringAsFixed(2)}'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatButton(
            label: 'Saved',
            shortValue: _fmtK(profile.savingsGoal as double),
            icon: Icons.savings_outlined,
            iconColor: AppTheme.accent,
            currency: currency,
            onTap: () => _showDetail(
              context,
              title: 'Savings',
              icon: Icons.savings_outlined,
              iconColor: AppTheme.accent,
              rows: [
                _Row('Monthly Savings Goal',
                    '$currency ${(profile.savingsGoal as double).toStringAsFixed(2)}'),
                _Row('Logged Savings This Period',
                    '$currency ${budget.totalSaved.toStringAsFixed(2)}'),              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatButton(
            label: 'Income',
            shortValue: _fmtK(budget.totalIncome),
            icon: Icons.arrow_downward_rounded,
            iconColor: AppTheme.primary,
            currency: currency,
            onTap: () => _showDetail(
              context,
              title: 'Income',
              icon: Icons.arrow_downward_rounded,
              iconColor: AppTheme.primary,
              rows: [
                _Row('Logged Income',
                    '$currency ${budget.totalIncome.toStringAsFixed(2)}'),
                _Row('Disposable Budget',
                    '$currency ${budget.disposableIncome.toStringAsFixed(2)}'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatButton(
            label: 'Spent %',
            shortValue: '${budget.percentSpent.toStringAsFixed(0)}%',
            icon: Icons.percent_rounded,
            iconColor:
                budget.percentSpent > 80 ? AppTheme.danger : AppTheme.warning,
            currency: currency,
            onTap: () => _showDetail(
              context,
              title: 'Budget Usage',
              icon: Icons.percent_rounded,
              iconColor:
                  budget.percentSpent > 80 ? AppTheme.danger : AppTheme.warning,
              rows: [
                _Row('Budget Used',
                    '${budget.percentSpent.toStringAsFixed(1)}%'),
                _Row('Healthy?', budget.isHealthy ? 'Yes' : 'Over budget'),
                _Row('Budget Left',
                    '$currency ${budget.remaining.toStringAsFixed(2)}'),
                _Row('Days Left', '${budget.daysRemaining}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _fmtK(double v) {
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  void _showDetail(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<_Row> rows,
  }) {
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: c.bgSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: c.border),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r.label,
                          style:
                              TextStyle(color: c.textSecondary, fontSize: 14)),
                      Text(r.value,
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _Row {
  final String label;
  final String value;
  const _Row(this.label, this.value);
}

class _StatButton extends StatelessWidget {
  final String label;
  final String shortValue;
  final IconData icon;
  final Color iconColor;
  final String currency;
  final VoidCallback onTap;

  const _StatButton({
    required this.label,
    required this.shortValue,
    required this.icon,
    required this.iconColor,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppTheme.glassCard(context, radius: 16),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 16),
                const Spacer(),
                Icon(Icons.expand_more_rounded, color: c.textMuted, size: 14),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                shortValue,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: c.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: AppTheme.glassCard(context, radius: 20),
      child: Column(
        children: [
          const Text('💬', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            'No transactions yet',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Head to Chat and log your first spend!',
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
