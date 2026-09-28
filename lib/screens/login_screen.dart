import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gcc_country.dart';
import '../services/auth_service.dart';
import '../services/collection_service.dart';
import '../services/custom_document_type_service.dart';
import '../services/document_scanner_service.dart';
import '../services/entitlement_service.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/legal_info_dialogs.dart';

/// Login & Sign-up — styled after the Home screen's visual language:
///
/// ink/obsidian backdrop with a white-text hero (like Home's hero header),
/// then a rounded surface sheet holding the quiz flow. Violet is the single
/// accent: toggle, progress, CTAs and links all use [FinavigColors.violet],
/// exactly like the app's bento tiles and FilledButtons. The screen follows
/// the app's light/dark theme like every other screen.
///
/// Flow is a quiz: one question per step, per-step validation, keyboard
/// submit advances. Sign-in = 2 steps; sign-up adds country + phone.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _phoneFocus = FocusNode();

  GccCountry _selectedCountry = GccCountry.uae;

  /// Self-reported date of birth, captured at signup for fintech KYC /
  /// age-gate readiness. Optional — null when the user skips it.
  DateTime? _selectedDob;

  bool _isSignUp = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;
  String? _stepError;

  int _step = 0;
  int _dir = 1; // +1 forward, -1 backward (slide direction)

  int get _totalSteps => _isSignUp ? 5 : 2;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  // ── Navigation between steps ──────────────────────────────────────────────

  void _onModeChanged(bool signUp) {
    if (signUp == _isSignUp || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSignUp = signUp;
      _step = 0;
      _dir = 1;
      _error = null;
      _stepError = null;
    });
    _focusCurrent();
  }

  void _gotoStep(int step) {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _dir = step >= _step ? 1 : -1;
      _step = step;
      _error = null;
      _stepError = null;
    });
    _focusCurrent();
  }

  void _back() => _gotoStep(_step - 1);

  void _continue() {
    FocusScope.of(context).unfocus();
    setState(() {
      _stepError = null;
      _error = null;
    });
    if (!_validateStep(_step)) return;
    if (_step < _totalSteps - 1) {
      _gotoStep(_step + 1);
    } else {
      _submit();
    }
  }

  bool _validateStep(int step) {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (step == 0) {
      if (email.isEmpty) return _failStep('Enter your email');
      if (!email.contains('@') || !email.contains('.')) {
        return _failStep('Enter a valid email');
      }
    } else if (step == 1) {
      if (password.isEmpty) return _failStep('Enter your password');
      if (password.length < 6) return _failStep('At least 6 characters');
    } else if (_isSignUp && step == 2) {
      // DOB is optional (self-reported), but if given it must be a real
      // date of the past and the user must be 16+ (see the T&C).
      if (_selectedDob != null) {
        final now = DateTime.now();
        if (_selectedDob!.isAfter(now)) {
          return _failStep('Date of birth cannot be in the future');
        }
        if (_selectedDob!.isBefore(DateTime(1900))) {
          return _failStep('Enter a realistic date of birth');
        }
        var age = now.year - _selectedDob!.year;
        if (now.month < _selectedDob!.month ||
            (now.month == _selectedDob!.month &&
                now.day < _selectedDob!.day)) {
          age--;
        }
        if (age < 16) {
          return _failStep('You must be at least 16 to use Finavig');
        }
      }
    }
    return true;
  }

  bool _failStep(String message) {
    setState(() => _stepError = message);
    return false;
  }

  void _focusCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final FocusNode? node;
      if (_step == 0) {
        node = _emailFocus;
      } else if (_step == 1) {
        node = _passwordFocus;
      } else if (_isSignUp && _step == 4) {
        node = _phoneFocus;
      } else {
        node = null; // DOB picker / country picker — keep keyboard closed
      }
      node?.requestFocus();
    });
  }

  // ── Auth submission ──────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final auth = AuthService.instance;
      if (_isSignUp) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userCountry', _selectedCountry.code);
        if (_selectedDob != null) {
          await prefs.setString(
              'userDateOfBirth', _selectedDob!.toIso8601String().substring(0, 10));
        }
        final phone = _phoneController.text.trim();
        if (phone.isNotEmpty) {
          await prefs.setString('userPhone', phone);
        }
        await auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          dateOfBirth: _selectedDob,
        );
        if (!auth.isSignedIn) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Account created! Check your email to confirm, then sign in.',
                ),
              ),
            );
            setState(() {
              _isSignUp = false;
              _step = 0;
              _busy = false;
            });
            _focusCurrent();
          }
          return;
        }
      } else {
        await auth.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      // Reload everything that is scoped per-user. Order matters:
      // collections first (DocumentScannerService maps legacy collection
      // ids against this list), then custom doc types (rows decode into
      // ExpiryItems via the registry), then documents and finance.
      await DocumentCollectionService.instance.reset();
      // On signup the DB trigger creates the personal collection with default
      // country 'AE'. Patch it to the country the user actually selected.
      if (_isSignUp) {
        await DocumentCollectionService.instance
            .updatePersonalCountry(_selectedCountry.code);
      }
      await CustomDocumentTypeService.instance.reset();
      await DocumentScannerService.instance.refresh();
      await FinanceService.instance.refresh();
      // Load the tier granted to this user (Track 1 entitlements).
      await EntitlementService.instance.refresh();

      if (mounted) context.go('/home');
    } catch (e) {
      setState(() {
        _error = _friendlyError(e.toString());
        _busy = false;
      });
    }
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Wrong email or password.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please confirm your email first (check your inbox).';
    }
    if (lower.contains('already registered')) {
      return 'An account with this email already exists — sign in instead.';
    }
    if (lower.contains('password') && lower.contains('at least')) {
      return 'Password is too weak — use at least 6 characters.';
    }
    if (lower.contains('rate limit')) {
      return 'Too many attempts — wait a minute and try again.';
    }
    if (lower.contains('not configured')) {
      return 'Supabase is not configured in this build (see lib/config/app_credentials.dart).';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _showForgotPassword() async {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FinavigRadius.dialog),
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a link to reset '
              'your password.',
              style: TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );

    final email = resetEmailController.text.trim();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      resetEmailController.dispose();
    });

    if (confirmed != true) return;

    if (email.isEmpty || !email.contains('@')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid email address.')),
        );
      }
      return;
    }

    try {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset link sent! Check your inbox.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e.toString())),
            backgroundColor: FinavigColors.danger,
          ),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // Same backdrop recipe as Home: ink in light mode, obsidian in dark.
      backgroundColor: isDark ? FinavigColors.obsidian : FinavigColors.ink,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hero(theme, isDark),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    _chrome(theme, isDark),
                    Expanded(child: _stepsArea(theme, isDark)),
                    _footer(theme, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero (on the ink backdrop, like Home's hero header) ──────────────────

  Widget _hero(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Finavig',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: FinavigColors.violet.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: FinavigColors.violet.withOpacity(0.55),
                  ),
                ),
                child: const Text(
                  'GCC Edition',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Track document expiries, manage cash flow, and stay compliant '
            'across the GCC.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: Colors.white.withOpacity(0.70),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chrome: mode toggle + progress (on the surface sheet) ────────────────

  Widget _chrome(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          _ModeToggle(
            isSignUp: _isSignUp,
            enabled: !_busy,
            isDark: isDark,
            onChanged: _onModeChanged,
          ),
          const SizedBox(height: 16),
          _StepProgress(step: _step, total: _totalSteps, isDark: isDark),
        ],
      ),
    );
  }

  // ── Steps: centered group of question + field + CTA ─────────────────────

  Widget _stepsArea(ThemeData theme, bool isDark) {
    return LayoutBuilder(
      builder: (context, viewport) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewport.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final slide = Tween<Offset>(
                        begin: Offset(_dir * 0.06, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.topLeft,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey('step-$_isSignUp-$_step'),
                      child: _buildStep(isDark),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _errorBanner(isDark),
                  ],
                  const SizedBox(height: 20),
                  _actionRow(isDark),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _errorBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? FinavigColors.dangerBg : FinavigColors.dangerBgLight,
        borderRadius: BorderRadius.circular(FinavigRadius.tile),
        border: Border.all(color: FinavigColors.danger.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: FinavigColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 13,
                color: FinavigColors.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (_step > 0) ...[
              _BackButton(isDark: isDark, onTap: _busy ? null : _back),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: _PrimaryButton(
                label: _step < _totalSteps - 1
                    ? 'Continue'
                    : (_isSignUp ? 'Create account' : 'Sign in'),
                busy: _busy,
                onPressed: _continue,
              ),
            ),
          ],
        ),
        if (_isSignUp && _step == _totalSteps - 1)
          TextButton(
            onPressed: _busy ? null : _submit,
            child: Text(
              'Skip for now',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? FinavigColors.textSecondary
                    : FinavigColors.textSecondaryLight,
              ),
            ),
          ),
      ],
    );
  }

  // ── Footer: links + legal (inside the surface sheet) ─────────────────────

  Widget _footer(ThemeData theme, bool isDark) {
    final subColor = isDark
        ? FinavigColors.textSecondary
        : FinavigColors.textSecondaryLight;
    final accentText =
        isDark ? FinavigColors.textPrimary : FinavigColors.textPrimaryLight;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Text(
                  'By continuing you agree to our',
                  style: TextStyle(fontSize: 12, color: subColor, height: 1.5),
                ),
                _LegalLink(
                  label: 'Terms & Conditions',
                  color: accentText,
                  onTap: () => showTermsDialog(context),
                ),
                Text(
                  'and',
                  style: TextStyle(fontSize: 12, color: subColor, height: 1.5),
                ),
                _LegalLink(
                  label: 'Privacy Policy',
                  color: accentText,
                  onTap: () => showPrivacyDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TextLink(
                    label: 'About',
                    color: subColor,
                    onTap: () => showAboutSheet(context)),
                _DotSeparator(color: subColor),
                _TextLink(
                    label: 'Terms',
                    color: subColor,
                    onTap: () => showTermsDialog(context)),
                _DotSeparator(color: subColor),
                _TextLink(
                    label: 'Privacy',
                    color: subColor,
                    onTap: () => showPrivacyDialog(context)),
                _DotSeparator(color: subColor),
                _TextLink(
                    label: 'Support',
                    color: subColor,
                    onTap: () => showSupportSheet(context)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${AppVersionBadge.version} · Made for the GCC',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? FinavigColors.textMuted
                    : FinavigColors.textMutedLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step content ─────────────────────────────────────────────────────────

  Widget _buildStep(bool isDark) {
    if (!_isSignUp) {
      switch (_step) {
        case 0:
          return _emailStep(isDark, isSignUp: false);
        default:
          return _passwordStep(isDark, isSignUp: false);
      }
    }
    switch (_step) {
      case 0:
        return _emailStep(isDark, isSignUp: true);
      case 1:
        return _passwordStep(isDark, isSignUp: true);
      case 2:
        return _dobStep(isDark);
      case 3:
        return _countryStep(isDark);
      default:
        return _phoneStep(isDark);
    }
  }

  /// "you're signing up as …" review chip on later steps.
  Widget _emailReviewChip(bool isDark) {
    final subColor = isDark
        ? FinavigColors.textSecondary
        : FinavigColors.textSecondaryLight;
    final email = _emailController.text.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(Icons.mark_email_read_outlined, size: 14, color: subColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              email.isEmpty ? '—' : email,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: subColor),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _gotoStep(0),
            behavior: HitTestBehavior.opaque,
            child: const Text(
              'Change',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: FinavigColors.violet,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emailStep(bool isDark, {required bool isSignUp}) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _QuizQuestion(
            isDark: isDark,
            title:
                isSignUp ? "First — what's your email?" : "What's your email?",
            subtitle: isSignUp
                ? "We'll create your Finavig account with it."
                : "Welcome back! Let's get you signed in.",
          ),
          TextFormField(
            controller: _emailController,
            focusNode: _emailFocus,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _continue(),
            style: TextStyle(color: _fieldTextColor(isDark), fontSize: 15),
            decoration: _fieldDecoration(
              isDark,
              label: 'Email Address',
              icon: Icons.alternate_email_rounded,
              errorText: _stepError,
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordStep(bool isDark, {required bool isSignUp}) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _emailReviewChip(isDark),
          _QuizQuestion(
            isDark: isDark,
            title: isSignUp ? 'Create a password' : 'Enter your password',
            subtitle: isSignUp
                ? 'At least 6 characters. You can change it later.'
                : null,
          ),
          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            textInputAction:
                isSignUp ? TextInputAction.next : TextInputAction.done,
            onFieldSubmitted: (_) => _continue(),
            style: TextStyle(color: _fieldTextColor(isDark), fontSize: 15),
            decoration: _fieldDecoration(
              isDark,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              errorText: _stepError,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                  color: isDark
                      ? FinavigColors.textSecondary
                      : FinavigColors.textSecondaryLight,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),
          if (!isSignUp) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : _showForgotPassword,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: FinavigColors.violet,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Signup step: optional self-reported date of birth — collected now so
  /// the future fintech (KYC / age-gated) features don't need a re-onboarding.
  Widget _dobStep(bool isDark) {
    final subColor = isDark
        ? FinavigColors.textSecondary
        : FinavigColors.textSecondaryLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuizQuestion(
          isDark: isDark,
          title: 'When were you born?',
          subtitle:
              'Optional — we use it to tailor budgets and to meet age rules. '
              'You can skip this.',
        ),
        GestureDetector(
          onTap: _busy ? null : _pickDateOfBirth,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : FinavigColors.cloud,
              borderRadius: BorderRadius.circular(FinavigRadius.field),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.10)
                    : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.cake_rounded,
                    size: 20, color: FinavigColors.violet),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedDob == null
                        ? 'Select your date of birth'
                        : '${_selectedDob!.day.toString().padLeft(2, '0')} '
                            '${_monthName(_selectedDob!.month)} '
                            '${_selectedDob!.year}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _selectedDob == null
                          ? subColor
                          : _fieldTextColor(isDark),
                    ),
                  ),
                ),
                if (_selectedDob != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedDob = null),
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: FinavigColors.textSecondary),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Stored privately under our Privacy Policy — never sold or shared.',
          style: TextStyle(fontSize: 12, color: subColor),
        ),
      ],
    );
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDob ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select your date of birth',
      cancelText: 'Cancel',
      confirmText: 'Confirm',
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDob = picked;
        _stepError = null;
      });
    }
  }

  static String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return months[month - 1];
  }

  Widget _countryStep(bool isDark) {
    // Two chips per row inside the 24px-padded steps area.
    final chipW =
        ((MediaQuery.of(context).size.width - 48 - 10) / 2)
            .clamp(140.0, 210.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuizQuestion(
          isDark: isDark,
          title: 'Where are you based?',
          subtitle:
              "We'll default your document types — IDs, licences, tenancy — to ${_selectedCountry.displayName}.",
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: GccCountry.values.map((c) {
            final selected = c == _selectedCountry;
            return GestureDetector(
              onTap: _busy ? null : () => setState(() => _selectedCountry = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: chipW,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? FinavigColors.violet.withOpacity(0.10)
                      : (isDark
                          ? Colors.white.withOpacity(0.06)
                          : FinavigColors.cloud),
                  borderRadius: BorderRadius.circular(FinavigRadius.field),
                  border: Border.all(
                    color: selected
                        ? FinavigColors.violet
                        : (isDark
                            ? Colors.white.withOpacity(0.10)
                            : Colors.black.withOpacity(0.05)),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                // ISO-letter badge instead of flag emoji: bundled fonts have
                // no regional-indicator glyphs, which rendered as "?" tofu
                // boxes on device. Text badges are deterministic everywhere.
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? FinavigColors.violet
                            : (isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.white),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        c.code,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: selected
                              ? Colors.white
                              : (isDark
                                  ? FinavigColors.textPrimary
                                  : FinavigColors.navyPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            c.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _fieldTextColor(isDark),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c.currency,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? FinavigColors.textSecondary
                                  : FinavigColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Constant-width trailing slot: the check icon appears
                    // without re-laying-out the row (was overflowing by
                    // ~5px the moment selection drew the icon).
                    SizedBox(
                      width: 18,
                      child: selected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: FinavigColors.violet,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _phoneStep(bool isDark) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _emailReviewChip(isDark),
          _QuizQuestion(
            isDark: isDark,
            title: 'Add your phone',
            subtitle:
                'Optional — used for renewal reminders and cash-flow alerts. You can skip this.',
          ),
          TextFormField(
            controller: _phoneController,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _continue(),
            style: TextStyle(color: _fieldTextColor(isDark), fontSize: 15),
            decoration: _fieldDecoration(
              isDark,
              label: 'Phone — $_selectedCountry.phoneCode (Optional)',
              icon: Icons.phone_iphone_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Color _fieldTextColor(bool isDark) =>
      isDark ? FinavigColors.textPrimary : FinavigColors.textPrimaryLight;

  /// Field style mirrors the app-wide InputDecorationTheme
  /// (slate/cloud fill, violet focus ring) so login feels native.
  InputDecoration _fieldDecoration(
    bool isDark, {
    required String label,
    required IconData icon,
    String? errorText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark
            ? FinavigColors.textSecondary
            : FinavigColors.textSecondaryLight,
        fontSize: 13,
      ),
      errorText: errorText,
      prefixIcon: Icon(icon, size: 20, color: FinavigColors.violet),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark
          ? FinavigColors.slate.withOpacity(0.55)
          : FinavigColors.cloud,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FinavigRadius.field),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FinavigRadius.field),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FinavigRadius.field),
        borderSide:
            const BorderSide(color: FinavigColors.violet, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FinavigRadius.field),
        borderSide:
            const BorderSide(color: FinavigColors.danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FinavigRadius.field),
        borderSide:
            const BorderSide(color: FinavigColors.danger, width: 1.5),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Building blocks — violet & dark, matching Home's bento style
// ──────────────────────────────────────────────────────────────────────────────

/// Big question heading for the current step.
class _QuizQuestion extends StatelessWidget {
  final bool isDark;
  final String title;
  final String? subtitle;

  const _QuizQuestion({
    required this.isDark,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: isDark
                ? FinavigColors.textPrimary
                : FinavigColors.textPrimaryLight,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isDark
                  ? FinavigColors.textSecondary
                  : FinavigColors.textSecondaryLight,
            ),
          ),
        ],
        const SizedBox(height: 18),
      ],
    );
  }
}

/// Segmented progress bar: one violet segment per quiz step.
class _StepProgress extends StatelessWidget {
  final int step;
  final int total;
  final bool isDark;

  const _StepProgress({
    required this.step,
    required this.total,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(total, (i) {
              final done = i <= step;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  height: 4,
                  margin: EdgeInsets.only(right: i == total - 1 ? 0 : 5),
                  decoration: BoxDecoration(
                    color: done
                        ? FinavigColors.violet
                        : (isDark
                            ? Colors.white.withOpacity(0.12)
                            : Colors.black.withOpacity(0.08)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Step ${step + 1} of $total',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark
                ? FinavigColors.textMuted
                : FinavigColors.textMutedLight,
          ),
        ),
      ],
    );
  }
}

/// Primary action — flat violet, same as the app's FilledButtons.
class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FinavigRadius.button),
          boxShadow: FinavigShadows.adaptive(isDark),
        ),
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: FinavigColors.violet,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FinavigRadius.button),
            ),
          ),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Circular back button for the action row.
class _BackButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback? onTap;

  const _BackButton({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.14)
                : Colors.black.withOpacity(0.10),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FinavigRadius.button),
          ),
        ),
        child: Icon(
          Icons.arrow_back_rounded,
          size: 20,
          color: isDark
              ? FinavigColors.textPrimary
              : FinavigColors.textPrimaryLight,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Sign in / Sign up segmented pill toggle
// ──────────────────────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final bool isSignUp;
  final bool enabled;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _ModeToggle({
    required this.isSignUp,
    required this.enabled,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final trackColor =
        isDark ? Colors.white.withOpacity(0.06) : FinavigColors.cloud;
    final inactiveColor =
        isDark ? FinavigColors.textSecondary : FinavigColors.textSecondaryLight;

    Widget segment(String label, bool value, IconData icon) {
      final selected = isSignUp == value;
      return Expanded(
        child: GestureDetector(
          onTap: enabled ? () => onChanged(value) : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? FinavigColors.violet : Colors.transparent,
              borderRadius: BorderRadius.circular(FinavigRadius.tile),
              boxShadow: selected ? FinavigShadows.soft : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : inactiveColor,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? Colors.white : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(FinavigRadius.tile + 2),
      ),
      child: Row(
        children: [
          segment('Sign in', false, Icons.login_rounded),
          segment('Sign up', true, Icons.person_add_alt_rounded),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Footer text links
// ──────────────────────────────────────────────────────────────────────────────

class _TextLink extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TextLink({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _DotSeparator extends StatelessWidget {
  final Color color;

  const _DotSeparator({required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      '·',
      style: TextStyle(
          fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _LegalLink({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Version badge
// ──────────────────────────────────────────────────────────────────────────────

class AppVersionBadge {
  AppVersionBadge._();
  static const String version = 'v1.0.0';
}
