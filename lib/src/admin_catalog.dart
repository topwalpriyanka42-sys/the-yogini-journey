import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'catalog.dart';
import 'firebase_backend.dart';
import 'pages.dart';

typedef _Document = DocumentSnapshot<Map<String, dynamic>>;
typedef _Collection = CollectionReference<Map<String, dynamic>>;

const _thumbnails = {
  'morning': 'Morning Yoga',
  'balance': 'Balance',
  'studio': 'Studio',
};
const _maxVideoBytes = 100 * 1024 * 1024;

class AdminCatalog extends ConsumerWidget {
  const AdminCatalog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(firestoreProvider)!.collection('courses');
    final storage = ref.watch(storageProvider)!;
    return _AdminList(
      collection: courses,
      newLabel: 'Add course',
      onAdd: () => _openEditor(context, courses.doc(), null, storage, false),
      onOpen: (doc) =>
          _openEditor(context, doc.reference, doc.data(), storage, false),
    );
  }
}

Future<void> _openEditor(
  BuildContext context,
  DocumentReference<Map<String, dynamic>> document,
  Map<String, dynamic>? data,
  FirebaseStorage storage,
  bool lesson,
) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => _Editor(
      document: document,
      data: data,
      storage: storage,
      lesson: lesson,
    ),
  ),
);

class _AdminList extends StatefulWidget {
  const _AdminList({
    required this.collection,
    required this.newLabel,
    required this.onAdd,
    required this.onOpen,
  });

  final _Collection collection;
  final String newLabel;
  final VoidCallback onAdd;
  final ValueChanged<_Document> onOpen;

  @override
  State<_AdminList> createState() => _AdminListState();
}

