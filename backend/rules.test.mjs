import { readFileSync } from 'node:fs';
import { after, before, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';
import { getMetadata, ref, updateMetadata, uploadBytes } from 'firebase/storage';

let environment;
const projectId = 'demo-yogini';
const progressPath = 'users/learner/courses/morning/lesson_progress/intro';
const publishedVideo = 'courses/morning/intro/video.mp4';
const draftVideo = 'courses/morning/draft/video.mp4';
const verified = { email_verified: true };

before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
    storage: { rules: readFileSync(new URL('../storage.rules', import.meta.url), 'utf8') },
  });
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const [path, data] of [
      ['courses/morning', { published: true }],
      ['courses/private', { published: false }],
      ['courses/morning/lessons/intro', { published: true }],
      ['courses/morning/lessons/draft', { published: false }],
      ['courses/private/lessons/intro', { published: true }],
      ['admin_audit_logs/entry', { action: 'example' }],
    ]) {
      await setDoc(doc(db, path), data);
    }
    for (const path of [publishedVideo, draftVideo, 'courses/private/intro/video.mp4']) {
      await uploadBytes(ref(context.storage(), path), new Uint8Array([1]), {
        contentType: 'video/mp4',
        customMetadata: { published: String(path === publishedVideo) },
      });
    }
  });
});

after(async () => {
  await environment?.cleanup();
});

test('guests can query only published courses and lessons', async () => {
  const db = environment.unauthenticatedContext().firestore();
  const publicCourses = query(collection(db, 'courses'), where('published', '==', true));
  const publicLessons = query(collection(db, 'courses/morning/lessons'), where('published', '==', true));
  await assertSucceeds(getDocs(publicCourses));
  await assertSucceeds(getDocs(publicLessons));
  await assertFails(getDocs(collection(db, 'courses')));
  await assertFails(getDocs(collection(db, 'courses/morning/lessons')));
  await assertFails(getDoc(doc(db, 'courses/private')));
  await assertFails(getDoc(doc(db, 'courses/private/lessons/intro')));
});

test('only a verified owner can save valid progress for an existing published lesson', async () => {
  const learner = environment.authenticatedContext('learner', verified).firestore();
  const stranger = environment.authenticatedContext('stranger', verified).firestore();
  const unverified = environment.authenticatedContext('learner').firestore();
  const progress = doc(learner, progressPath);
  await assertSucceeds(setDoc(progress, { completedAt: serverTimestamp() }));
  await assertSucceeds(getDoc(progress));
  await assertSucceeds(getDocs(collection(learner, 'users/learner/courses/morning/lesson_progress')));
  await assertFails(getDoc(doc(stranger, progressPath)));
  await assertFails(setDoc(doc(stranger, progressPath), { completedAt: serverTimestamp() }));
  await assertFails(setDoc(doc(unverified, progressPath), { completedAt: serverTimestamp() }));
  await assertFails(setDoc(progress, { completedAt: serverTimestamp(), certificateEligible: true }));
  await assertFails(setDoc(progress, { completedAt: new Date(0) }));
  await assertFails(setDoc(doc(learner, progressPath.replace('/intro', '/draft')), { completedAt: serverTimestamp() }));
  await assertFails(setDoc(doc(learner, progressPath.replace('/intro', '/missing')), { completedAt: serverTimestamp() }));
  await assertSucceeds(deleteDoc(progress));
});

test('audit logs require a verified admin claim and remain read-only', async () => {
  const learner = environment.authenticatedContext('learner', verified).firestore();
  const unverifiedAdmin = environment.authenticatedContext('unverified', { admin: true }).firestore();
  const admin = environment.authenticatedContext('operator', { ...verified, admin: true }).firestore();
  const audit = 'admin_audit_logs/entry';
  await assertFails(getDoc(doc(learner, audit)));
  await assertFails(getDoc(doc(unverifiedAdmin, audit)));
  await assertFails(setDoc(doc(learner, 'users/learner'), { admin: true }));
  await assertSucceeds(getDocs(query(collection(admin, 'admin_audit_logs'), limit(1))));
  await assertSucceeds(getDoc(doc(admin, 'courses/private')));
  await assertFails(setDoc(doc(admin, audit), { action: 'forged' }));
  await assertFails(setDoc(doc(admin, 'courses/new'), { published: true }));
});

test('Storage serves published media and permits only authorized draft uploads', async () => {
  const guest = environment.unauthenticatedContext().storage();
  const learner = environment.authenticatedContext('learner', verified).storage();
  const admin = environment.authenticatedContext('operator', { ...verified, admin: true }).storage();
  await assertSucceeds(getMetadata(ref(guest, publishedVideo)));
  await assertSucceeds(getMetadata(ref(learner, publishedVideo)));
  await assertFails(getMetadata(ref(guest, draftVideo)));
  await assertFails(getMetadata(ref(guest, 'courses/private/intro/video.mp4')));
  await assertFails(uploadBytes(ref(learner, publishedVideo), new Uint8Array([2])));
  await assertFails(uploadBytes(ref(admin, publishedVideo), new Uint8Array([2])));
  const draft = ref(admin, 'courses/morning/new/video.mp4');
  const videoMetadata = { contentType: 'video/mp4', customMetadata: { published: 'false' } };
  await assertFails(uploadBytes(ref(learner, draft.fullPath), new Uint8Array([2]), videoMetadata));
  await assertFails(uploadBytes(draft, new Uint8Array([2]), { ...videoMetadata, contentType: 'text/plain' }));
  await assertFails(uploadBytes(draft, new Uint8Array([2]), { ...videoMetadata, customMetadata: { published: 'true' } }));
  await assertSucceeds(uploadBytes(draft, new Uint8Array([2]), videoMetadata));
  await assertSucceeds(getMetadata(draft));
  await assertFails(getMetadata(ref(guest, draft.fullPath)));
  await assertSucceeds(updateMetadata(draft, { customMetadata: { published: 'true' } }));
  await assertSucceeds(getMetadata(ref(guest, draft.fullPath)));
  await assertFails(uploadBytes(ref(learner, draft.fullPath), new Uint8Array([3]), videoMetadata));
  await assertSucceeds(updateMetadata(draft, { customMetadata: { published: 'false' } }));
  await assertFails(getMetadata(ref(guest, draft.fullPath)));
  await assertSucceeds(uploadBytes(draft, new Uint8Array([3]), videoMetadata));
});

