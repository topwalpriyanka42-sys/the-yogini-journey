import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';
import { test } from 'node:test';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { certificateIdPattern, certificateUrl, renderCertificatePdf } from '../certificates.mjs';

test('generates a branded PDF with a verification URL and Hindi name support', async () => {
  const certificateId = randomUUID();
  const url = certificateUrl('demo-yogini', certificateId);
  assert.equal(url.protocol, 'https:');
  assert.equal(url.searchParams.get('code'), certificateId);
  const pdf = await renderCertificatePdf({
    certificateId,
    courseTitle: 'Morning Yoga',
    learnerName: 'प्रियंका Sharma',
    completedAt: Timestamp.fromMillis(0),
  }, url);
  assert.equal(pdf.subarray(0, 5).toString(), '%PDF-');
  assert.ok(pdf.byteLength > 10000);
  assert.match(pdf.toString('latin1'), /\/Count 1\b/);
});

test('issues once after the last lesson, protects private data, and verifies an opted-in certificate', {
  skip: !process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST ||
    !process.env.YOGINI_FUNCTIONS_URL,
  timeout: 60000,
}, async () => {
  const app = initializeApp({ projectId: 'demo-yogini' }, 'certificates-test');
  const db = getFirestore(app);
  const auth = getAuth(app);
  const uid = 'certificate-learner';
  const other = 'certificate-other';
  const courseId = 'certificate-course';
  const base = process.env.YOGINI_FUNCTIONS_URL;
  const password = 'emulator-test-password';
  const learner = 'प्रियंका <Student>';
  const course = db.collection('courses').doc(courseId);
  const user = db.collection('users').doc(uid);
  const progress = user.collection('courses').doc(courseId).collection('lesson_progress');
  const record = user.collection('certificates').doc(courseId);

  async function tokenFor(id, emailVerified, displayName) {
    const email = `${id}@example.test`;
    await auth.createUser({ uid: id, email, password, emailVerified, displayName });
    const login = await fetch(
      `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=test`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, returnSecureToken: true }),
      },
    );
    assert.equal(login.status, 200);
    return (await login.json()).idToken;
  }

  async function call(method, token, data) {
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers.Authorization = `Bearer ${token}`;
    const res = await fetch(`${base}/${method}`, { method: 'POST', headers, body: JSON.stringify({ data }) });
    return { status: res.status, body: await res.json() };
  }

  try {
    const token = await tokenFor(uid, true, learner);
    const otherToken = await tokenFor(other, true, 'Other learner');
    const unverifiedToken = await tokenFor('certificate-unverified', false, 'Unverified learner');
    assert.equal((await call('issueCertificate', null, { courseId })).status, 401);
    assert.equal((await call('issueCertificate', unverifiedToken, { courseId })).body.error.status, 'FAILED_PRECONDITION');

    await course.set({ title: 'Morning Yoga', published: true });
    await Promise.all([
      course.collection('lessons').doc('intro').set({ published: true }),
      course.collection('lessons').doc('practice').set({ published: true }),
      course.collection('lessons').doc('draft').set({ published: false }),
    ]);
    await progress.doc('intro').set({ completedAt: Timestamp.fromMillis(1000) });
    const incomplete = await call('issueCertificate', token, { courseId, shareConsent: true });
    assert.equal(incomplete.body.error.status, 'FAILED_PRECONDITION');
    assert.equal((await record.get()).exists, false);
    await progress.doc('practice').set({ completedAt: Timestamp.fromMillis(2000) });

    let issued;
    for (let attempt = 0; attempt < 30; attempt += 1) {
      issued = await record.get();
      if (issued.exists) break;
      await delay(500);
    }
    assert.ok(issued.exists, 'final progress write must issue automatically');
    const id = issued.get('certificateId');
    assert.match(id, certificateIdPattern);
    assert.equal(issued.get('completedAt').toMillis(), 2000);
    assert.equal(issued.get('learnerName'), learner);
    assert.equal(issued.get('shareEnabled'), false);
    assert.equal(issued.get('lessonCount'), 2);
    const verification = `${base}/verifyCertificate?code=${id}`;
    assert.equal((await fetch(verification)).status, 404);

    const pdf = await call('downloadCertificate', token, { courseId });
    assert.equal(pdf.status, 200);
    assert.equal(Buffer.from(pdf.body.result.pdfBase64, 'base64').subarray(0, 5).toString(), '%PDF-');
    assert.equal((await call('downloadCertificate', otherToken, { courseId })).status, 404);

    const retry = await Promise.all([
      call('issueCertificate', token, { courseId, shareConsent: true }),
      call('issueCertificate', token, { courseId }),
    ]);
    assert.deepEqual(retry.map(({ body }) => body.result.certificateId), [id, id]);
    const publicPage = await fetch(verification);
    assert.equal(publicPage.status, 200);
    const html = await publicPage.text();
    assert.match(html, /&lt;Student&gt;/);
    assert.doesNotMatch(html, /<Student>|@example\.test/);
    const publicPdf = await fetch(`${verification}&format=pdf`);
    assert.equal(publicPdf.headers.get('content-type'), 'application/pdf');
    assert.equal((await call('issueCertificate', token, { courseId, shareConsent: false })).status, 200);
    assert.equal((await fetch(verification)).status, 404);
    assert.equal((await user.collection('certificates').get()).size, 1);
  } finally {
    await deleteApp(app);
  }
});
