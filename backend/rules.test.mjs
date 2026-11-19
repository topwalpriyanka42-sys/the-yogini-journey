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
  where,
} from 'firebase/firestore';
import { getMetadata, ref, uploadBytes } from 'firebase/storage';

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

test('Storage serves published lesson media and rejects drafts and client uploads', async () => {
  const guest = environment.unauthenticatedContext().storage();
  const learner = environment.authenticatedContext('learner', verified).storage();
  const admin = environment.authenticatedContext('operator', { ...verified, admin: true }).storage();
  await assertSucceeds(getMetadata(ref(guest, publishedVideo)));
  await assertFails(getMetadata(ref(guest, draftVideo)));
  await assertFails(getMetadata(ref(guest, 'courses/private/intro/video.mp4')));
  await assertFails(uploadBytes(ref(learner, publishedVideo), new Uint8Array([2])));
  await assertFails(uploadBytes(ref(admin, publishedVideo), new Uint8Array([2])));
});