test('only verified administrators can edit and explicitly publish valid courses and lessons', async () => {
  const admin = environment.authenticatedContext('operator', { ...verified, admin: true }).firestore();
  const learner = environment.authenticatedContext('learner', verified).firestore();
  const guest = environment.unauthenticatedContext().firestore();
  const coursePath = 'courses/admin-test';
  const lessonPath = `${coursePath}/lessons/intro`;
  const draft = {
    title: 'Yoga', description: 'Introduction', level: 'beginner',
    minutes: 15, thumbnail: 'morning', published: false,
  };
  const lesson = { title: 'Start here', order: 1, published: false };
  await assertFails(setDoc(doc(learner, coursePath), draft));
  await assertFails(setDoc(doc(admin, coursePath), { ...draft, published: true }));
  await assertFails(setDoc(doc(admin, lessonPath), lesson));
  await assertSucceeds(setDoc(doc(admin, coursePath), draft));
  await assertFails(updateDoc(doc(admin, coursePath), { level: 'unknown' }));
  await assertFails(updateDoc(doc(admin, coursePath), { role: 'admin' }));
  await assertFails(getDoc(doc(guest, coursePath)));
  await assertSucceeds(setDoc(doc(admin, lessonPath), lesson));
  const youtubeId = 'aBcd-Ef_G12';
  await assertFails(updateDoc(doc(learner, lessonPath), { youtubeVideoId: youtubeId }));
  await assertFails(updateDoc(doc(admin, lessonPath), { youtubeVideoId: 'https://example.com/watch' }));
  await assertFails(updateDoc(doc(admin, lessonPath), { youtubeVideoId: 12345 }));
  await assertSucceeds(updateDoc(doc(admin, lessonPath), { youtubeVideoId: youtubeId }));
  await assertFails(updateDoc(doc(learner, lessonPath), { published: true }));
  await assertSucceeds(updateDoc(doc(admin, coursePath), { published: true }));
  await assertSucceeds(getDoc(doc(guest, coursePath)));
  await assertFails(getDoc(doc(guest, lessonPath)));
  await assertSucceeds(updateDoc(doc(admin, lessonPath), { published: true }));
  const publishedLesson = await assertSucceeds(getDoc(doc(guest, lessonPath)));
  if (publishedLesson.data().youtubeVideoId !== youtubeId) throw new Error('Missing published YouTube ID');
  await assertSucceeds(updateDoc(doc(admin, coursePath), { published: false }));
  await assertFails(getDoc(doc(guest, lessonPath)));
});

test('only the verified learner can enroll in a published course', async () => {
  const learner = environment.authenticatedContext('learner', verified).firestore();
  const stranger = environment.authenticatedContext('stranger', verified).firestore();
  const path = 'users/learner/enrollments/morning';
  await assertFails(setDoc(doc(stranger, path), { enrolledAt: serverTimestamp() }));
  await assertFails(setDoc(doc(learner, path.replace('morning', 'private')), { enrolledAt: serverTimestamp() }));
  await assertSucceeds(setDoc(doc(learner, path), { enrolledAt: serverTimestamp() }));
  await assertSucceeds(getDoc(doc(learner, path)));
  await assertFails(getDoc(doc(stranger, path)));
});

test('certificates are readable by their verified owner and writable only by the server', async () => {
  const path = 'users/learner/certificates/morning';
  const certificate = {
    certificateId: '00000000-0000-4000-8000-000000000000',
    courseTitle: 'Morning',
    shareEnabled: true,
    issuedAt: new Date(0),
  };
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), certificate);
  });
  const learner = environment.authenticatedContext('learner', verified).firestore();
  const stranger = environment.authenticatedContext('stranger', verified).firestore();
  const admin = environment.authenticatedContext('operator', { ...verified, admin: true }).firestore();
  const guest = environment.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(learner, path)));
  await assertSucceeds(getDocs(collection(learner, 'users/learner/certificates')));
  await assertFails(getDoc(doc(stranger, path)));
  await assertFails(getDoc(doc(guest, path)));
  await assertFails(getDoc(doc(admin, path)));
  await assertFails(updateDoc(doc(learner, path), { shareEnabled: false }));
  await assertFails(deleteDoc(doc(learner, path)));
  await assertFails(setDoc(doc(learner, path.replace('morning', 'fake')), certificate));
});
