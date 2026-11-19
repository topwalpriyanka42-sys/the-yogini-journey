import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'firebase_backend.dart';
import 'pages.dart';

final demoProfileProvider = NotifierProvider<DemoProfile, String?>(
  DemoProfile.new,
);

class DemoProfile extends Notifier<String?> {
  @override
  String? build() => null;

  void start(String name) => state = name;
  void end() => state = null;
}

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  static const _slides = [
    (
      'Find your starting point',
      'Explore free yoga courses at beginner, intermediate and advanced levels.',
      'morning',
    ),
    (
      'Make space for the breath',
      'Discover traditional breathing practices in the Pranayama library.',
      'balance',
    ),
    (
      'Practice at your own pace',
      'Open a course to explore lessons, or continue as a guest.',
      'studio',
    ),
  ];

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final (title, description, image) = _slides[_index];
    final demo = ref.watch(authProvider) == null;
    final last = _index == _slides.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
        leading: _index == 0
            ? null
            : BackButton(onPressed: () => setState(() => _index--)),
        actions: [
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Continue as guest'),
          ),
        ],
      ),
      body: SafeArea(
        child: PageContent(
          maxWidth: 540,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Column(
                key: ValueKey(_index),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: AspectRatio(
                        aspectRatio: 1.6,
                        child: Image.asset(
                          'assets/$image.jpg',
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(description),
                ],
              ),
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: (_index + 1) / _slides.length,
              semanticsLabel:
                  'Onboarding step ${_index + 1} of ${_slides.length}',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: last
                  ? () => context.push('/register')
                  : () => setState(() => _index++),
              child: Text(
                last
                    ? (demo ? 'Create demo account' : 'Create account')
                    : 'Next',
              ),
            ),
            if (last)
              TextButton(
                onPressed: () => context.push('/login'),
                child: Text(demo ? 'Demo sign in' : 'Sign in'),
              ),
          ],
        ),
      ),
    );
  }
}

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key, required this.register, this.admin = false});

  final bool register;
  final bool admin;

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  bool _busy = false;
  String? _message;

  bool _validEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted) setState(() => _message = authError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    final auth = ref.read(authProvider);
    if (auth == null) {
      ref
          .read(demoProfileProvider.notifier)
          .start(widget.register ? _name.text.trim() : 'Demo learner');
      context.go('/profile');
      return;
    }
    final email = _email.text.trim();
    final password = _password.text;
    final name = _name.text.trim();
    await _run(() async {
      if (widget.register) {
        final account = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        // Keep the account usable if sending the verification email fails.
        // The profile offers a resend action.
        if (!mounted) return;
        try {
          await account.user?.updateDisplayName(name);
          await account.user?.sendEmailVerification();
        } catch (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(authError(error))));
        }
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
      if (mounted) context.go(widget.admin ? '/admin' : '/profile');
    });
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!_validEmail(email)) {
      setState(() => _message = 'Enter your email address first.');
      return;
    }
    await _run(() async {
      await ref.read(authProvider)!.sendPasswordResetEmail(email: email);
      if (mounted) {
        setState(
          () => _message =
              'If the address is registered, look for a password reset email.',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final register = widget.register;
    final demo = ref.watch(authProvider) == null;
    final title = widget.admin
        ? 'Administrator sign in'
        : register
        ? (demo ? 'Create demo account' : 'Create account')
        : (demo ? 'Demo sign in' : 'Sign in');
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: PageContent(
          maxWidth: 480,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            if (demo)
              const Text(
                'Use a sample email and password. This form opens a temporary demo profile on this device.',
              )
            else if (widget.admin)
              const Text('Use your verified administrator account.'),
            const SizedBox(height: 22),
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (register) ...[
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a name.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    decoration: InputDecoration(
                      labelText: demo ? 'Sample email' : 'Email',
                      hintText: demo ? 'learner@example.com' : null,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    validator: (value) => _validEmail(value ?? '')
                        ? null
                        : (demo
                              ? 'Enter a valid sample email.'
                              : 'Enter a valid email.'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    decoration: InputDecoration(
                      labelText: demo ? 'Sample password' : 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _hidePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    obscureText: _hidePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) {
                      if (demo || register) {
                        return (value?.length ?? 0) < 8
                            ? 'Enter at least 8 characters.'
                            : null;
                      }
                      return value == null || value.isEmpty
                          ? 'Enter your password.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      _busy
                          ? 'Please wait…'
                          : register
                          ? (demo ? 'Create profile' : 'Create account')
                          : 'Sign in',
                    ),
                  ),
                ],
              ),
            ),
            if (_message case final message?)
              Semantics(liveRegion: true, child: Text(message)),
            if (!demo && !register)
              TextButton(
                onPressed: _busy ? null : _resetPassword,
                child: const Text('Forgot password?'),
              ),
            if (!widget.admin)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => context.pushReplacement(
                        register ? '/login' : '/register',
                      ),
                child: Text(
                  register
                      ? 'Already exploring? Sign in'
                      : (demo ? 'Create demo account' : 'Create account'),
                ),
              ),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Continue as guest'),
            ),
          ],
        ),
      ),
    );
  }
}
