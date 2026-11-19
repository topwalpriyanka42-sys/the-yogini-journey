import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

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

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
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
      'Open a course to preview a lesson, or try the demo account screens.',
      'studio',
    ),
  ];

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final (title, description, image) = _slides[_index];
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
              child: Text(last ? 'Create demo account' : 'Next'),
            ),
            if (last)
              TextButton(
                onPressed: () => context.push('/login'),
                child: const Text('Demo sign in'),
              ),
          ],
        ),
      ),
    );
  }
}

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key, required this.register});

  final bool register;

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    ref
        .read(demoProfileProvider.notifier)
        .start(widget.register ? _name.text.trim() : 'Demo learner');
    context.go('/profile');
  }

  @override
  Widget build(BuildContext context) {
    final register = widget.register;
    final title = register ? 'Create demo account' : 'Demo sign in';
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: PageContent(
          maxWidth: 480,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Use a sample email and password. This form opens a temporary demo profile on this device.',
            ),
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
                    decoration: const InputDecoration(
                      labelText: 'Sample email',
                      hintText: 'learner@example.com',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(value?.trim() ?? '')
                        ? null
                        : 'Enter a valid sample email.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Sample password',
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
                    validator: (value) => (value?.trim().length ?? 0) < 8
                        ? 'Enter at least 8 characters.'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submit,
                    child: Text(register ? 'Create profile' : 'Sign in'),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () =>
                  context.pushReplacement(register ? '/login' : '/register'),
              child: Text(
                register ? 'Already exploring? Sign in' : 'Create demo account',
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
