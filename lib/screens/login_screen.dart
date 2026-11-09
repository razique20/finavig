import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/gcc_country.dart';
import '../services/app_version_service.dart';
import '../services/auth_service.dart';
import '../services/collection_service.dart';
import '../services/custom_document_type_service.dart';
import '../services/document_scanner_service.dart';
import '../services/entitlement_service.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_messages.dart';
import '../widgets/dialogs/legal_info_dialogs.dart';
import 'app_lock_flows.dart';

class AppVersionBadge {
  AppVersionBadge._();
  static const String version = 'v1.0.0';
}

/// Modern, app-centred Login and Sign-Up screen for Finavig.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _isSignUp = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  GccCountry _selectedCountry = GccCountry.uae;
  DateTime? _selectedDob;
  bool _showAdvancedFields = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _switchMode(bool signUp) {
    if (_isSignUp == signUp) return;
    setState(() {
      _isSignUp = signUp;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final auth = AuthService.instance;
      final prefs = await SharedPreferences.getInstance();

      if (_isSignUp) {
        await prefs.setString('userCountry', _selectedCountry.code);
        if (_selectedDob != null) {
          await prefs.setString(
            'userDateOfBirth',
            _selectedDob!.toIso8601String().substring(0, 10),
          );
        }
        final phone = _phoneController.text.trim();
        if (phone.isNotEmpty) {
          await prefs.setString('userPhone', phone);
        }

        await auth.signUp(
          email: email,
          password: password,
          dateOfBirth: _selectedDob,
        );

        if (!auth.isSignedIn) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Account created! Check your email to confirm, then sign in.',
                ),
                backgroundColor: FinavigColors.safe,
              ),
            );
            setState(() {
              _isSignUp = false;
              _busy = false;
            });
          }
          return;
        }
      } else {
        await auth.signIn(email: email, password: password);
      }

      if (mounted) {
        unawaited(AppVersionService.instance.trackAppUsage());
      }

      // Initialize user-scoped services
      try {
        await DocumentCollectionService.instance.reset();
        if (_isSignUp) {
          await DocumentCollectionService.instance.updatePersonalCountry(
            _selectedCountry.code,
          );
        }
        await CustomDocumentTypeService.instance.reset();
        await DocumentScannerService.instance.refresh();
        await FinanceService.instance.refresh();
        await EntitlementService.instance.refresh();
      } catch (e) {
        debugPrint('Post-auth refresh error: $e');
      }

      // Offer app lock setup to returning sign-ins
      if (mounted && !_isSignUp) {
        try {
          await maybeOfferAppLockSetup(context);
        } catch (e) {
          debugPrint('App lock offer skipped: $e');
        }
      }

      if (mounted) {
        final hasOnboarded = prefs.getBool('hasOnboarded') ?? false;
        final destination = (_isSignUp && !hasOnboarded) ? '/onboarding' : '/home';
        context.go(destination);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _busy = false;
        });
      }
    }
  }

  Future<void> _continueAsLocal() async {
    setState(() => _busy = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userCountry', _selectedCountry.code);
    await DocumentCollectionService.instance.reset();
    await DocumentScannerService.instance.refresh();
    await FinanceService.instance.refresh();

    if (mounted) {
      final hasOnboarded = prefs.getBool('hasOnboarded') ?? false;
      final destination = hasOnboarded ? '/home' : '/onboarding';
      context.go(destination);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    final controller = TextEditingController(text: email);

    final resetEmail = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your registered email address and we will send you a password reset link.',
              style: TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Send Link'),
          ),
        ],
      ),
    );

    if (resetEmail == null || resetEmail.isEmpty) return;

    try {
      await AuthService.instance.sendPasswordReset(resetEmail);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset link sent! Check your inbox.'),
            backgroundColor: FinavigColors.safe,
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

  void _showCountryPicker() {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Text('🌍', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Text(
                      'Select GCC Country',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: GccCountry.values.map((country) {
                    final selected = country == _selectedCountry;
                    return ListTile(
                      leading: Text(
                        country.flagEmoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        country.displayName,
                        style: TextStyle(
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'Currency: ${country.currency} · ${country.nationalIdLabel}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: fade.color(
                            FinavigColors.textMutedLight,
                            FinavigColors.textMuted,
                          ),
                        ),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: FinavigColors.accent,
                            )
                          : null,
                      onTap: () {
                        setState(() => _selectedCountry = country);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _selectedDob ?? DateTime(now.year - 25, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 15, now.month, now.day),
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = FinavigTransition.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = fade.color(
      const Color(0xFFF6F7FA),
      FinavigColors.obsidian,
    );
    final cardBg = fade.color(
      Colors.white,
      FinavigColors.charcoal,
    );
    final cardBorder = fade.color(
      const Color(0xFFE5E7EB),
      Colors.white.withValues(alpha: 0.08),
    );

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // ── Brand Header ──────────────────────────────────────
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: fade.color(
                              Colors.white,
                              FinavigColors.slate,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: FinavigColors.accent.withValues(alpha: 0.25),
                                blurRadius: 24,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Image.asset(
                            'assets/New Logo/finavig-mark-transparent.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'FINAVIG',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3.5,
                          color: fade.color(
                            FinavigColors.textPrimaryLight,
                            FinavigColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Smart Expiries & Financial Navigator',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: fade.color(
                            FinavigColors.textSecondaryLight,
                            FinavigColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // GCC Region Strip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: fade.color(
                            Colors.black.withValues(alpha: 0.04),
                            Colors.white.withValues(alpha: 0.05),
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '🇦🇪 🇸🇦 🇶🇦 🇰🇼 🇧🇭 🇴🇲',
                              style: TextStyle(fontSize: 11),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'GCC Edition',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: fade.color(
                                  FinavigColors.textMutedLight,
                                  FinavigColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Segmented Control (Sign In / Create Account) ───────
                      Container(
                        height: 46,
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          color: fade.color(
                            const Color(0xFFEBECEF),
                            FinavigColors.slate,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _AuthTabButton(
                                label: 'Sign In',
                                active: !_isSignUp,
                                onTap: () => _switchMode(false),
                              ),
                            ),
                            Expanded(
                              child: _AuthTabButton(
                                label: 'Create Account',
                                active: _isSignUp,
                                onTap: () => _switchMode(true),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Main Auth Card ────────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.35)
                                  : Colors.black.withValues(alpha: 0.04),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Error Banner
                              if (_error != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: FinavigColors.danger.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: FinavigColors.danger.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        size: 16,
                                        color: FinavigColors.danger,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: FinavigColors.danger,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],

                              // Email Field
                              _AuthInputField(
                                controller: _emailController,
                                label: 'Email Address',
                                hint: 'name@example.com',
                                icon: Icons.alternate_email_rounded,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 14),

                              // Password Field
                              _AuthInputField(
                                controller: _passwordController,
                                label: 'Password',
                                hint: '••••••••',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscurePassword,
                                textInputAction: _isSignUp
                                    ? TextInputAction.next
                                    : TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                    color: fade.color(
                                      FinavigColors.textMutedLight,
                                      FinavigColors.textMuted,
                                    ),
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),

                              // Sign-In Extra: Forgot Password
                              if (!_isSignUp) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _forgotPassword,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Forgot password?',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: FinavigColors.accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              // Sign-Up Extras: Country & KYC Fields
                              if (_isSignUp) ...[
                                const SizedBox(height: 14),
                                // GCC Country Selector
                                InkWell(
                                  onTap: _showCountryPicker,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: fade.color(
                                        const Color(0xFFF9FAFB),
                                        FinavigColors.slate.withValues(alpha: 0.5),
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          _selectedCountry.flagEmoji,
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'GCC Country',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: fade.color(
                                                    FinavigColors.textMutedLight,
                                                    FinavigColors.textMuted,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '${_selectedCountry.displayName} (${_selectedCountry.currency})',
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: fade.color(
                                                    FinavigColors.textPrimaryLight,
                                                    FinavigColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 18,
                                          color: fade.color(
                                            FinavigColors.textMutedLight,
                                            FinavigColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Toggle Optional Fields
                                InkWell(
                                  onTap: () => setState(
                                    () => _showAdvancedFields =
                                        !_showAdvancedFields,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _showAdvancedFields
                                              ? Icons.expand_less_rounded
                                              : Icons.expand_more_rounded,
                                          size: 16,
                                          color: FinavigColors.accent,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _showAdvancedFields
                                              ? 'Hide optional KYC fields'
                                              : 'Add phone & date of birth (optional)',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: FinavigColors.accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                if (_showAdvancedFields) ...[
                                  const SizedBox(height: 10),
                                  _AuthInputField(
                                    controller: _phoneController,
                                    label: 'Phone Number (Optional)',
                                    hint: '${_selectedCountry.phoneCode} 50 123 4567',
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                  ),
                                  const SizedBox(height: 12),
                                  InkWell(
                                    onTap: _pickDob,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: fade.color(
                                          const Color(0xFFF9FAFB),
                                          FinavigColors.slate.withValues(alpha: 0.5),
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: cardBorder),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.cake_outlined,
                                            size: 18,
                                            color: fade.color(
                                              FinavigColors.textMutedLight,
                                              FinavigColors.textMuted,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _selectedDob != null
                                                  ? 'DOB: ${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}'
                                                  : 'Date of Birth (Optional)',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: _selectedDob != null
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: fade.color(
                                                  FinavigColors.textPrimaryLight,
                                                  FinavigColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.calendar_month_outlined,
                                            size: 18,
                                            color: fade.color(
                                              FinavigColors.textMutedLight,
                                              FinavigColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],

                              const SizedBox(height: 20),

                              // Primary Submit Button
                              SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: FinavigColors.accent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: _busy ? null : _submit,
                                  child: _busy
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              _isSignUp
                                                  ? 'Create Free Account'
                                                  : 'Sign In to Finavig',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 17,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Offline / Local Mode ──────────────────────────────
                      TextButton.icon(
                        onPressed: _busy ? null : _continueAsLocal,
                        icon: const Icon(
                          Icons.cloud_off_rounded,
                          size: 16,
                          color: FinavigColors.textSecondary,
                        ),
                        label: Text(
                          'Explore in Local Mode (Offline)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: fade.color(
                              FinavigColors.textSecondaryLight,
                              FinavigColors.textSecondary,
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),
                      const SizedBox(height: 16),

                      // ── Trust & Security Footer ───────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            size: 13,
                            color: fade.color(
                              FinavigColors.textMutedLight,
                              FinavigColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Bank-grade AES encryption · Offline-first privacy',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: fade.color(
                                FinavigColors.textMutedLight,
                                FinavigColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _FooterLink(
                            label: 'Terms of Service',
                            onTap: () => showTermsDialog(context),
                          ),
                          Text(
                            ' · ',
                            style: TextStyle(
                              color: fade.color(
                                FinavigColors.textMutedLight,
                                FinavigColors.textMuted,
                              ),
                            ),
                          ),
                          _FooterLink(
                            label: 'Privacy Policy',
                            onTap: () => showPrivacyDialog(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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

class _AuthTabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _AuthTabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? fade.color(Colors.white, FinavigColors.charcoal)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active
                ? fade.color(
                    FinavigColors.textPrimaryLight,
                    FinavigColors.textPrimary,
                  )
                : fade.color(
                    FinavigColors.textSecondaryLight,
                    FinavigColors.textSecondary,
                  ),
          ),
        ),
      ),
    );
  }
}

class _AuthInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  const _AuthInputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final fade = FinavigTransition.of(context);
    final borderColor = fade.color(
      const Color(0xFFE5E7EB),
      Colors.white.withValues(alpha: 0.1),
    );
    final fillColor = fade.color(
      const Color(0xFFF9FAFB),
      FinavigColors.slate.withValues(alpha: 0.5),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: fade.color(
              FinavigColors.textSecondaryLight,
              FinavigColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: fade.color(
              FinavigColors.textPrimaryLight,
              FinavigColors.textPrimary,
            ),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              color: fade.color(
                FinavigColors.textMutedLight,
                FinavigColors.textMuted,
              ),
            ),
            prefixIcon: Icon(
              icon,
              size: 18,
              color: fade.color(
                FinavigColors.textMutedLight,
                FinavigColors.textMuted,
              ),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: FinavigColors.accent,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: FinavigColors.accent,
        ),
      ),
    );
  }
}
