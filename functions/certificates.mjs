import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import PDFDocument from 'pdfkit';
import QRCode from 'qrcode';

export const certificateIdPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
export const maxLessons = 500;

export function certificateUrl(projectId, certificateId) {
  const url = new URL(`https://us-central1-${projectId}.cloudfunctions.net/verifyCertificate`);
  url.searchParams.set('code', certificateId);
  return url;
}

export async function issueCourseCertificate(db, uid, courseId, learnerName, { share } = {}) {
  if (typeof courseId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(courseId)) {
    throw new HttpsError('invalid-argument', 'Select a valid course.');
  }
  const name = typeof learnerName === 'string' ? learnerName.trim() : '';
  if (!name || name.length > 120) {
    throw new HttpsError('failed-precondition', 'Set a profile name of up to 120 characters first.');
  }
  const user = db.collection('users').doc(uid);
  const record = user.collection('certificates').doc(courseId);
  const course = db.collection('courses').doc(courseId);
  const progress = user.collection('courses').doc(courseId).collection('lesson_progress');

  return db.runTransaction(async (transaction) => {
    const previous = await transaction.get(record);
    if (previous.exists) {
      if (typeof share === 'boolean' && previous.get('shareEnabled') !== share) {
        transaction.update(record, { shareEnabled: share });
      }
      return previous.get('certificateId');
    }

    const courseSnapshot = await transaction.get(course);
    const courseTitle = courseSnapshot.get('title');
    if (courseSnapshot.get('published') !== true ||
        typeof courseTitle !== 'string' || !courseTitle.trim() || courseTitle.length > 120) {
      throw new HttpsError('failed-precondition', 'This course cannot issue a certificate.');
    }
    const lessons = await transaction.get(
      course.collection('lessons').where('published', '==', true).limit(maxLessons + 1),
    );
    if (lessons.empty || lessons.size > maxLessons) {
      throw new HttpsError('failed-precondition', 'This course has no eligible lesson list.');
    }
    const completions = await transaction.getAll(...lessons.docs.map((lesson) => progress.doc(lesson.id)));
    let completionDate = null;
    for (const entry of completions) {
      const time = entry.get('completedAt');
      if (!(time instanceof Timestamp)) {
        throw new HttpsError('failed-precondition', 'Mark every published lesson complete first.');
      }
      if (completionDate == null || time.toMillis() > completionDate.toMillis()) {
        completionDate = time;
      }
    }

    const certificateId = randomUUID();
    transaction.create(record, {
      certificateId,
      courseTitle: courseTitle.trim(),
      learnerName: name,
      completedAt: completionDate,
      issuedAt: Timestamp.now(),
      lessonCount: lessons.size,
      shareEnabled: share === true,
    });
    return certificateId;
  });
}

export async function findCertificate(db, certificateId) {
  if (typeof certificateId !== 'string' || !certificateIdPattern.test(certificateId)) return null;
  const results = await db.collectionGroup('certificates')
    .where('certificateId', '==', certificateId).limit(1).get();
  const certificate = results.docs[0]?.data();
  return certificate?.shareEnabled === true ? certificate : null;
}

const latinFont = readFileSync(new URL('./fonts/NotoSans-Regular.ttf', import.meta.url));
const hindiFont = readFileSync(new URL('./fonts/NotoSansDevanagari-Regular.ttf', import.meta.url));
const devanagari = /[\u0900-\u097f\u1cd0-\u1cff\ua8e0-\ua8ff\u200c\u200d]/u;
const dateFormat = new Intl.DateTimeFormat('en-GB', {
  day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC',
});

export function certificateDate(certificate) {
  return dateFormat.format(certificate.completedAt.toDate());
}

function drawCenteredName(document, name, y, largestSize) {
  const runs = [];
  for (const character of name.replace(/\s+/g, ' ')) {
    const font = devanagari.test(character) ? 'Hindi' : 'Latin';
    const previous = runs.at(-1);
    if (previous?.font === font) previous.text += character;
    else runs.push({ font, text: character });
  }
  function widths(size) {
    return runs.map(({ font, text }) => document.font(font).fontSize(size).widthOfString(text));
  }
  let size = largestSize;
  let measured = widths(size);
  while (measured.reduce((sum, width) => sum + width, 0) > 690 && size > 8) {
    size -= 1;
    measured = widths(size);
  }
  let x = (document.page.width - measured.reduce((sum, width) => sum + width, 0)) / 2;
  runs.forEach(({ font, text }, index) => {
    document.font(font).fontSize(size).text(text, x, y, { lineBreak: false });
    x += measured[index];
  });
}

export async function renderCertificatePdf(certificate, verificationUrl) {
  const qr = await QRCode.toBuffer(verificationUrl.toString(), { width: 360, margin: 2, errorCorrectionLevel: 'M' });
  const doc = new PDFDocument({
    size: 'A4', layout: 'landscape', margin: 0,
    info: { Title: 'The Yogini Journey Certificate', Author: 'The Yogini Journey' },
  });
  const chunks = [];
  const finished = new Promise((resolve, reject) => {
    doc.on('data', (data) => chunks.push(data));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
  });
  const { width, height } = doc.page;
  const green = '#294839';
  const gold = '#aa854d';
  doc.registerFont('Latin', latinFont).registerFont('Hindi', hindiFont);
  doc.rect(0, 0, width, height).fill('#fbf7ed');
  doc.lineWidth(2).rect(23, 23, width - 46, height - 46).stroke(green);
  doc.lineWidth(0.6).rect(31, 31, width - 62, height - 62).stroke(gold);
  doc.save().translate(width / 2, 64).lineWidth(1.8);
  doc.path('M 0 42 Q -28 38 -29 17 Q -9 13 0 42 Q 9 13 29 17 Q 28 38 0 42 M 0 31 Q -13 17 0 0 Q 13 17 0 31').stroke(green);
  doc.restore();
  doc.fillColor(green).font('Latin');
  const center = (text, y, size) => doc.font('Latin').fontSize(size).text(text, 45, y, {
    align: 'center', width: width - 90, lineBreak: false,
  });
  center('THE YOGINI JOURNEY', 119, 19);
  center('Certificate of Completion', 164, 39);
  center('Presented to', 236, 15);
  drawCenteredName(doc, certificate.learnerName, 264, 43);
  center('for completing', 334, 15);
  drawCenteredName(doc, certificate.courseTitle, 362, 28);
  center(`Completed on ${certificateDate(certificate)}`, 422, 14);
  center(`Certificate ID  ${certificate.certificateId}`, 507, 10);
  doc.image(qr, width - 146, 433, { width: 98 });
  doc.circle(104, 481, 38).lineWidth(1).stroke(gold);
  doc.circle(104, 481, 33).lineWidth(0.5).stroke(gold);
  doc.fillColor(green).font('Latin').fontSize(8)
    .text('YOGINI', 74, 465, { width: 60, align: 'center', lineBreak: false })
    .text('ISSUER SEAL', 73, 483, { width: 62, align: 'center', lineBreak: false });
  doc.end();
  return finished;
}
