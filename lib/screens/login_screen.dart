import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'password_recovery_screen.dart';

/// Sign in / create account. Uses the app's existing theme and styling.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.mode = LoginMode.signIn});

  final LoginMode mode;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum LoginMode { signIn, signUp }

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late LoginMode _mode = widget.mode;
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _verificationCode = TextEditingController();
  final _verificationFocusNode = FocusNode();
  bool _obscure = true;
  bool _verificationPending = false;
  bool _resendingConfirmation = false;
  int _resendCooldownSeconds = 0;
  Timer? _resendCooldownTimer;
  String? _signupNotice;

  @override
  void initState() {
    super.initState();
    _verificationCode.addListener(_onVerificationCodeChanged);
    _verificationFocusNode.addListener(_onVerificationCodeChanged);
  }

  void _onVerificationCodeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    _verificationCode.removeListener(_onVerificationCodeChanged);
    _verificationFocusNode.removeListener(_onVerificationCodeChanged);
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _verificationCode.dispose();
    _verificationFocusNode.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendCooldownTimer?.cancel();
    setState(() => _resendCooldownSeconds = 60);
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _resendCooldownSeconds = 0);
      } else {
        setState(() => _resendCooldownSeconds--);
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthProvider>();
    final email = _email.text.trim();
    if (_verificationPending) {
      if (!RegExp(r'^\d{6}$').hasMatch(_verificationCode.text.trim())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter the 6-digit code from your email.'),
          ),
        );
        return;
      }
      final verificationError = await auth.verifySignupCode(
        email: email,
        code: _verificationCode.text,
      );
      if (!mounted) return;
      if (verificationError == null) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(verificationError)));
      }
      return;
    }
    final password = _password.text;

    final error = _mode == LoginMode.signIn
        ? await auth.signIn(email: email, password: password)
        : await auth.signUp(
            email: email,
            password: password,
            fullName: '${_firstName.text.trim()} ${_lastName.text.trim()}'
                .trim(),
          );

    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    if (_mode == LoginMode.signUp && error.startsWith('Account created.')) {
      setState(() {
        _mode = LoginMode.signIn;
        _verificationPending = true;
        _signupNotice = error;
      });
      _startResendCooldown();
      return;
    }
    if (_mode == LoginMode.signIn && error.contains('not verified yet')) {
      setState(() {
        _verificationPending = false;
        _signupNotice = error;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _resendConfirmation() async {
    if (_resendingConfirmation || _resendCooldownSeconds > 0) return;
    final auth = context.read<AuthProvider>();
    setState(() => _resendingConfirmation = true);
    final error = await auth.resendSignupConfirmation(_email.text);
    if (!mounted) return;
    setState(() => _resendingConfirmation = false);
    if (error == null) {
      setState(() {
        _verificationPending = true;
        _signupNotice =
            'A 6-digit verification code was sent to ${_email.text.trim()}.';
      });
      _verificationCode.clear();
      _startResendCooldown();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? 'Verification code sent. Check your inbox and spam folder.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;
    final isSignIn = _mode == LoginMode.signIn;
    final isVerifying = _verificationPending;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isVerifying
              ? 'Verify email'
              : (isSignIn ? 'Sign in' : 'Create account'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: [cs.primary, cs.primary.withValues(alpha: 0.78)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 29,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    child: const Icon(
                      Icons.directions_car_filled_outlined,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'APNI GARI',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        height: 1.2,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.verified_user_outlined,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text(
              isVerifying
                  ? 'Check your email'
                  : (isSignIn ? 'Welcome back' : 'Join Apni Gari'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              isVerifying
                  ? 'Enter the 6-digit code sent to ${_email.text.trim()} to verify your account.'
                  : (isSignIn
                        ? 'Sign in to post cars and message sellers.'
                        : 'Create an account to start selling your car. '
                              'Your name shows on your listings.'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            if (auth.authNotice != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(auth.authNotice!),
              ),
              const SizedBox(height: 18),
            ],
            if (_signupNotice != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(_signupNotice!),
              ),
              if (!_verificationPending)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed:
                        _resendingConfirmation || _resendCooldownSeconds > 0
                        ? null
                        : _resendConfirmation,
                    icon: _resendingConfirmation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.mark_email_unread_outlined),
                    label: Text(
                      _resendCooldownSeconds > 0
                          ? 'Resend in ${_resendCooldownSeconds}s'
                          : 'Resend confirmation email',
                    ),
                  ),
                ),
              const SizedBox(height: 18),
            ],
            if (!isSignIn && !isVerifying) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.mark_email_unread_outlined,
                      color: cs.onTertiaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'After creating your account, enter the 6-digit code sent to your email to verify it.',
                        style: TextStyle(color: cs.onTertiaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isSignIn && !isVerifying) ...[
                    TextFormField(
                      controller: _firstName,
                      textCapitalization: TextCapitalization.words,
                      enabled: !auth.isLoading,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                        hintText: 'e.g. Ahmed',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: _validateName,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _lastName,
                      textCapitalization: TextCapitalization.words,
                      enabled: !auth.isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Last name',
                        hintText: 'e.g. Khan',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: _validateName,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    enabled: !auth.isLoading && !isVerifying,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      final ok = RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(value);
                      return ok ? null : 'Enter a valid email';
                    },
                  ),
                  if (!isVerifying) const SizedBox(height: 14),
                  if (!isVerifying)
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      enabled: !auth.isLoading,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Password must be at least 6 characters'
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  if (isVerifying) ...[
                    _buildVerificationCodeField(auth.isLoading),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed:
                            _resendingConfirmation || _resendCooldownSeconds > 0
                            ? null
                            : _resendConfirmation,
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          _resendCooldownSeconds > 0
                              ? 'Resend in ${_resendCooldownSeconds}s'
                              : 'Resend code',
                        ),
                      ),
                    ),
                  ],
                  if (isSignIn && !isVerifying) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: auth.isLoading
                            ? null
                            : () => Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => ForgotPasswordScreen(
                                    initialEmail: _email.text.trim(),
                                  ),
                                ),
                              ),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: auth.isLoading ? null : _submit,
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isVerifying
                                ? 'Verify email'
                                : (isSignIn ? 'Sign in' : 'Create account'),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (!isVerifying)
              TextButton(
                onPressed: auth.isLoading
                    ? null
                    : () => setState(() {
                        _mode = isSignIn ? LoginMode.signUp : LoginMode.signIn;
                      }),
                child: Text(
                  isSignIn
                      ? 'New here? Create an account'
                      : 'Already have an account? Sign in',
                ),
              ),
            if (!isSignIn && !isVerifying) ...[
              const SizedBox(height: 4),
              Text(
                'Create your account with your email and password.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _validateName(String? input) {
    final value = input?.trim() ?? '';
    if (value.isEmpty) return 'Enter your name';
    // Accept letters from any language, with spaces, apostrophes, and hyphens.
    if (!RegExp(
      r"^[\p{L}\p{M}]+(?:[ '\u2019-][\p{L}\p{M}]+)*$",
      unicode: true,
    ).hasMatch(value)) {
      return 'Use letters only (spaces, apostrophes, and hyphens are okay)';
    }
    return null;
  }

  Widget _buildVerificationCodeField(bool isLoading) {
    final colorScheme = Theme.of(context).colorScheme;
    final code = _verificationCode.text;
    final activeIndex = code.length.clamp(0, 5);

    return Semantics(
      label: 'Six-digit email verification code',
      child: SizedBox(
        height: 64,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Row(
              children: List.generate(6, (index) {
                final hasDigit = index < code.length;
                final isActive =
                    _verificationFocusNode.hasFocus &&
                    index == activeIndex &&
                    !isLoading;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index == 5 ? 0 : 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      hasDigit ? code[index] : '-',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: hasDigit
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.55,
                                  ),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                );
              }),
            ),
            TextFormField(
              controller: _verificationCode,
              focusNode: _verificationFocusNode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              maxLength: 6,
              autofocus: true,
              enabled: !isLoading,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.transparent),
              cursorColor: Colors.transparent,
              decoration: const InputDecoration(
                counterText: '',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
    );
  }
}
