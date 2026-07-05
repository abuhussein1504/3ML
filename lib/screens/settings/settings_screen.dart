import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_theme.dart';
import '../../providers/app_provider.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../services/export_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.appColors;
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final profile = provider.profile;
        if (profile == null) return const SizedBox();
        final budget = provider.budget;
        final currency = profile.currency;
        final isDark = provider.themeMode == ThemeMode.dark;

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: c.bgPrimary,
              floating: true,
              title: Text('Settings',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Profile card ─────────────────────────
                    Container(
                      decoration: AppTheme.primaryCard(context),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor:
                                AppTheme.primary.withValues(alpha: 0.2),
                            child: Text(
                              profile.name.isNotEmpty
                                  ? profile.name[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(profile.name,
                                    style: TextStyle(
                                      color: c.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    )),
                                Text(
                                  '$currency ${profile.salary.toStringAsFixed(0)}/month · Payday ${_ordinal(profile.payday)}',
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: AppTheme.primary, size: 20),
                            onPressed: () =>
                                _showEditProfileSheet(context, provider),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Appearance ────────────────────────────
                    _SectionHeader('Appearance', context: context),
                    Container(
                      decoration: AppTheme.glassCard(context),
                      child: _ActionTile(
                        icon: isDark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                        label: isDark ? 'Dark Mode' : 'Light Mode',
                        subtitle: 'Switch between dark and light theme',
                        trailing: Switch(
                          value: isDark,
                          onChanged: (_) => provider.toggleTheme(),
                          activeThumbColor: AppTheme.primary,
                        ),
                        onTap: () => provider.toggleTheme(),
                        context: context,
                      ),
                    ),

                    const SizedBox(height: 20),

                    _SectionHeader('Budget Summary', context: context),
                    Container(
                      decoration: AppTheme.glassCard(context),
                      child: Column(
                        children: [
                          _InfoTile(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Monthly Salary',
                            value:
                                '$currency ${profile.salary.toStringAsFixed(2)}',
                            context: context,
                          ),
                          Divider(height: 1, color: c.border),
                          _InfoTile(
                            icon: Icons.home_outlined,
                            label: 'Fixed Bills',
                            value:
                                '$currency ${profile.fixedBills.toStringAsFixed(2)}',
                            context: context,
                          ),
                          Divider(height: 1, color: c.border),
                          _InfoTile(
                            icon: Icons.savings_outlined,
                            label: 'Savings Goal',
                            value:
                                '$currency ${profile.savingsGoal.toStringAsFixed(2)}',
                            context: context,
                          ),
                          Divider(height: 1, color: c.border),
                          _InfoTile(
                            icon: Icons.monetization_on_outlined,
                            label: 'Disposable Budget',
                            value:
                                '$currency ${profile.disposableIncome.toStringAsFixed(2)}',
                            valueColor: AppTheme.primary,
                            context: context,
                          ),
                          if (budget != null) ...[
                            Divider(height: 1, color: c.border),
                            _InfoTile(
                              icon: Icons.trending_down_rounded,
                              label: 'Spent This Period',
                              value:
                                  '$currency ${budget.totalSpent.toStringAsFixed(2)}',
                              valueColor: AppTheme.danger,
                              context: context,
                            ),
                            Divider(height: 1, color: c.border),
                            _InfoTile(
                              icon: Icons.check_circle_outline,
                              label: 'Safe to Spend Today',
                              value:
                                  '$currency ${budget.safeToSpend.toStringAsFixed(2)}',
                              valueColor: budget.isHealthy
                                  ? AppTheme.primary
                                  : AppTheme.danger,
                              context: context,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _SectionHeader('Privacy & Data', context: context),
                    Container(
                      decoration: AppTheme.glassCard(context),
                      child: Column(
                        children: [
                          _ActionTile(
                            icon: Icons.shield_outlined,
                            label: 'Privacy',
                            subtitle:
                                'No bank linking. All data stays on device.',
                            onTap: () => _showPrivacyDialog(context),
                            context: context,
                          ),
                          Divider(height: 1, color: c.border),
                          _ActionTile(
                            icon: Icons.file_download_outlined,
                            label: 'Export Transactions (CSV)',
                            subtitle: 'Download your spending history',
                            onTap: () async {
                              await ExportService().exportTransactionsCsv(
                                provider.transactions,
                                profile,
                              );
                            },
                            context: context,
                          ),
                          Divider(height: 1, color: c.border),
                          _ActionTile(
                            icon: Icons.backup_outlined,
                            label: 'Backup Data',
                            subtitle: 'Export recovery file to restore later',
                            onTap: () async {
                              await ExportService().exportRecoveryData(
                                provider.transactions,
                                profile,
                              );
                            },
                            context: context,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _SectionHeader('About', context: context),
                    Container(
                      decoration: AppTheme.glassCard(context),
                      child: Column(
                        children: [
                          _InfoTile(
                            icon: Icons.info_outline_rounded,
                            label: 'Version',
                            value: '1.0.0',
                            context: context,
                          ),
                          Divider(height: 1, color: c.border),
                          _ActionTile(
                            icon: Icons.gavel_outlined,
                            label: 'Licenses',
                            subtitle: 'Open source licenses',
                            onTap: () => showLicensePage(context: context),
                            context: context,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _SectionHeader('Danger Zone',
                        color: AppTheme.danger, context: context),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.danger.withValues(alpha: 0.3)),
                      ),
                      child: _ActionTile(
                        icon: Icons.delete_forever_outlined,
                        label: 'Reset App',
                        subtitle:
                            'Delete all data and start fresh. This cannot be undone.',
                        iconColor: AppTheme.danger,
                        labelColor: AppTheme.danger,
                        onTap: () => _confirmReset(context, provider),
                        context: context,
                      ),
                    ),

                    const SizedBox(height: 40),

                    Center(
                      child: Column(
                        children: [
                          Text('Made by',
                              style:
                                  TextStyle(color: c.textMuted, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text('Abu Hussein',
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    ),
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

  String _ordinal(int n) {
    if (n == 1 || n == 21) return '${n}st';
    if (n == 2 || n == 22) return '${n}nd';
    if (n == 3 || n == 23) return '${n}rd';
    return '${n}th';
  }

  void _showEditProfileSheet(BuildContext context, AppProvider provider) {
    final p = provider.profile!;
    final nameCtrl = TextEditingController(text: p.name);
    final salaryCtrl = TextEditingController(text: p.salary.toStringAsFixed(2));
    final billsCtrl =
        TextEditingController(text: p.fixedBills.toStringAsFixed(2));
    final savingsCtrl =
        TextEditingController(text: p.savingsGoal.toStringAsFixed(2));
    int payday = p.payday;
    String currency = p.currency;
    final c = context.appColors;

    final currencies = ['EGP', 'USD', 'EUR', 'GBP', 'SAR', 'AED', 'QAR', 'KWD'];

    showModalBottomSheet(
      context: context,
      backgroundColor: c.bgSecondary,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: c.border),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit Profile',
                    style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: c.textPrimary),
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: currency,
                  dropdownColor: c.bgCard,
                  style: TextStyle(color: c.textPrimary),
                  decoration: const InputDecoration(labelText: 'Currency'),
                  items: currencies
                      .toSet()
                      .toList()
                      .map((cur) =>
                          DropdownMenuItem(value: cur, child: Text(cur)))
                      .toList(),
                  onChanged: (v) => setSt(() => currency = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: salaryCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: c.textPrimary),
                  decoration:
                      const InputDecoration(labelText: 'Monthly Salary'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: billsCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: c.textPrimary),
                  decoration: const InputDecoration(labelText: 'Fixed Bills'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: savingsCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: c.textPrimary),
                  decoration: const InputDecoration(labelText: 'Savings Goal'),
                ),
                const SizedBox(height: 12),
                Text('Payday: ${_ordinal(payday)} of each month',
                    style: TextStyle(color: c.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(31, (i) {
                    final day = i + 1;
                    final sel = day == payday;
                    return GestureDetector(
                      onTap: () => setSt(() => payday = day),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.primary : c.bgCard,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: sel ? AppTheme.primary : c.border),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: sel ? c.bgPrimary : c.textSecondary,
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await provider.updateProfile(p.copyWith(
                        name: nameCtrl.text.trim(),
                        salary: double.tryParse(salaryCtrl.text) ?? p.salary,
                        fixedBills:
                            double.tryParse(billsCtrl.text) ?? p.fixedBills,
                        savingsGoal:
                            double.tryParse(savingsCtrl.text) ?? p.savingsGoal,
                        payday: payday,
                        currency: currency,
                      ));
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    final c = context.appColors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Privacy Policy', style: TextStyle(color: c.textPrimary)),
        content: SingleChildScrollView(
          child: Text(
            '🔒 Your data stays on your device.\n\n'
            '• No bank account linking required\n'
            '• Transactions are stored locally in SQLite\n'
            '• Only the raw text you enter is sent to the AI backend\n'
            '• No personal financial data is sold or shared\n'
            '• You can export and delete all data at any time',
            style: TextStyle(color: c.textSecondary, height: 1.6),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, AppProvider provider) {
    final c = context.appColors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text('Reset App', style: TextStyle(color: AppTheme.danger)),
        content: Text(
          'This will permanently delete all your transactions and profile data.\n\nConsider backing up first.',
          style: TextStyle(color: c.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            onPressed: () async {
              Navigator.pop(context);
              await provider.resetApp();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  (_) => false,
                );
              }
            },
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  final BuildContext context;
  const _SectionHeader(this.title,
      {this.color = AppTheme.textMuted, required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color:
              color == AppTheme.textMuted ? context.appColors.textMuted : color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final BuildContext context;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: c.textMuted, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(color: c.textSecondary, fontSize: 14)),
          ),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color? labelColor;
  final Widget? trailing;
  final BuildContext context;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.context,
    this.iconColor = AppTheme.textMuted,
    this.labelColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext ctx) {
    final c = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: labelColor ?? c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: TextStyle(color: c.textMuted, fontSize: 11)),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

