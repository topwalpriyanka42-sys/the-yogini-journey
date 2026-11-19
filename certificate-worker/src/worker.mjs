import { authenticate, courseIdPattern, eligibleCourse, RequestError } from './firebase.mjs';

const certificateIdPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const headers = {
  'Cache-Control': 'no-store',
  'X-Content-Type-Options': 'nosniff',
  'X-Robots-Tag': 'noindex, nofollow',
};
const selection = 'id, course_id, learner_name, course_title, completed_at, share_enabled';

function json(data, status = 200) {
  return Response.json(data, { status, headers });
}

async function requestData(request) {
  const reader = request.body?.getReader();
  if (!reader) throw new RequestError(400, 'Enter a course.');
  const decoder = new TextDecoder();
  let text = '';
  let bytes = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      bytes += value.byteLength;
      if (bytes > 4096) throw new RequestError(413, 'The request is too large.');
      text += decoder.decode(value, { stream: true });
    }
    text += decoder.decode();
    return JSON.parse(text);
  } catch (error) {
    if (error instanceof RequestError) throw error;
    throw new RequestError(400, 'Invalid certificate request.');
  } finally {
    await reader.cancel();
  }
}

function ownerCertificate(db, uid, courseId) {
  return db.prepare(`SELECT ${selection} FROM certificates WHERE uid = ? AND course_id = ?`)
    .bind(uid, courseId).first();
}

function serialize(record) {
  return {
    certificateId: record.id,
    courseId: record.course_id,
    learnerName: record.learner_name,
    courseTitle: record.course_title,
    completedAt: record.completed_at,
    shareEnabled: record.share_enabled === 1,
  };
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[char]);
}

async function verificationPage(db, url) {
  const id = url.searchParams.get('code');
  if (!id || !certificateIdPattern.test(id)) return new Response('Certificate not found.', { status: 404, headers });
  const certificate = await db.prepare(`SELECT ${selection} FROM certificates WHERE id = ? AND share_enabled = 1`)
    .bind(id).first();
  if (!certificate) return new Response('Certificate not found.', { status: 404, headers });

  const date = new Date(certificate.completed_at).toLocaleDateString('en-GB', {
    day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC',
  });
  return new Response(`<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Verified certificate | The Yogini Journey</title>
<style>body{margin:0;padding:24px;background:#fbf7ed;color:#294839;font:16px system-ui}main{max-width:560px;margin:48px auto;padding:30px;background:#fffdf7;border:1px solid #b49a66;border-radius:20px}h1{font:38px Georgia,serif}dt{font-weight:700;margin-top:14px}dd{margin:4px 0;overflow-wrap:anywhere}</style>
<main><p>The Yogini Journey</p><h1>Verified certificate</h1>
<dl><dt>Student</dt><dd>${escapeHtml(certificate.learner_name)}</dd>
<dt>Course</dt><dd>${escapeHtml(certificate.course_title)}</dd>
<dt>Completed</dt><dd>${escapeHtml(date)}</dd>
<dt>Certificate ID</dt><dd>${escapeHtml(id)}</dd></dl></main></html>`, {
    headers: {
      ...headers,
      'Content-Type': 'text/html; charset=utf-8',
      'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'",
    },
  });
}

export default {
  async fetch(request, env) {
    try {
      const url = new URL(request.url);
      if (url.pathname === '/verify' && request.method === 'GET') {
        return await verificationPage(env.DB, url);
      }
      if (url.pathname === '/' && request.method === 'GET') {
        if (!env.FIREBASE_API_KEY || !env.FIREBASE_PROJECT_ID) {
          return json({ service: 'yogini-certificates', ready: false }, 503);
        }
        await env.DB.prepare('SELECT id FROM certificates LIMIT 0').all();
        return json({ service: 'yogini-certificates', ready: true });
      }
      const list = url.pathname === '/api/certificates' && request.method === 'GET';
      const issue = url.pathname === '/api/certificates/issue' && request.method === 'POST';
      const share = url.pathname === '/api/certificates/share' && request.method === 'POST';
      if (!list && !issue && !share) return json({ error: 'Not found.' }, 404);
      const account = await authenticate(request, env);
      if (list) {
        const { results } = await env.DB.prepare(
          `SELECT ${selection} FROM certificates WHERE uid = ? ORDER BY issued_at DESC`,
        ).bind(account.uid).all();
        return json({ certificates: results.map(serialize) });
      }

      const data = await requestData(request);
      const courseId = data?.courseId;
      if (typeof courseId !== 'string' || !courseIdPattern.test(courseId)) {
        throw new RequestError(400, 'Select a valid course.');
      }
      const existing = await ownerCertificate(env.DB, account.uid, courseId);
      if (share) {
        if (typeof data.enabled !== 'boolean') throw new RequestError(400, 'Choose a verification setting.');
        if (!existing) throw new RequestError(404, 'Certificate not found.');
        await env.DB.prepare('UPDATE certificates SET share_enabled = ? WHERE id = ? AND uid = ?')
          .bind(Number(data.enabled), existing.id, account.uid).run();
        return json({ certificate: serialize({ ...existing, share_enabled: Number(data.enabled) }) });
      }
      if (existing) return json({ certificate: serialize(existing) });
      if (!account.name || account.name.length > 120) {
        throw new RequestError(409, 'Set your certificate name in Profile first.');
      }
      const course = await eligibleCourse(env, account, courseId);
      await env.DB.prepare(`INSERT INTO certificates
        (id, uid, course_id, learner_name, course_title, completed_at, issued_at)
        VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(uid, course_id) DO NOTHING`)
        .bind(crypto.randomUUID(), account.uid, courseId, account.name, course.title,
          course.completedAt, new Date().toISOString()).run();
      return json({ certificate: serialize(await ownerCertificate(env.DB, account.uid, courseId)) });
    } catch (error) {
      if (error instanceof RequestError) return json({ error: error.message }, error.status);
      console.error('Certificate request failed:', error.name);
      return json({ error: 'Certificates are temporarily unavailable.' }, 503);
    }
  },
};
