import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalog.dart';
import 'firebase_backend.dart';

class Lesson {
  const Lesson(this.id, this.title, this.order, {this.youtubeVideoId});

  final String id;
  final String title;
  final int order;
  final String? youtubeVideoId;
}

final courseCatalogProvider = StreamProvider<List<Course>>((ref) {
  final database = ref.watch(firestoreProvider);
  if (database == null) return Stream.value(ref.watch(coursesProvider));
  return database
      .collection('courses')
      .where('published', isEqualTo: true)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map(_courseFromDocument).toList()
              ..sort((a, b) => a.title.compareTo(b.title)),
      );
});

Course _courseFromDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  final image = data['thumbnail'];
  return Course(
    doc.id,
    data['title'] as String,
    Level.values.byName(data['level'] as String),
    data['minutes'] as int,
    image is String && courseThumbnails.containsKey(image) ? image : 'studio',
    data['description'] as String,
  );
}

final lessonsProvider = StreamProvider.autoDispose.family<List<Lesson>, String>(
  (ref, courseId) {
    final database = ref.watch(firestoreProvider)!;
    return database
        .collection('courses')
        .doc(courseId)
        .collection('lessons')
        .where('published', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => Lesson(
                      doc.id,
                      doc.data()['title'] as String,
                      doc.data()['order'] as int,
                      youtubeVideoId: doc.data()['youtubeVideoId'] as String?,
                    ),
                  )
                  .toList()
                ..sort((a, b) {
                  final byOrder = a.order.compareTo(b.order);
                  return byOrder == 0 ? a.id.compareTo(b.id) : byOrder;
                }),
        );
  },
);

CollectionReference<Map<String, dynamic>> progressCollection(
  FirebaseFirestore db,
  String uid,
  String courseId,
) => db
    .collection('users')
    .doc(uid)
    .collection('courses')
    .doc(courseId)
    .collection('lesson_progress');

final lessonProgressProvider = StreamProvider.autoDispose
    .family<Set<String>, ({String uid, String courseId})>(
      (ref, key) =>
          progressCollection(
            ref.watch(firestoreProvider)!,
            key.uid,
            key.courseId,
          ).snapshots().map(
            (snapshot) => snapshot.docs.map((doc) => doc.id).toSet(),
          ),
    );
