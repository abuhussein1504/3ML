import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../models/transaction_model.dart';
import '../providers/app_provider.dart';

double? _parseAmountForSave(String raw, double? keepIfEmpty) {
  final t = raw.trim().replaceAll(',', '').replaceAll(' ', '');
  if (t.isEmpty) return keepIfEmpty;
  return double.tryParse(t);
}

class TransactionTile extends StatelessWidget {
  final TransactionModel tx;
  final bool showCategory;

  const TransactionTile({
    super.key,
    required this.tx,
    this.showCategory = true,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final catSvc = provider.categoryService;
    final currency = provider.profile?.currency ?? 'EGP';
    final isExpense = tx.isExpense;
    final c = context.appColors;
    final amountColor = isExpense ? c.textPrimary : AppTheme.primary;
    final sign = tx.isIncome
        ? '+'
        : tx.isSavings
            ? '→'
            : '-';

    return Dismissible(
      key: Key(tx.id),
      background: _buildDismissBackground(false),
      secondaryBackground: _buildDismissBackground(true),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.endToStart) {
          // Delete
          return await _confirmDelete(context);
        } else {
          // Edit
          _showEditSheet(context);
          return false;
        }
      },
      onDismissed: (_) => provider.deleteTransaction(tx.id),
      child: Container(
        decoration: AppTheme.glassCard(context, radius: 16),
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.bgCardAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              catSvc.iconFor(tx.categoryName),
              style: const TextStyle(fontSize: 20),
            ),
          ),
          title: Text(
            tx.item ?? tx.intent ?? tx.rawInput,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: showCategory
              ? Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.bgCardAlt,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${catSvc.iconFor(tx.categoryName)}  ${catSvc.getDisplayName(tx.categoryName)}',
                            style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : null,
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign $currency ${tx.amount?.toStringAsFixed(2) ?? '?'}',
                    style: TextStyle(
                      color: amountColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _showEditSheet(context),
                    child: const Icon(Icons.more_horiz_rounded,
                        color: AppTheme.textMuted, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDismissBackground(bool isEnd) {
    return Container(
      decoration: BoxDecoration(
        color: isEnd
            ? AppTheme.danger.withValues(alpha: 0.15)
            : AppTheme.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: isEnd ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(
        isEnd ? Icons.delete_outline_rounded : Icons.edit_outlined,
        color: isEnd ? AppTheme.danger : AppTheme.accent,
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final c = context.appColors;
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: c.bgCard,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Delete Transaction',
                style: TextStyle(color: c.textPrimary)),
            content: Text('Are you sure you want to delete this transaction?',
                style: TextStyle(color: c.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showEditSheet(BuildContext context) {
    final provider = context.read<AppProvider>();
    final catSvc = provider.categoryService;
    final amountCtrl =
        TextEditingController(text: tx.amount?.toStringAsFixed(2) ?? '');
    final itemCtrl = TextEditingController(text: tx.item ?? tx.intent ?? '');
    final allCats = catSvc.allCategories.toSet().toList();
    // Normalize: model may return lowercase — find case-insensitive match
    String selectedCategory = allCats.firstWhere(
      (c) => c.toLowerCase() == tx.categoryName.toLowerCase(),
      orElse: () => allCats.isNotEmpty ? allCats.first : tx.categoryName,
    );

    final sheetColors = context.appColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: sheetColors.bgSecondary,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: sheetColors.border),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: sheetColors.textMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Edit Transaction',
                  style: TextStyle(
                    color: sheetColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                // Item
                TextField(
                  controller: itemCtrl,
                  style: TextStyle(color: sheetColors.textPrimary),
                  decoration:
                      const InputDecoration(labelText: 'Item / Description'),
                ),
                const SizedBox(height: 14),
                // Amount
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: sheetColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
                const SizedBox(height: 14),
                // Category picker
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  dropdownColor: sheetColors.bgCard,
                  style: TextStyle(color: sheetColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: allCats
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Row(
                              children: [
                                Text(catSvc.iconFor(c)),
                                const SizedBox(width: 8),
                                Text(catSvc.getDisplayName(c)),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setSt(() => selectedCategory = v!),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amountToSave =
                          _parseAmountForSave(amountCtrl.text, tx.amount);
                      if (amountToSave == null) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Enter a valid amount'),
                            ),
                          );
                        }
                        return;
                      }
                      final updated = tx
                          .copyWith(
                            item: itemCtrl.text.trim().isNotEmpty
                                ? itemCtrl.text.trim()
                                : null,
                            amount: amountToSave,
                            categoryName: selectedCategory,
                          )
                          .withCategoryAsBudgetDriver();
                      await provider.updateTransaction(updated);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Save Changes'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style:
                        TextButton.styleFrom(foregroundColor: AppTheme.danger),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      if (await _confirmDelete(context)) {
                        await provider.deleteTransaction(tx.id);
                      }
                    },
                    child: const Text('Delete Transaction'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

