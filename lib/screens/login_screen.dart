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
import '../utils/error_messages.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/legal_info_dialogs.dart';
import 'app_lock_flows.dart';

/// Login & Sign-up — a Material-3 centred auth screen: a quiet
/// brand header (FV monogram, wordmark + GCC Edition pill, the
/// welcome screen's tagline and feature chips) above the quiz flow,
/// which sits in a soft card on a chart-motif backdrop borrowed
/// from the splash / welcome artwork.
///
/// Violet is the single accent: toggle, progress, CTAs and links all
/// use [FinavigColors.violet], exactly like the app's bento tiles and
/// FilledButtons. The screen follows the app's light/dark theme like
/// every other screen.
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
      //
      // Auth has already succeeded at this point — a failure here must
      // NEVER send the user back to "try again" (the account exists, so a
      // retry would report "already registered"). Log it and enter the app;
      // services re-sync on next launch.
      try {
        await DocumentCollectionService.instance.reset();
        // On signup the DB trigger creates the personal collection with
        // default country 'AE'. Patch it to the selected country.
        if (_isSignUp) {
          await DocumentCollectionService.instance
              .updatePersonalCountry(_selectedCountry.code);
        }
        await CustomDocumentTypeService.instance.reset();
        await DocumentScannerService.instance.refresh();
        await FinanceService.instance.refresh();
        // Load the tier granted to this user (Track 1 entitlements).
        await EntitlementService.instance.refresh();
      } catch (e) {
        debugPrint('Post-auth refresh failed (entering app anyway): $e');
      }

      // One-time, opt-in App Lock set-up offer for returning users (never
      // shown to brand-new sign-ups). Purely a convenience — a failure here
      // must not surface as a login error, so entry always proceeds.
      if (mounted && !_isSignUp) {
        try {
          await maybeOfferAppLockSetup(context);
        } catch (e) {
          debugPrint('App Lock offer skipped: $e');
        }
      }

      if (mounted) {
        // Brand-new accounts go through the onboarding tour once, right
        // after sign-up. Returning sign-ins (and anyone who has already
        // onboarded) land straight on Home. Without this, onboarding was
        // only reachable from the splash screen — i.e. on the *next* cold
        // start — so a fresh sign-up never saw it.
        final prefs = await SharedPreferences.getInstance();
        final hasOnboarded = prefs.getBool('hasOnboarded') ?? false;
        if (_isSignUp && !hasOnboarded) {
          context.go('/onboarding');
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      setState(() {
        _error = friendlyError(e);
        _busy = false;
      });
    }
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
            content: Text(friendlyError(e)),
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
      // Same surface recipe as the rest of the app: ink in light
      // mode, obsidian in dark.
      backgroundColor: isDark ? FinavigColors.obsidian : FinavigColors.ink,
      // The sheet IS the screen — a quiet brand backdrop under a
      // centred header, with the quiz flow in a soft M3 card.
      body: SafeArea(
        bottom: false,
        child: _glassSheet(theme, isDark),
      ),
    );
  }

  /// The full-screen surface: a quiet chart-motif backdrop (the same
  /// motif as the splash / welcome art), the centred brand header and
  /// feature chips, the mode toggle + progress, the quiz flow in a
  /// soft card, and the footer.
  Widget _glassSheet(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark
            ? FinavigGradients.surfaceDark
            : FinavigGradients.splashLight,
      ),
      child: Stack(
        children: [
          Positioned.fill(child: _BackdropArt(isDark: isDark)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _brandHeader(isDark),
                _featureStrip(isDark),
                _chrome(theme, isDark),
                Expanded(child: _stepsArea(theme, isDark)),
                _footer(theme, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Brand header (centred: FV monogram, wordmark + pill, tagline) ──

  Widget _brandHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Inter — the app's system typeface (matches the
              // welcome screen's wordmark), not a serif display font.
              Text(
                'Finavig',
                style: GoogleFonts.inter(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : FinavigColors.ink,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: FinavigColors.violet.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: FinavigColors.violet.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'GCC Edition',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: FinavigColors.violet,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // The welcome screen's positioning line, repeated here so
          // the two pre-auth screens tell one story.
          Text(
            'AI-powered financial & document intelligence',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
              color: isDark
                  ? FinavigColors.textSecondary
                  : FinavigColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  // ── Feature chips (the welcome screen's promise) ────────────────

  /// Budgets · cash flow · document alerts — the welcome screen's
  /// tagline as a quiet strip of violet chips under the header.
  Widget _featureStrip(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          _FeatureChip(
            icon: Icons.pie_chart_rounded,
            label: 'Budgets',
            isDark: isDark,
          ),
          _FeatureChip(
            icon: Icons.show_chart_rounded,
            label: 'Cash flow',
            isDark: isDark,
          ),
          _FeatureChip(
            icon: Icons.description_rounded,
            label: 'Doc alerts',
            isDark: isDark,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
      child: LayoutBuilder(
        builder: (context, viewport) {
          // The quiz flow sits in a soft, rounded card — the
          // Material-3 "centred card" auth layout, so the space
          // around the form reads as designed, not empty.
          return Container(
            width: double.infinity,
            constraints:
                BoxConstraints(minHeight: viewport.maxHeight),
            decoration: BoxDecoration(
              color: isDark ? FinavigColors.charcoal : Colors.white,
              borderRadius: BorderRadius.circular(FinavigRadius.card),
              border: Border.all(
                color: isDark
                    ? FinavigColors.glassBorderWhite
                    : FinavigColors.fog,
              ),
              boxShadow: FinavigShadows.adaptive(isDark),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
              child: ConstrainedBox(
                // Mirror the card's vertical padding so the step
                // content stays centred in the full card height.
                constraints: BoxConstraints(
                  minHeight: viewport.maxHeight - 52,
                ),
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
                            child: SlideTransition(
                                position: slide, child: child),
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
                      const SizedBox(height: 16),
                      _TrustRow(isDark: isDark),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color:
                    (isDark ? Colors.white : Colors.black).withOpacity(0.14),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.cake_rounded,
                    size: 19, color: FinavigColors.violet),
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
    final c = _selectedCountry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuizQuestion(
          isDark: isDark,
          title: 'Where are you based?',
          subtitle:
              "We'll default your document types — IDs, licences, tenancy — to ${c.displayName}.",
        ),
        // Dropdown-style picker: tappable field opening a bottom sheet with
        // all 6 GCC countries (same pattern as the app's other pickers).
        GestureDetector(
          onTap: _busy ? null : _pickCountry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color:
                    (isDark ? Colors.white : Colors.black).withOpacity(0.14),
              ),
            ),
            child: Row(
              children: [
                // Bundled flag image (emoji flags render as tofu with the
                // bundled fonts); hairline border keeps white-edged flags
                // like AE visible on light backgrounds.
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.20)
                          : Colors.black.withOpacity(0.10),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.asset(
                      c.flagAsset,
                      width: 32,
                      height: 22,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _fieldTextColor(isDark),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${c.currency} · ${c.phoneCode}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? FinavigColors.textSecondary
                              : FinavigColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.expand_more_rounded,
                  size: 22,
                  color: isDark
                      ? FinavigColors.textSecondary
                      : FinavigColors.textSecondaryLight,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Opens the country picker bottom sheet and updates the selection.
  Future<void> _pickCountry() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<GccCountry>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final sheetDark = theme.brightness == Brightness.dark;
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: sheetDark
                          ? Colors.white.withOpacity(0.15)
                          : Colors.black.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Select your country',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: sheetDark
                        ? FinavigColors.textPrimary
                        : FinavigColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 12),
                ...GccCountry.values.map((option) {
                  final selected = option == _selectedCountry;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, option),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? FinavigColors.violet.withOpacity(0.10)
                              : (sheetDark
                                  ? Colors.white.withOpacity(0.05)
                                  : FinavigColors.cloud),
                          borderRadius:
                              BorderRadius.circular(FinavigRadius.tile),
                          border: Border.all(
                            color: selected
                                ? FinavigColors.violet
                                : (sheetDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.black.withOpacity(0.05)),
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: sheetDark
                                      ? Colors.white.withOpacity(0.20)
                                      : Colors.black.withOpacity(0.10),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Image.asset(
                                  option.flagAsset,
                                  width: 38,
                                  height: 28,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    option.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: sheetDark
                                          ? FinavigColors.textPrimary
                                          : FinavigColors.textPrimaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${option.currency} · ${option.phoneCode}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: sheetDark
                                          ? FinavigColors.textSecondary
                                          : FinavigColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 22,
                              child: selected
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      size: 20,
                                      color: FinavigColors.violet,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedCountry = picked;
        _stepError = null;
      });
    }
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
              label: 'Phone — ${_selectedCountry.phoneCode} (Optional)',
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
    // Sharp-edged, compact fields: quiet fill, hairline border, NO accent
    // highlight when focused — focus is communicated by the caret and
    // keyboard only. Tight icon constraints + slim padding keep the boxes
    // ~44px tall instead of the Material default ~56px.
    const radius = BorderRadius.all(Radius.circular(6));
    const iconSlot = BoxConstraints(minWidth: 40, minHeight: 36);
    final hairline = (isDark ? Colors.white : Colors.black).withOpacity(0.14);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark
            ? FinavigColors.textSecondary
            : FinavigColors.textSecondaryLight,
        fontSize: 13,
      ),
      errorText: errorText,
      prefixIcon: Icon(icon, size: 19, color: FinavigColors.accentBright),
      prefixIconConstraints: iconSlot,
      suffixIconConstraints: iconSlot,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark
          ? Colors.white.withOpacity(0.06)
          : Colors.black.withOpacity(0.03),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.22),
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide:
            const BorderSide(color: FinavigColors.danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide:
            const BorderSide(color: FinavigColors.danger, width: 1.2),
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
    // Flat single-dark-color CTA: solid ink in both themes (hairline border
    // keeps it visible on the dark glass sheet). No gradient, no halo.
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FinavigRadius.button),
          border: isDark
              ? Border.all(color: Colors.white.withOpacity(0.14))
              : null,
        ),
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: FinavigColors.ink,
            foregroundColor: Colors.white,
            disabledBackgroundColor: FinavigColors.ink.withOpacity(0.55),
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
            borderRadius: BorderRadius.circular(26),
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
    // Glass & Glow: quiet glass track; the selected segment is a raised
    // glass pill (white with violet text in light, white-at-16% in dark).
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
              // Solid white pill in both themes with ink (button-color)
              // text — matches the flat dark CTA.
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: selected ? FinavigShadows.soft : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? FinavigColors.ink : inactiveColor,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? FinavigColors.ink : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 54,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.10),
        ),
      ),
      child: Row(
        children: [
          segment('Sign in', false, Icons.login_rounded),
          const SizedBox(width: 4),
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

/// Small violet-tint chip — one per core promise from the
/// welcome screen's tagline.
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: FinavigColors.violet
            .withValues(alpha: isDark ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: FinavigColors.violet
              .withValues(alpha: isDark ? 0.30 : 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: FinavigColors.violet),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? FinavigColors.textPrimary
                  : FinavigColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Quiet security line under the CTA — a fintech trust cue.
class _TrustRow extends StatelessWidget {
  final bool isDark;

  const _TrustRow({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = isDark
        ? FinavigColors.textMuted
        : FinavigColors.textMutedLight;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.verified_user_rounded, size: 13, color: color),
        const SizedBox(width: 6),
        Text(
          'Secure sign-in — your data stays private',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Quiet brand backdrop: a soft accent glow, faint market-chart
/// lines and ghosted bento tiles — the splash / welcome artwork's
/// motifs, at a whisper, so the login feels branded without a
/// dark hero image.
class _BackdropArt extends StatelessWidget {
  final bool isDark;

  const _BackdropArt({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackdropPainter(isDark: isDark),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final bool isDark;

  _BackdropPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final accent = isDark
        ? FinavigColors.accentBright
        : FinavigColors.accent;

    // 1. Soft radial glow behind the brand header.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: isDark ? 0.16 : 0.10),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(w / 2, h * 0.16),
            radius: w * 0.9,
          ),
        ),
    );

    // 2. Faint market-chart lines — the splash / welcome
    // backdrop's motif, barely there so the form stays the hero.
    final mainLine = Paint()
      ..color = accent.withValues(alpha: isDark ? 0.22 : 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final goldLine = Paint()
      ..color = FinavigColors.tierGold
          .withValues(alpha: isDark ? 0.18 : 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final y = h * 0.08;
    canvas.drawPath(
      Path()
        ..moveTo(-24, y + 36)
        ..cubicTo(w * 0.18, y - 12, w * 0.34, y + 52, w * 0.52, y + 8)
        ..cubicTo(w * 0.68, y - 24, w * 0.84, y + 20, w + 24, y - 6),
      mainLine,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-24, y + 66)
        ..cubicTo(w * 0.22, y + 30, w * 0.40, y + 80, w * 0.58, y + 38)
        ..cubicTo(w * 0.74, y + 10, w * 0.88, y + 44, w + 24, y + 26),
      goldLine,
    );

    // 3. Ghosted bento tiles in the top corners — the home grid,
    // outlined at a whisper.
    final tile = Paint()
      ..color = accent.withValues(alpha: isDark ? 0.08 : 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const radius = Radius.circular(18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-18, 10, w * 0.24, 60),
        radius,
      ),
      tile,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.76, 10, w * 0.24 + 18, 60),
        radius,
      ),
      tile,
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.isDark != isDark;
}

// ──────────────────────────────────────────────────────────────────────────────
// Version badge
// ──────────────────────────────────────────────────────────────────────────────

class AppVersionBadge {
  AppVersionBadge._();
  static const String version = 'v1.0.0';
}
