import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'certificate_client.dart';
import 'firebase_backend.dart';

class YogaChatPage extends ConsumerWidget {
  const YogaChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authUserProvider);
    if (ref.watch(firebaseAppProvider) != null && account.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = account.asData?.value;
    return _Chat(key: ValueKey(user?.uid), user: user);
  }
}

class _Chat extends StatefulWidget {
  const _Chat({super.key, required this.user});

  final User? user;

  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  final _input = TextEditingController();
  final _list = ScrollController();
  late final _prefs = SharedPreferencesAsync();
  final _http = http.Client();
  final _messages = <Map<String, String>>[];
  bool _loading = true;
  bool _sending = false;
  String _language = 'en';
  String? _status;

  String get _historyKey => 'yoga-chat-v1:${widget.user?.uid ?? "guest"}';
  bool get _live =>
      certificateServer != null && widget.user?.emailVerified == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _list.dispose();
    _http.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final text = await _prefs.getString(_historyKey);
      if (!mounted || text == null) return;
      final rows = jsonDecode(text) as List;
      final saved = rows
          .map((row) => Map<String, String>.from(row as Map))
          .toList();
      _messages.addAll(saved);
    } catch (_) {
      // Local chat still works if the device's history is unavailable.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _persist() async {
    try {
      await _prefs.setString(_historyKey, jsonEncode(_messages));
    } catch (_) {
      if (mounted) {
        setState(
          () => _status = 'Chat history could not be saved on this phone.',
        );
      }
    }
  }

  Future<void> _clear() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear chat history?'),
        content: const Text('This removes the saved messages from this phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _messages.clear();
      _status = null;
    });
    await _persist();
  }

  Future<({String text, String mode})?> _askWorker(String language) async {
    final token = await widget.user!.getIdToken();
    if (token == null) return null;
    final recent = _messages.skip(
      _messages.length > 7 ? _messages.length - 7 : 0,
    );
    final request =
        http.Request('POST', certificateServer!.replace(path: '/api/chat'))
          ..followRedirects = false
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode({
            'language': language,
            'messages': [
              for (final row in recent)
                {'role': row['role'], 'content': _clip(row['content']!)},
            ],
          });
    final response = await _http
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 25));
    if (response.statusCode == 429) {
      if (mounted) _status = 'Live chat limit reached for today.';
      return null;
    }
    if (response.statusCode != 200) return null;
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final reply = data['reply'];
    if (reply is! String || reply.trim().isEmpty) return null;
    return (text: reply, mode: data['mode'] == 'safety' ? 'safety' : 'live');
  }

  String _clip(String text) =>
      text.length <= 500 ? text : String.fromCharCodes(text.runes.take(240));

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _list.hasClients) {
      _list.jumpTo(_list.position.maxScrollExtent);
    }
  });

  Future<void> _send() async {
    final question = _input.text.trim();
    if (_sending || _loading || question.isEmpty || question.length > 500) {
      return;
    }
    final language = _language;
    _input.clear();
    setState(() {
      _sending = true;
      _status = null;
      _messages.add({'role': 'user', 'content': question});
    });
    _scrollToEnd();

    ({String text, String mode})? reply;
    if (_live) {
      try {
        reply = await _askWorker(language);
      } catch (_) {
        // The demo remains available when the live service cannot answer.
      }
    }
    if (!mounted) return;
    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': reply?.text ?? demoYogaReply(question, language),
        'mode': reply?.mode ?? 'demo',
      });
      if (_messages.length > 30) {
        _messages.removeRange(0, _messages.length - 30);
      }
    });
    _scrollToEnd();
    await _persist();
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yoga chat'),
        actions: [
          IconButton(
            tooltip: 'Clear chat history',
            icon: const Icon(Icons.delete_outline),
            onPressed: _messages.isEmpty || _sending ? null : _clear,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (code, title) in [
                        ('en', 'English'),
                        ('hi', 'हिंदी'),
                      ])
                        ChoiceChip(
                          label: Text(title),
                          selected: _language == code,
                          onSelected: (_) => setState(() => _language = code),
                        ),
                    ],
                  ),
                  Text(
                    _live
                        ? 'Live replies send recent messages to Cloudflare. Avoid sharing private details. History is saved on this phone.'
                        : 'Demo replies are generated on this phone. Verify your email and sign in for live chat.',
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _messages.isEmpty
                        ? Center(
                            child: Text(
                              _language == 'hi'
                                  ? 'योग, ध्यान या सामान्य श्वास अभ्यास के बारे में पूछें।'
                                  : 'Ask about beginner yoga, meditation or gentle breathing.',
                            ),
                          )
                        : ListView.builder(
                            controller: _list,
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final row = _messages[index];
                              final mine = row['role'] == 'user';
                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: .9,
                                  alignment: mine
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Card(
                                    color: mine
                                        ? colors.secondaryContainer
                                        : colors.surfaceContainer,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (row['mode'] == 'demo')
                                            Text(
                                              'Demo reply',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall,
                                            ),
                                          SelectableText(row['content']!),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (_status case final status?)
                    Semantics(liveRegion: true, child: Text(status)),
                  if (_sending)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Preparing reply',
                    ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          maxLength: 500,
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: _language == 'hi'
                                ? 'अपना सवाल लिखें'
                                : 'Your question',
                            counterText: '',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Send question',
                        icon: const Icon(Icons.send),
                        onPressed: _sending || _loading ? null : _send,
                      ),
                    ],
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

String demoYogaReply(String input, String language) {
  final hi = language == 'hi';
  final message = input.toLowerCase();
  if (RegExp(
    r'chest pain|cannot breathe|can.t breathe|difficulty breathing|fainted|सीने में दर्द|छाती में दर्द|साँस नहीं|सांस नहीं|बेहोश',
  ).hasMatch(message)) {
    return hi
        ? 'अगर सीने में दर्द, साँस लेने में कठिनाई या बेहोशी हो रही है, तो अभ्यास रोकें और तुरंत आपातकालीन चिकित्सा सहायता लें।'
        : 'If you have chest pain, difficulty breathing, or fainting, stop practicing and seek emergency medical help now.';
  }
  if (RegExp(
    r'diagnos|prescrib|medication|medicine|dosage|cure|treat |pregnan|injur|इलाज|दवाई|दवा|निदान|गर्भ',
  ).hasMatch(message)) {
    return hi
        ? 'इन लक्षणों या आपके लिए योग की उपयुक्तता के बारे में किसी योग्य स्वास्थ्य पेशेवर से बात करें।'
        : 'A qualified health professional can assess your symptoms and advise whether yoga is appropriate for you.';
  }
  if (RegExp(r'breath|pranayam|pranayama|श्वास|साँस|सांस|प्राणायाम')
      .hasMatch(message)) {
    return hi
        ? 'आराम से बैठें और साँस को सामान्य रखें। साँस रोकने या ज़ोर लगाने की ज़रूरत नहीं है। हल्के अभ्यास के लिए Pranayama टैब में Deep Breathing देखें।'
        : 'Sit comfortably and let your breath stay natural. Avoid holding or forcing it. For a gentle introduction, try Deep Breathing in the Pranayama tab.';
  }
  if (RegExp(r'meditat|ध्यान').hasMatch(message)) {
    return hi
        ? 'आराम से बैठकर कुछ पलों के लिए अपनी सामान्य साँस पर ध्यान दें। ध्यान भटके तो धीरे से साँस पर लौटें।'
        : 'Sit comfortably and notice your natural breath for a few moments. When your attention wanders, gently return to the breath.';
  }
  return hi
      ? 'शुरुआत के लिए Courses में Beginner स्तर चुनें। आरामदायक हरकत और सामान्य साँस के साथ अभ्यास करें। दर्द या चक्कर आने पर रुकें।'
      : 'Start with a Beginner course in the Courses tab. Keep movement comfortable and breathe naturally. Stop if you feel pain or dizziness.';
}
