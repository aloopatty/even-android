import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'even_supabase_config.dart';

/// Authentication gate for EVEN. Email sign-in uses a one-time verification
/// code; Google uses Supabase OAuth. No service-role key belongs in this app.
class EvenAuthGate extends StatefulWidget {
  const EvenAuthGate({super.key, required this.child});
  final Widget child;

  @override
  State<EvenAuthGate> createState() => _EvenAuthGateState();
}

class _EvenAuthGateState extends State<EvenAuthGate> {
  @override
  Widget build(BuildContext context) {
    if (!EvenSupabaseConfig.isConfigured) return const _BackendConfigurationRequiredPage();
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        client.auth.currentSession,
      ),
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        if (session != null) return widget.child;
        return const _EvenSignInPage();
      },
    );
  }
}

String _friendlyAuthError(Object error) {
  final message = error.toString();
  if (message.contains('Failed host lookup') ||
      message.contains('SocketException') ||
      message.contains('No address associated with hostname')) {
    return 'EVEN cannot reach its cloud server. Check your internet connection. '
        'If other apps work, the Supabase project URL in the Android build may be incorrect.';
  }
  if (message.contains('Invalid login credentials')) {
    return 'That verification code is invalid or expired. Request a new code and try again.';
  }
  if (message.contains('redirect') || message.contains('Redirect')) {
    return 'Google sign-in returned to EVEN, but the callback URL is not allowed. '
        'Add even://login-callback to Supabase Auth → URL Configuration → Redirect URLs.';
  }
  if (error is AuthException) return error.message;
  return 'Something went wrong while signing in. Please try again.';
}

class _EvenSignInPage extends StatefulWidget {
  const _EvenSignInPage();

  @override
  State<_EvenSignInPage> createState() => _EvenSignInPageState();
}

class _EvenSignInPageState extends State<_EvenSignInPage> {
  final _email = TextEditingController();
  final _otp = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      await _client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _notice = 'A verification code has been requested for $email. Check your inbox and spam folder.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    final email = _email.text.trim();
    final token = _otp.text.trim();
    if (token.length < 6) {
      setState(() => _error = 'Enter the verification code from your email.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() { _busy = true; _error = null; });
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'even://login-callback',
      );
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 66, height: 66,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(Icons.all_inclusive_rounded, size: 34, color: colors.primary),
                  ),
                  const SizedBox(height: 28),
                  Text('EVEN', style: TextStyle(
                    color: colors.primary, fontSize: 16,
                    fontWeight: FontWeight.w800, letterSpacing: 2.2,
                  )),
                  const SizedBox(height: 10),
                  Text('Good to have you here.',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800, letterSpacing: -0.8,
                    )),
                  const SizedBox(height: 8),
                  Text('Sign in to keep your groups, expenses and balances in sync.',
                    style: TextStyle(color: colors.onSurfaceVariant, height: 1.45)),
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _google,
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 27),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(child: Divider(color: colors.outlineVariant)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR USE EMAIL', style: TextStyle(
                        color: colors.onSurfaceVariant, fontSize: 10,
                        fontWeight: FontWeight.w700, letterSpacing: 1.2,
                      )),
                    ),
                    Expanded(child: Divider(color: colors.outlineVariant)),
                  ]),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _email,
                    enabled: !_busy && !_codeSent,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _otp,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      maxLength: 8,
                      decoration: const InputDecoration(
                        labelText: 'Email verification code',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                        counterText: '',
                      ),
                    ),
                  ],
                  if (_notice != null) ...[
                    const SizedBox(height: 12),
                    Text(_notice!, style: TextStyle(color: colors.primary)),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: colors.error)),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _busy ? null : (_codeSent ? _verifyCode : _sendCode),
                    child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_codeSent ? 'Verify and continue' : 'Continue with email'),
                  ),
                  if (_codeSent)
                    TextButton(
                      onPressed: _busy ? null : () => setState(() {
                        _codeSent = false; _otp.clear(); _notice = null; _error = null;
                      }),
                      child: const Text('Change email address'),
                    ),
                  const SizedBox(height: 20),
                  Text('By continuing, you agree to use EVEN responsibly. Your account keeps your shared expense data available across your devices.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11, height: 1.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fail closed: never silently open a local-only account when cloud auth is
/// required. The project URL and publishable key are supplied at build time.
class _BackendConfigurationRequiredPage extends StatelessWidget {
  const _BackendConfigurationRequiredPage();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 48, color: colors.primary),
                  const SizedBox(height: 24),
                  Text('EVEN', textAlign: TextAlign.center,
                    style: TextStyle(color: colors.primary, fontWeight: FontWeight.w900,
                      fontSize: 18, letterSpacing: 2)),
                  const SizedBox(height: 16),
                  Text('Secure sign-in is not configured',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text(
                    'EVEN requires its Supabase project URL and publishable key before sign-in. '
                    'This build will not open a local-only profile or pretend that cloud sync is active.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant, height: 1.5)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16)),
                    child: const Text(
                      'Build this app with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY. '
                      'Never put a secret/service-role key in the Android app.',
                      style: TextStyle(height: 1.5)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
