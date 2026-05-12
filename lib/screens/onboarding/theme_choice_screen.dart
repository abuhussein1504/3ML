import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_theme.dart';
import '../../providers/app_provider.dart';

/// Shown once on first install so the user picks light or dark before budget onboarding.
class ThemeChoiceScreen extends StatelessWidget {
  const ThemeChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.bgPrimary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '3ML',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Choose your look',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: c.textPrimary,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You can change this anytime in Settings.',
                        style: TextStyle(
                          fontSize: 16,
                          color: c.textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          Expanded(
                            child: _ThemeCard(
                              label: 'Light',
                              icon: Icons.light_mode_rounded,
                              onTap: () => context
                                  .read<AppProvider>()
                                  .completeThemeSelection(ThemeMode.light),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _ThemeCard(
                              label: 'Dark',
                              icon: Icons.dark_mode_rounded,
                              onTap: () => context
                                  .read<AppProvider>()
                                  .completeThemeSelection(ThemeMode.dark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.label,
    required this.icon,
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
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: c.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: c.textPrimary),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 17,
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