class _AdminListState extends State<_AdminList> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream = widget.collection
      .snapshots();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        onPressed: widget.onAdd,
        icon: const Icon(Icons.add),
        label: Text(widget.newLabel),
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
              children: [
                const Text(
                  'Could not load this list. Check connection and Firebase rules.',
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _stream = widget.collection.snapshots()),
                  child: const Text('Retry'),
                ),
              ],
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Text('Nothing here yet.');
          return Column(
            children: [
              for (final doc in docs)
                ListTile(
                  title: Text(doc.data()['title']?.toString() ?? doc.id),
                  subtitle: Text(
                    doc.data()['published'] == true ? 'Published' : 'Draft',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => widget.onOpen(doc),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _Editor extends StatefulWidget {
  const _Editor({
    required this.document,
    required this.data,
    required this.storage,
    required this.lesson,
  });

  final DocumentReference<Map<String, dynamic>> document;
  final Map<String, dynamic>? data;
  final FirebaseStorage storage;
  final bool lesson;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.data?['title']?.toString(),
  );
  late final _description = TextEditingController(
    text:
        (widget.data?['description'] ??
                widget.data?['dascription'] ??
                widget.data?['descripition'])
            ?.toString(),
  );
  late final _number = TextEditingController(
    text:
        (widget.data?[widget.lesson ? 'order' : 'minutes'] ??
                (widget.lesson ? 1 : 15))
            .toString(),
  );
  late Level _level =
      Level.values
          .where((level) => level.name == widget.data?['level'])
          .firstOrNull ??
      Level.beginner;
  late String _thumbnail = _thumbnails.containsKey(widget.data?['thumbnail'])
      ? widget.data!['thumbnail'] as String
      : 'studio';
  late bool _saved = widget.data != null;
  late bool _published = widget.data?['published'] == true;
  bool _busy = false;
  double? _progress;
  String? _status;

  Reference get _video => widget.storage.ref(
    'courses/${widget.document.parent.parent!.id}/${widget.document.id}/video.mp4',
  );

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await action();
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(
          () => _status = switch (error.code) {
            'permission-denied' || 'unauthorized' => 'Firebase denied access. Check the deployed rules and your administrator sign-in.',
            'object-not-found' =>
              'Upload an MP4 before publishing this lesson.',
            _ =>
              'Could not finish (${error.code}). Check your connection and retry.',
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'Could not finish. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final number = int.parse(_number.text.trim());
    final data = <String, dynamic>{
      'title': _title.text.trim(),
      if (widget.lesson)
        'order': number
      else ...{
        'description': _description.text.trim(),
        'minutes': number,
        'level': _level.name,
        'thumbnail': _thumbnail,
      },
      if (!_saved) 'published': false,
    };
    await widget.document.set(data, SetOptions(merge: true));
    if (mounted) {
      setState(() {
        _saved = true;
        _status = 'Changes saved.';
      });
    }
  }

  Future<void> _upload() async {
    final source = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['mp4'],
    );
    if (source == null || !mounted) return;
    final size = source.lengthSync();
    if (source.extension?.toLowerCase() != 'mp4' ||
        (size != null && (size < 1 || size > _maxVideoBytes))) {
      setState(() => _status = 'Choose an MP4 file up to 100 MB.');
      return;
    }

    final directory = await Directory.systemTemp.createTemp('yogini-video-');
    try {
      final file = File('${directory.path}/video.mp4');
      final output = file.openWrite();
      var transferred = 0;
      try {
        await for (final bytes in source.readAsByteStream()) {
          transferred += bytes.length;
          if (!mounted || transferred > _maxVideoBytes) break;
          output.add(bytes);
          await output.flush();
        }
      } finally {
        await output.close();
      }
      if (!mounted) return;
      if (transferred < 1 || transferred > _maxVideoBytes) {
        setState(() => _status = 'Choose an MP4 file up to 100 MB.');
        return;
      }

      final upload = _video.putFile(
        file,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {'published': 'false'},
        ),
      );
      final subscription = upload.snapshotEvents.listen((snapshot) {
        if (mounted && snapshot.totalBytes > 0) {
          setState(
            () => _progress = snapshot.bytesTransferred / snapshot.totalBytes,
          );
        }
      }, onError: (Object _, StackTrace _) {});
      try {
        await upload;
        if (mounted) {
          setState(
            () => _status = 'Video uploaded. You can publish this lesson.',
          );
        }
      } finally {
        await subscription.cancel();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  }

  Future<void> _setPublished() async {
    final publish = !_published;
    if (publish) {
      if (!_form.currentState!.validate()) return;
      await _save();
    }

    if (widget.lesson && publish) {
      await _video.updateMetadata(
        SettableMetadata(customMetadata: {'published': 'true'}),
      );
      try {
        await widget.document.firestore.runTransaction((transaction) async {
          transaction.update(widget.document, {'published': true});
        });
      } catch (_) {
        try {
          await _video.updateMetadata(
            SettableMetadata(customMetadata: {'published': 'false'}),
          );
        } catch (_) {
          if (mounted) {
            setState(
              () => _status = 'Publishing failed. Check video access with Hide draft video before retrying.',
            );
          }
          return;
        }
        rethrow;
      }
    } else {
      await widget.document.update({'published': publish});
    }
    if (mounted) setState(() => _published = publish);
    if (widget.lesson && !publish) {
      try {
        await _video.updateMetadata(
          SettableMetadata(customMetadata: {'published': 'false'}),
        );
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') {
          if (mounted) {
            setState(
              () => _status = 'Lesson hidden. Could not update video access. Retry from the button below.',
            );
          }
          return;
        }
      }
    }
    if (mounted) {
      setState(() => _status = publish ? 'Published.' : 'Moved to draft.');
    }
  }

  Future<void> _hideDraftVideo() async {
    await _video.updateMetadata(
      SettableMetadata(customMetadata: {'published': 'false'}),
    );
    if (mounted) setState(() => _status = 'Draft video access updated.');
  }

  String? _requiredText(String? value, int maxLength) {
    if (value == null || value.trim().isEmpty) return 'Enter a value.';
    return value.trim().length > maxLength
        ? 'Use at most $maxLength characters.'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.lesson ? 'lesson' : 'course';
    final lessons = widget.document.collection('lessons');
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(_saved ? 'Edit $kind' : 'New $kind')),
        body: SafeArea(
          child: PageContent(
            maxWidth: 640,
            children: [
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_published ? 'Published' : 'Draft'),
                    TextFormField(
                      controller: _title,
                      enabled: !_busy,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: (value) => _requiredText(value, 120),
                    ),
                    if (!widget.lesson) ...[
                      TextFormField(
                        controller: _description,
                        enabled: !_busy,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                        validator: (value) => _requiredText(value, 2000),
                      ),
                      DropdownButtonFormField<Level>(
                        initialValue: _level,
                        decoration: const InputDecoration(labelText: 'Level'),
                        items: [
                          for (final level in Level.values)
                            DropdownMenuItem(
                              value: level,
                              child: Text(level.label),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _level = value!),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _thumbnail,
                        decoration: const InputDecoration(
                          labelText: 'Thumbnail',
                        ),
                        items: [
                          for (final item in _thumbnails.entries)
                            DropdownMenuItem(
                              value: item.key,
                              child: Text(item.value),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _thumbnail = value!),
                      ),
                    ],
                    TextFormField(
                      controller: _number,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: widget.lesson
                            ? 'Lesson order'
                            : 'Duration in minutes',
                      ),
                      validator: (value) {
                        final number = int.tryParse(value?.trim() ?? '');
                        final max = widget.lesson ? 10000 : 1440;
                        return number == null || number < 1 || number > max
                            ? 'Enter a number from 1 to $max.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : () => _run(_save),
                      child: const Text('Save'),
                    ),
                    if (_saved && widget.lesson && !_published) ...[
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _run(_upload),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Choose and upload MP4'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _run(_hideDraftVideo),
                        child: const Text('Hide draft video'),
                      ),
                    ],
                    if (_saved)
                      OutlinedButton(
                        onPressed: _busy ? null : () => _run(_setPublished),
                        child: Text(
                          _published ? 'Move to draft' : 'Publish $kind',
                        ),
                      ),
                    if (_busy) LinearProgressIndicator(value: _progress),
                    if (_status case final status?)
                      Semantics(liveRegion: true, child: Text(status)),
                  ],
                ),
              ),
              if (_saved && !widget.lesson) ...[
                const SizedBox(height: 24),
                Text('Lessons', style: Theme.of(context).textTheme.titleLarge),
                _AdminList(
                  collection: lessons,
                  newLabel: 'Add lesson',
                  onAdd: () => _openEditor(
                    context,
                    lessons.doc(),
                    null,
                    widget.storage,
                    true,
                  ),
                  onOpen: (doc) => _openEditor(
                    context,
                    doc.reference,
                    doc.data(),
                    widget.storage,
                    true,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
