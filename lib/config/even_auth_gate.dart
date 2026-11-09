import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'even_supabase_config.dart';

class EvenAuthGate extends StatefulWidget {
  const EvenAuthGate({super.key, required this.child, required this.onProfileCompleted});
  final Widget child;
  final Future<void> Function(String displayName) onProfileCompleted;

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
      initialData: AuthState(AuthChangeEvent.initialSession, client.auth.currentSession),
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        if (session == null) return const _EvenSignInPage();
        if (session.user.appMetadata['provider']?.toString() != 'google') return widget.child;
        return FutureBuilder<Map<String, dynamic>?>(
          future: client.from('profiles').select('username').eq('id', session.user.id).maybeSingle(),
          builder: (context, profile) {
            if (profile.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (profile.hasError) {
              return Scaffold(body: Center(child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_outlined, size: 42),
                  const SizedBox(height: 16),
                  const Text('Could not load your profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('Check your connection and make sure the EVEN profile migration has been applied.', textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  FilledButton(onPressed: () => setState(() {}), child: const Text('Try again')),
                ]),
              )));
            }
            final username = profile.data?['username']?.toString().trim() ?? '';
            if (username.isEmpty) {
              return _GoogleProfileSetupPage(
                user: session.user,
                onComplete: (displayName) async {
                  await widget.onProfileCompleted(displayName);
                  if (mounted) setState(() {});
                },
              );
            }
            return widget.child;
          },
        );
      },
    );
  }
}

class _GoogleProfileSetupPage extends StatefulWidget {
  const _GoogleProfileSetupPage({required this.user, required this.onComplete});
  final User user;
  final Future<void> Function(String displayName) onComplete;
  @override
  State<_GoogleProfileSetupPage> createState() => _GoogleProfileSetupPageState();
}

