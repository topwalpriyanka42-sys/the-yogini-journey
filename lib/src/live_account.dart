import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'admin_catalog.dart';
import 'firebase_backend.dart';
import 'pages.dart';

final _adminAccessProvider = FutureProvider.autoDispose<bool>((ref) async {
  final uid = ref.watch(
    authUserProvider.select((session) => session.asData?.value?.uid),
  );
  final user = ref.read(authProvider)?.currentUser;
  final database = ref.watch(firestoreProvider);
  if (uid == null || user == null || user.uid != uid || database == null) {
    return false;
  }
  final token = await user.getIdTokenResult(true);
  if (token.claims?['admin'] != true ||
      token.claims?['email_verified'] != true) {
    return false;
  }
  // Check the current server policy rather than trusting cached local data.
  await database
      .collection('admin_audit_logs')
      .limit(1)
      .get(const GetOptions(source: Source.server));
  return true;
});

class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = ref.watch(authUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator access'),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
      ),
      body: SafeArea(
        child: PageContent(
          children: [
            if (auth == null)
              const Text('Administrator access requires a Firebase build.')
            else if (user.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (user.hasError)
              const Text('Could not check the current session.')
            else if (user.asData?.value == null)
              FilledButton(
                onPressed: () => context.push('/admin/sign-in'),
                child: const Text('Administrator sign in'),
              )
            else
              ref
                  .watch(_adminAccessProvider)
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Column(
                      children: [
                        const Text(
                          'Administrator access could not be verified by the server.',
                        ),
                        TextButton(
                          onPressed: () => ref.invalidate(_adminAccessProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                    data: (allowed) => allowed
                        ? const AdminCatalog()
                        : const Text(
                            'This account needs a verified email and an administrator role.',
                          ),
                  ),
            if (auth != null && user.asData?.value != null)
              TextButton(
                onPressed: () => context.push('/admin/sign-in'),
                child: const Text('Sign in with another account'),
              ),
          ],
        ),
      ),
    );
  }
}

class LiveProfile extends ConsumerStatefulWidget {
  const LiveProfile({super.key});

  @override
  ConsumerState<LiveProfile> createState() => _LiveProfileState();
}

class _LiveProfileState extends ConsumerState<LiveProfile> {
  bool _busy = false;
  String? _status;

  Future<void> _run(Future<void> Function() action, [String? success]) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await action();
      if (mounted) setState(() => _status = success);
    } catch (error) {
      if (mounted) setState(() => _status = authError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editName(User user) async {
    var entered = user.displayName ?? '';
    final form = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name on future certificates'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: entered,
            decoration: const InputDecoration(labelText: 'Full name'),
            textCapitalization: TextCapitalization.words,
            maxLength: 120,
            onChanged: (value) => entered = value,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter your name.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, entered.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && mounted) {
      await _run(() => user.updateDisplayName(name), 'Profile name saved.');
    }
  }

  Future<void> _delete(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently removes your login and starts deletion of your saved data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) await _run(user.delete);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider)!;
    return ref
        .watch(authUserProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text('Could not read your account.'),
          data: (user) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                user?.displayName ??
                    (user == null ? 'Guest profile' : 'Your profile'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (user == null) ...[
                FilledButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('Sign in'),
                ),
                OutlinedButton(
                  onPressed: () => context.push('/register'),
                  child: const Text('Create account'),
                ),
              ] else ...[
                if (user.email case final email?) Text(email),
                if (!user.emailVerified) ...[
                  const Text('Verify your email to save lesson progress.'),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            user.sendEmailVerification,
                            'Verification email sent.',
                          ),
                    child: const Text('Resend verification email'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            await user.reload();
                            await auth.currentUser?.getIdToken(true);
                          }),
                    child: const Text('Check verification'),
                  ),
                ],
                TextButton(
                  onPressed: _busy ? null : () => _editName(user),
                  child: const Text('Edit certificate name'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _run(auth.signOut),
                  child: const Text('Sign out'),
                ),
                if (const bool.fromEnvironment(
                  'FIREBASE_ACCOUNT_DELETION_ENABLED',
                ))
                  TextButton(
                    onPressed: _busy ? null : () => _delete(user),
                    child: const Text('Delete account'),
                  ),
              ],
              TextButton(
                onPressed: () => context.push('/admin'),
                child: const Text('Administrator access'),
              ),
              if (_status case final status?)
                Semantics(liveRegion: true, child: Text(status)),
            ],
          ),
        );
  }
}
