import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_theme.dart';
import '../../models/user_profile.dart';
import '../../providers/app_provider.dart';
import '../main_shell.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _isLoading = false;

  // Form values
  final _nameCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _billsCtrl = TextEditingController();
  final _savingsCtrl = TextEditingController();
  int _selectedPayday = 1;
  String _currency = 'EGP';

  final _currencies = ['EGP', 'USD', 'EUR', 'GBP', 'SAR', 'AED', 'QAR', 'KWD'];

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _salaryCtrl.dispose();
    _billsCtrl.dispose();
    _savingsCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_step < 4) {
      _step++;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() {});
    } else {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        await _complete();
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Something went wrong: $e'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      }
    }
  }

  void _back() {
    if (_step > 0) {
      _step--;
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() {});
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _complete() async {
    final profile = UserProfile(
      name: _nameCtrl.text.trim(),
      salary: (double.tryParse(_salaryCtrl.text.trim()) ?? 0).toDouble(),
      payday: _selectedPayday,
      fixedBills: (double.tryParse(_billsCtrl.text.trim().isEmpty ? '0' : _billsCtrl.text.trim()) ?? 0.0).toDouble(),
      savingsGoal: (double.tryParse(_savingsCtrl.text.trim().isEmpty ? '0' : _savingsCtrl.text.trim()) ?? 0.0).toDouble(),
      currency: _currency,
    );
    await context.read<AppProvider>().completeOnboarding(profile);
    if (!mounted) return;
    // Use pushAndRemoveUntil so navigation works regardless of Consumer rebuild timing.
    // popUntil(isFirst) is unreliable here because notifyListeners() schedules a
    // rebuild for the NEXT frame, so the first route may still show OnboardingScreen.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  bool get _canProceed {
    if (_isLoading) return false;
    switch (_step) {
      case 0: return _nameCtrl.text.trim().isNotEmpty;
      case 1:
        final v = double.tryParse(_salaryCtrl.text.trim());
        return v != null && v > 0;
      case 2: return true; // payday always valid
      case 3: return true; // bills can be 0 or empty
      case 4: return true; // savings can be 0 or empty
      default: return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final elevatedFg = Theme.of(context).brightness == Brightness.dark
        ? c.bgPrimary
        : Colors.white;
    return Scaffold(
      backgroundColor: c.bgPrimary,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _back,
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: c.textSecondary, size: 18),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_step + 1) / 5,
                        backgroundColor: c.bgCard,
                        valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_step + 1}/5',
                    style: TextStyle(
                        color: c.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepPage(
                    title: "What's your name?",
                    subtitle: "We'll personalize your experience.",
                    child: TextField(
                      controller: _nameCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(color: c.textPrimary),
                      decoration:
                          const InputDecoration(hintText: 'e.g. Ahmed'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  _StepPage(
                    title: "Monthly salary?",
                    subtitle: "Your take-home pay each month.",
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _currency,
                          dropdownColor: c.bgCard,
                          style: TextStyle(color: c.textPrimary),
                          decoration:
                              const InputDecoration(labelText: 'Currency'),
                          items: _currencies
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _currency = v!),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _salaryCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: TextStyle(color: c.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'e.g. 12000',
                            prefixText: '$_currency  ',
                            prefixStyle:
                                TextStyle(color: c.textMuted),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  _StepPage(
                    title: "When do you get paid?",
                    subtitle: "The day of month your salary arrives.",
                    child: _PaydayPicker(
                      selected: _selectedPayday,
                      onChanged: (v) => setState(() => _selectedPayday = v),
                    ),
                  ),
                  _StepPage(
                    title: "Fixed monthly bills?",
                    subtitle:
                        "Rent, subscriptions, loan payments — things you always pay. Enter 0 if none.",
                    child: TextField(
                      controller: _billsCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: TextStyle(color: c.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. 3000',
                        prefixText: '$_currency  ',
                        prefixStyle:
                            TextStyle(color: c.textMuted),
                      ),
                    ),
                  ),
                  _StepPage(
                    title: "Monthly savings goal?",
                    subtitle:
                        "How much do you want to set aside each month? Enter 0 to skip.",
                    child: TextField(
                      controller: _savingsCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: TextStyle(color: c.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. 1000',
                        prefixText: '$_currency  ',
                        prefixStyle:
                            TextStyle(color: c.textMuted),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            // CTA (body height already shrinks above keyboard via resizeToAvoidBottomInset)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canProceed ? _next : null,
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(elevatedFg),
                          ),
                        )
                      : Text(_step == 4 ? "Let's Go! 🚀" : 'Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _StepPage({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: bottomInset + 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 28),
            Text(title,
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 10),
            Text(subtitle,
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 15,
                    height: 1.5)),
            const SizedBox(height: 28),
            child,
          ],
        ),
      ),
    );
  }
}

class _PaydayPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _PaydayPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(31, (i) {
        final day = i + 1;
        final isSelected = day == selected;
        final onPrimary = Theme.of(context).brightness == Brightness.dark
            ? c.bgPrimary
            : Colors.white;
        return GestureDetector(
          onTap: () => onChanged(day),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary : c.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.primary : c.border,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                color: isSelected ? onPrimary : c.textSecondary,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
        );
      }),
    );
  }
}
