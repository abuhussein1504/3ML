import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../app_theme.dart';
import '../../providers/app_provider.dart';
import '../../services/export_service.dart';
import '../main_shell.dart';
import 'setup_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final c = context.appColors;
        final mustPickTheme = provider.needsThemeChoice;
        return Scaffold(
          backgroundColor: c.bgPrimary,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 24),
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '3ML',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: c.bgPrimary,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                'Make My\nMoney Last',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  color: c.textPrimary,
                                  height: 1.1,
                                  letterSpacing: -1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'One number every day',
                                style: TextStyle(
                                  fontSize: 17,
                                  color: c.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                'Choose your look',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: c.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ThemeCard(
                                      label: 'Light',
                                      icon: Icons.light_mode_rounded,
                                      selected: !mustPickTheme &&
                                          provider.themeMode == ThemeMode.light,
                                      onTap: () => context
                                          .read<AppProvider>()
                                          .completeThemeSelection(
                                              ThemeMode.light),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _ThemeCard(
                                      label: 'Dark',
                                      icon: Icons.dark_mode_rounded,
                                      selected: !mustPickTheme &&
                                          provider.themeMode == ThemeMode.dark,
                                      onTap: () => context
                                          .read<AppProvider>()
                                          .completeThemeSelection(
                                              ThemeMode.dark),
                                    ),
                                  ),
                                ],
                              ),
                              if (mustPickTheme) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Pick light or dark to continue.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: c.textMuted,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 28),
                              const _FeatureRow(
                                  icon: '💬', text: 'Just type what you spent'),
                              const SizedBox(height: 14),
                              const _FeatureRow(
                                  icon: '🔒',
                                  text: 'Fully private, no bank linking'),
                              const SizedBox(height: 14),
                              const _FeatureRow(
                                  icon: '📊',
                                  text: 'Instant smart budget math'),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 32, bottom: 24),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: mustPickTheme
                                        ? null
                                        : () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const SetupScreen()),
                                            ),
                                    child: const Text("I'm New"),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: c.textPrimary,
                                      side: BorderSide(color: c.border),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: mustPickTheme
                                        ? null
                                        : () => _restoreData(context),
                                    child: const Text('Restore From Backup'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _restoreData(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    String content;
    if (file.bytes != null) {
      content = String.fromCharCodes(file.bytes!);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    } else {
      return;
    }

    if (!context.mounted) return;

    final recovery = await ExportService().parseRecoveryFile(content);
    if (recovery == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid backup file. Please check and try again.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    await context.read<AppProvider>().restoreFromBackup(
          recovery.profile,
          recovery.transactions,
        );

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    }
  }
}

class _ThemeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: c.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppTheme.primary : c.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: c.textPrimary),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: c.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