class _GoogleProfileSetupPageState extends State<_GoogleProfileSetupPage> {
  late final TextEditingController _username;
  late final TextEditingController _displayName;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final metadata = widget.user.userMetadata ?? const <String, dynamic>{};
    final suggested = (metadata['full_name'] ?? metadata['name'] ?? '').toString().trim();
    _displayName = TextEditingController(text: suggested);
    final normalized = suggested.toLowerCase()
        .replaceAll(RegExp('[^a-z0-9_]+'), '_')
        .replaceAll(RegExp('^_+|_+$'), '');
    final suggestion = normalized.length > 20 ? normalized.substring(0, 20) : normalized;
    _username = TextEditingController(text: suggestion.length >= 3 ? suggestion : 'even_user');
  }

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _username.text.trim().toLowerCase();
    final displayName = _displayName.text.trim();
    if (!RegExp('^[a-z0-9_]{3,20}$').hasMatch(username)) {
      setState(() => _error = 'Username must be 3–20 characters: lowercase letters, numbers or underscores.');
      return;
    }
    if (displayName.isEmpty || displayName.length > 60) {
      setState(() => _error = 'Enter a display name of 1–60 characters.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final updated = await Supabase.instance.client.from('profiles').update({
        'username': username,
        'display_name': displayName,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.user.id).select('id').maybeSingle().timeout(const Duration(seconds: 15));
      if (updated == null) throw StateError('Your profile record was not found. Please sign out and sign in again.');
      await widget.onComplete(displayName);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.code == '23505'
            ? 'That username is already taken. Please choose another.'
            : 'Could not save your profile: ' + error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _saving = false; _error = 'Could not save your profile. Check your connection and try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(26),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.all_inclusive_rounded, size: 44, color: colors.primary),
            const SizedBox(height: 22),
            Text('Make EVEN yours', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Choose a unique username and the name your friends will see.', style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 24),
            TextField(controller: _username, enabled: !_saving, autocorrect: false,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(labelText: 'Unique username', prefixText: '@')),
            const SizedBox(height: 14),
            TextField(controller: _displayName, enabled: !_saving, textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Display name')),
            const SizedBox(height: 8),
            Text('Your username is unique. Your display name can be changed and does not need to be unique.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: colors.error)),
            ],
            const SizedBox(height: 22),
            FilledButton(onPressed: _saving ? null : _save, child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Continue')),
          ],
        )),
      ))),
    );
  }
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
    if (email.contains(' ') || !email.contains('@') || !email.substring(email.indexOf('@') + 1).contains('.')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      await _client.auth.signInWithOtp(email: email, shouldCreateUser: true);
      if (!mounted) return;
      setState(() { _codeSent = true; _notice = 'A one-time code has been sent to ' + email + '.'; });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not send the code: ' + error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    final token = _otp.text.trim();
    if (token.length < 6) {
      setState(() => _error = 'Enter the verification code from your email.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await _client.auth.verifyOTP(email: _email.text.trim(), token: token, type: OtpType.email);
    } catch (error) {
      if (mounted) setState(() => _error = 'Verification failed: ' + error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() { _busy = true; _error = null; });
    try {
      await _client.auth.signInWithOAuth(OAuthProvider.google, redirectTo: 'even://login-callback');
    } catch (error) {
      if (mounted) setState(() => _error = 'Google sign-in failed: ' + error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkConnection() async {
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      await _client.auth.getUser().timeout(const Duration(seconds: 12));
      if (mounted) setState(() => _notice = 'Supabase Auth is reachable.');
    } on AuthException {
      if (mounted) setState(() => _notice = 'Supabase Auth is reachable. Sign in to access your account.');
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not reach Supabase: ' + error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 66, alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(22)),
            child: Icon(Icons.all_inclusive_rounded, size: 34, color: colors.primary)),
          const SizedBox(height: 28),
          Text('EVEN', style: TextStyle(color: colors.primary, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2.2)),
          const SizedBox(height: 10),
          Text('Good to have you here.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8)),
          const SizedBox(height: 8),
          Text('Sign in to keep your groups, expenses and balances in sync.', style: TextStyle(color: colors.onSurfaceVariant, height: 1.45)),
          const SizedBox(height: 28),
          OutlinedButton.icon(onPressed: _busy ? null : _checkConnection,
            icon: const Icon(Icons.cloud_done_outlined), label: const Text('Check cloud connection')),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: _busy ? null : _google,
            icon: const Icon(Icons.g_mobiledata_rounded, size: 27), label: const Text('Continue with Google')),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: Divider(color: colors.outlineVariant)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR USE EMAIL', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2))),
            Expanded(child: Divider(color: colors.outlineVariant)),
          ]),
          const SizedBox(height: 18),
          TextField(controller: _email, enabled: !_busy && !_codeSent,
            keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded))),
          if (_codeSent) ...[
            const SizedBox(height: 12),
            TextField(controller: _otp, enabled: !_busy, keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode], maxLength: 8,
              decoration: const InputDecoration(labelText: 'Email verification code', prefixIcon: Icon(Icons.verified_user_outlined), counterText: '')),
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
          FilledButton(onPressed: _busy ? null : (_codeSent ? _verifyCode : _sendCode),
            child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_codeSent ? 'Verify and continue' : 'Continue with email')),
          if (_codeSent) TextButton(onPressed: _busy ? null : () => setState(() {
            _codeSent = false; _otp.clear(); _notice = null; _error = null;
          }), child: const Text('Change email address')),
          const SizedBox(height: 20),
          Text('By continuing, you agree to use EVEN responsibly. Your account keeps your shared expense data available across your devices.',
            textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11, height: 1.5)),
        ],
      )),
    ))));
  }
}

class _BackendConfigurationRequiredPage extends StatelessWidget {
  const _BackendConfigurationRequiredPage();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(body: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off_rounded, size: 48, color: colors.primary),
        const SizedBox(height: 20),
        Text('Secure sign-in is not configured', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        const Text('Build EVEN with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY. Never put a secret/service-role key in the Android app.', textAlign: TextAlign.center),
      ]),
    ))));
  }
}
