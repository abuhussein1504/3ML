import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../app_theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/transaction_tile.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _touchedIndex = -1;
  String? _expandedCategory;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final budget = provider.budget;
        final profile = provider.profile;

        if (budget == null || profile == null) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary));
        }

        final currency = profile.currency;
        final allTx = provider.transactions.where((t) => t.isExpense).toList();

        final byCategory = Map.fromEntries(
          budget.byCategory.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)),
        );

        final catSvc = provider.categoryService;

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: context.appColors.bgPrimary,
              floating: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Where Money Goes',
                      style: TextStyle(
                          color: context.appColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  Text('Current pay period',
                      style: TextStyle(
                          color: context.appColors.textMuted, fontSize: 11)),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_rounded, color: AppTheme.primary),
                  onPressed: () => _showAddCategoryDialog(context, provider),
                  tooltip: 'Add category',
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: AppTheme.glassCard(context),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _SummaryCell(
                                label: 'Spent',
                                value: '$currency ${_fmtK(budget.totalSpent)}',
                                color: AppTheme.danger,
                              ),
                              _Divider(),
                              _SummaryCell(
                                label: 'Remaining',
                                value: '$currency ${_fmtK(budget.remaining)}',
                                color: budget.remaining >= 0
                                    ? AppTheme.primary
                                    : AppTheme.danger,
                              ),
                              _Divider(),
                              _SummaryCell(
                                label: 'Budget',
                                value:
                                    '$currency ${_fmtK(budget.disposableIncome)}',
                                color: context.appColors.textPrimary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${budget.percentSpent.toStringAsFixed(0)}% spent',
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12),
                                  ),
                                  Text(
                                    '${(100 - budget.percentSpent).clamp(0, 100).toStringAsFixed(0)}% remaining',
                                    style: const TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: (budget.percentSpent / 100)
                                      .clamp(0.0, 1.0),
                                  backgroundColor: context.appColors.bgCardAlt,
                                  valueColor: AlwaysStoppedAnimation(
                                    budget.percentSpent > 80
                                        ? AppTheme.danger
                                        : budget.percentSpent > 60
                                            ? AppTheme.warning
                                            : AppTheme.primary,
                                  ),
                                  minHeight: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (byCategory.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => _showFullBreakdownSheet(
                            context, provider, byCategory, currency),
                        child: Row(
                          children: [
                            Text(
                              'Spending Breakdown',
                              style: TextStyle(
                                color: context.appColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            const Text('See all',
                                style: TextStyle(
                                    color: AppTheme.primary, fontSize: 12)),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppTheme.primary, size: 16),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 220,
                        decoration: AppTheme.glassCard(context),
                        child: Row(
                          children: [
                            Expanded(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  PieChart(
                                    PieChartData(
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 55,
                                      sections: _buildPieSections(
                                        byCategory,
                                        budget.totalSpent,
                                        Theme.of(context).brightness ==
                                            Brightness.dark,
                                      ),
                                      pieTouchData: PieTouchData(
                                        touchCallback: (event, response) {
                                          if (!event
                                              .isInterestedForInteractions) {
                                            setState(() => _touchedIndex = -1);
                                            return;
                                          }
                                          setState(() {
                                            _touchedIndex = response
                                                    ?.touchedSection
                                                    ?.touchedSectionIndex ??
                                                -1;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  if (_touchedIndex >= 0 &&
                                      _touchedIndex <
                                          byCategory.keys.length) ...[
                                    IgnorePointer(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            catSvc.getDisplayName(
                                              byCategory.keys
                                                  .toList()[_touchedIndex],
                                            ),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color:
                                                  context.appColors.textPrimary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                  right: 16, top: 12, bottom: 12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: byCategory.entries
                                    .take(5)
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map((e) {
                                  final color = _pieColor(e.key);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        SizedBox(
                                          width: 80,
                                          child: Text(
                                            catSvc.getDisplayName(e.value.key),
                                            style: TextStyle(
                                              color: context
                                                  .appColors.textSecondary,
                                              fontSize: 11,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    Text(
                      'Category Details',
                      style: TextStyle(
                        color: context.appColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (byCategory.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        decoration: AppTheme.glassCard(context),
                        child: Column(
                          children: [
                            const Text('📭', style: TextStyle(fontSize: 36)),
                            const SizedBox(height: 8),
                            Text('No expenses this period',
                                style: TextStyle(
                                    color: context.appColors.textSecondary)),
                          ],
                        ),
                      )
                    else
                      ...byCategory.entries.map((entry) {
                        final catName = entry.key;
                        final amount = entry.value;
                        final pct = budget.totalSpent > 0
                            ? amount / budget.totalSpent * 100
                            : 0.0;
                        final catTxs = allTx
                            .where((t) => t.categoryName == catName)
                            .toList();
                        final isExpanded = _expandedCategory == catName;
                        final displayName = catSvc.getDisplayName(catName);

                        return Column(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _expandedCategory =
                                  isExpanded ? null : catName),
                              child: Container(
                                decoration:
                                    AppTheme.glassCard(context, radius: 16),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: context.appColors.bgCardAlt,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            catSvc.iconFor(catName),
                                            style:
                                                const TextStyle(fontSize: 18),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    displayName,
                                                    style: TextStyle(
                                                      color: context.appColors
                                                          .textPrimary,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _showRenameCategoryDialog(
                                                      context,
                                                      provider,
                                                      catName,
                                                      displayName,
                                                    ),
                                                    child: const Icon(
                                                      Icons.edit_outlined,
                                                      size: 14,
                                                      color: AppTheme.textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                '${catTxs.length} transaction${catTxs.length != 1 ? 's' : ''}',
                                                style: TextStyle(
                                                  color: context
                                                      .appColors.textMuted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '$currency ${amount.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              '${pct.toStringAsFixed(0)}%',
                                              style: const TextStyle(
                                                color: AppTheme.textMuted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          isExpanded
                                              ? Icons.expand_less_rounded
                                              : Icons.expand_more_rounded,
                                          color: AppTheme.textMuted,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    // Mini progress bar
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: pct / 100,
                                        backgroundColor: AppTheme.bgCardAlt,
                                        valueColor:
                                            const AlwaysStoppedAnimation(
                                                AppTheme.primary),
                                        minHeight: 4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 12, top: 4),
                                child: Column(
                                  children: catTxs
                                      .map((tx) => TransactionTile(
                                            tx: tx,
                                            showCategory: false,
                                          ))
                                      .toList(),
                                ),
                              ),
                            const SizedBox(height: 10),
                          ],
                        );
                      }),

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

  List<PieChartSectionData> _buildPieSections(
    Map<String, double> data,
    double total,
    bool isDarkTheme,
  ) {
    final labelColor =
        isDarkTheme ? Colors.white : const Color(0xFF1A1F36);
    return data.entries.toList().asMap().entries.map((e) {
      final pct = total > 0 ? e.value.value / total * 100 : 0.0;
      final isTouched = _touchedIndex == e.key;
      return PieChartSectionData(
        color: _pieColor(e.key),
        value: e.value.value,
        title: pct >= 5 ? '${pct.toStringAsFixed(0)}%' : '',
        radius: isTouched ? 60 : 50,
        titleStyle: TextStyle(
          color: labelColor,
          fontSize: isTouched ? 13 : 11,
          fontWeight: FontWeight.w700,
          shadows: isDarkTheme
              ? null
              : [
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.9),
                    blurRadius: 6,
                  ),
                ],
        ),
      );
    }).toList();
  }

  Color _pieColor(int index) {
    const colors = [
      AppTheme.primary,
      AppTheme.accent,
      AppTheme.warning,
      AppTheme.danger,
      Color(0xFF00C4F0),
      Color(0xFF9C7FFF),
      Color(0xFF00E5A0),
      Color(0xFFFF6B6B),
      Color(0xFFFFB347),
      Color(0xFF7EC8E3),
      Color(0xFFFF85A1),
      Color(0xFF98FF98),
      Color(0xFFDDA0DD),
      Color(0xFFADD8E6),
      Color(0xFFFFD700),
      Color(0xFF20B2AA),
    ];
    return colors[index % colors.length];
  }

  String _fmtK(double v) {
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  void _showFullBreakdownSheet(
    BuildContext context,
    AppProvider provider,
    Map<String, double> byCategory,
    String currency,
  ) {
    final c = context.appColors;
    final catSvc = provider.categoryService;
    final total = byCategory.values.fold(0.0, (a, b) => a + b);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bgSecondary,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: c.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('All Spending Categories',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: byCategory.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final entry = byCategory.entries.elementAt(i);
                  final pct = total > 0 ? entry.value / total * 100 : 0.0;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c.bgCardAlt,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(catSvc.iconFor(entry.key),
                              style: const TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(catSvc.getDisplayName(entry.key),
                                  style: TextStyle(
                                      color: c.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct / 100,
                                  backgroundColor: c.bgCardAlt,
                                  valueColor:
                                      AlwaysStoppedAnimation(_pieColor(i)),
                                  minHeight: 4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$currency ${entry.value.toStringAsFixed(2)}',
                              style: TextStyle(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                            Text('${pct.toStringAsFixed(1)}%',
                                style: TextStyle(
                                    color: c.textMuted, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showRenameCategoryDialog(
    BuildContext context,
    AppProvider provider,
    String original,
    String current,
  ) {
    final ctrl = TextEditingController(text: current);
    final c = context.appColors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rename Category', style: TextStyle(color: c.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: c.textPrimary),
          decoration: const InputDecoration(hintText: 'Category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await provider.renameCategoryDisplay(
                    original, ctrl.text.trim());
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, AppProvider provider) {
    final nameCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '🏷️');
    final c = context.appColors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('New Category', style: TextStyle(color: c.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: emojiCtrl,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.textPrimary, fontSize: 22),
                    decoration: InputDecoration(
                      hintText: '🏷️',
                      hintStyle: TextStyle(color: c.textMuted, fontSize: 22),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    maxLength: 2,
                    buildCounter: (_,
                            {required currentLength,
                            required isFocused,
                            maxLength}) =>
                        null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    style: TextStyle(color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Category name',
                      hintStyle: TextStyle(color: c.textMuted),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await provider.addUserCategory(
                  nameCtrl.text.trim(),
                  emoji: emojiCtrl.text.trim().isNotEmpty
                      ? emojiCtrl.text.trim()
                      : null,
                );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCell(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  TextStyle(color: context.appColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: context.appColors.border);
  }
}

