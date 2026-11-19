import { getAuth } from 'firebase-admin/auth';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall, onRequest } from 'firebase-functions/v2/https';
import { certificateDate, certificateUrl, findCertificate, issueCourseCertificate, maxLessons, renderCertificatePdf } from './certificates.mjs';

const app = initializeApp();
const db = getFirestore(app);
const region = 'us-central1';
const projectId = app.options.projectId ?? process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT;

function verifiedUid(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in to continue.');
  if (request.auth.token.email_verified !== true) {
    throw new HttpsError('failed-precondition', 'Verify your email first.');
  }
  return request.auth.uid;
}

async function verifiedLearner(uid) {
  try {
    const learner = await getAuth(app).getUser(uid);
    if (!learner.disabled && learner.emailVerified) return learner;
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
  }
  throw new HttpsError('failed-precondition', 'An active account with a verified email is required.');
}

export const issueCertificate = onCall({ region, maxInstances: 5 }, async (request) => {
  const uid = verifiedUid(request);
  const learner = await verifiedLearner(uid);
  return {
    certificateId: await issueCourseCertificate(db, uid, request.data?.courseId, learner.displayName, {
      share: typeof request.data?.shareConsent === 'boolean' ? request.data.shareConsent : undefined,
    }),
  };
});

export const autoIssueCertificate = onDocumentWritten({
  document: 'users/{uid}/courses/{courseId}/lesson_progress/{lessonId}',
  region,
  maxInstances: 5,
  retry: true,
}, async (event) => {
  if (!event.data?.after.exists) return;
  const { uid, courseId } = event.params;
  const user = db.collection('users').doc(uid);
  if ((await user.collection('certificates').doc(courseId).get()).exists) return;

  const [lessons, completions] = await Promise.all([
    db.collection('courses').doc(courseId).collection('lessons')
      .where('published', '==', true).limit(maxLessons + 1).count().get(),
    user.collection('courses').doc(courseId).collection('lesson_progress').count().get(),
  ]);
  const required = lessons.data().count;
  if (!required || required > maxLessons || completions.data().count < required) return;

  try {
    const learner = await verifiedLearner(uid);
    await issueCourseCertificate(db, uid, courseId, learner.displayName);
  } catch (error) {
    if (!(error instanceof HttpsError) || error.code !== 'failed-precondition') throw error;
  }
});

export const downloadCertificate = onCall({ region, maxInstances: 5 }, async (request) => {
  const uid = verifiedUid(request);
  await verifiedLearner(uid);
  const courseId = request.data?.courseId;
  if (typeof courseId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(courseId)) {
    throw new HttpsError('invalid-argument', 'Select a valid course.');
  }
  const record = await db.collection('users').doc(uid).collection('certificates').doc(courseId).get();
  if (!record.exists) throw new HttpsError('not-found', 'Certificate not found.');
  const certificate = record.data();
  const pdf = await renderCertificatePdf(certificate, certificateUrl(projectId, certificate.certificateId));
  return { pdfBase64: pdf.toString('base64') };
});

function escapeHtml(text) {
  return String(text).replace(/[&<>"']/g, (char) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[char]);
}

export const verifyCertificate = onRequest({ region, maxInstances: 5 }, async (request, response) => {
  response.set({
    'Cache-Control': 'no-store',
    'X-Robots-Tag': 'noindex, nofollow',
    'X-Content-Type-Options': 'nosniff',
  });
  if (request.method !== 'GET') {
    response.set('Allow', 'GET').status(405).send('Use GET.');
    return;
  }
  try {
    const certificate = await findCertificate(db, request.query.code);
    if (certificate == null) {
      response.status(404).type('text/plain').send('Certificate not found.');
      return;
    }
    const verificationUrl = certificateUrl(projectId, certificate.certificateId);
    if (request.query.format === 'pdf') {
      const pdf = await renderCertificatePdf(certificate, verificationUrl);
      response.type('application/pdf')
        .attachment(`Yogini-${certificate.certificateId}.pdf`).send(pdf);
      return;
    }
    const download = new URL(verificationUrl);
    download.searchParams.set('format', 'pdf');
    response.set('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'");
    response.type('html').send(`<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Verified certificate | The Yogini Journey</title>
<style>body{margin:0;padding:24px;background:#fbf7ed;color:#294839;font:16px system-ui}main{max-width:560px;margin:48px auto;padding:30px;background:#fffdf7;border:1px solid #b49a66;border-radius:20px}h1{font:38px Georgia,serif}dt{font-weight:700;margin-top:14px}dd{margin:4px 0;overflow-wrap:anywhere}a{color:inherit}</style>
<main><p>The Yogini Journey</p><h1>Verified certificate</h1>
<dl><dt>Student</dt><dd>${escapeHtml(certificate.learnerName)}</dd>
<dt>Course</dt><dd>${escapeHtml(certificate.courseTitle)}</dd>
<dt>Completed</dt><dd>${escapeHtml(certificateDate(certificate))}</dd>
<dt>Certificate ID</dt><dd>${escapeHtml(certificate.certificateId)}</dd></dl>
<a href="${escapeHtml(download.toString())}">Download PDF</a></main></html>`);
  } catch (error) {
    console.error('Certificate verification failed', error.code ?? error.name);
    response.status(503).type('text/plain').send('Certificate verification is temporarily unavailable.');
  }
});
