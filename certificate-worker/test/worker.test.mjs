import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { test } from 'node:test';
import worker from '../src/worker.mjs';

const project = 'demo-yogini';
const origin = 'https://certificates.example.test';
const root = `projects/${project}/databases/(default)/documents`;
const courseId = 'morning-yoga';
const readTime = '2026-11-18T10:00:00Z';

function createDatabase() {
  const database = new DatabaseSync(':memory:');
  database.exec(readFileSync(new URL('../migrations/0001_certificates.sql', import.meta.url), 'utf8'));
  return {
    close: () => database.close(),
    prepare(sql) {
      const statement = database.prepare(sql);
      return {
        bind: (...args) => ({
          first: async () => statement.get(...args),
          all: async () => ({ results: statement.all(...args) }),
          run: async () => statement.run(...args),
        }),
        all: async () => ({ results: statement.all() }),
      };
    },
  };
}

function token(uid, verified = true, audience = project) {
  const payload = Buffer.from(JSON.stringify({
    aud: audience, iss: `https://securetoken.google.com/${audience}`,
    sub: uid, email_verified: verified, exp: Math.floor(Date.now() / 1000) + 900,
  })).toString('base64url');
  return `header.${payload}.test-signature`;
}

test('validates Firebase identity and progress, issues once, and keeps verification opt-in', async (t) => {
  const db = createDatabase();
  t.after(db.close);
  const env = { DB: db, FIREBASE_PROJECT_ID: project, FIREBASE_API_KEY: 'test-key' };
  const learner = token('learner');
  const unverified = token('unverified', false);
  const stranger = token('stranger');
  const wrongProject = token('learner', true, 'some-other-project');
  const forged = token('forged');
  let progressReady = false;
  let lessonCount = 2;
  let checkedProgress = 0;

  t.mock.method(globalThis, 'fetch', async (input, options) => {
    const url = new URL(input);
    const body = JSON.parse(options.body);
    if (url.hostname === 'identitytoolkit.googleapis.com') {
      assert.equal(url.pathname, '/v1/accounts:lookup');
      assert.equal(url.searchParams.get('key'), 'test-key');
      if (body.idToken === forged) return Response.json({}, { status: 400 });
      const identity = ({
        [learner]: ['learner', true, 'प्रियंका <Student>'],
        [stranger]: ['stranger', true, 'Other learner'],
        [unverified]: ['unverified', false, 'Not yet verified'],
      })[body.idToken];
      assert.ok(identity, 'only mock tokens can be verified by the identity service');
      return Response.json({ users: [{
        localId: identity[0], emailVerified: identity[1], displayName: identity[2],
      }] });
    }
    assert.equal(url.hostname, 'firestore.googleapis.com');
    assert.ok(options.headers.Authorization?.startsWith('Bearer '));
    if (url.pathname.endsWith('/documents:runQuery')) {
      assert.equal(body.structuredQuery.where.compositeFilter.filters[0].fieldFilter.value.booleanValue, true);
      assert.equal(body.structuredQuery.where.compositeFilter.filters[1].fieldFilter.value.referenceValue,
        `${root}/courses/${courseId}`);
      return Response.json([{ readTime, document: { fields: { title: { stringValue: 'Morning Yoga' } } } }]);
    }
    assert.equal(body.readTime, readTime);
    if (url.pathname.endsWith('/courses/morning-yoga:runQuery')) {
      assert.equal(body.structuredQuery.where.fieldFilter.value.booleanValue, true);
      return Response.json(Array.from({ length: lessonCount }, (_, index) => ({
        document: { name: `${root}/courses/${courseId}/lessons/${index}` },
      })));
    }
    assert.ok(url.pathname.endsWith('/documents:batchGet'));
    const expectedUid = options.headers.Authorization === `Bearer ${learner}` ? 'learner' : 'stranger';
    assert.ok(body.documents.every((path) => path.startsWith(`${root}/users/${expectedUid}/courses/${courseId}/lesson_progress/`)));
    checkedProgress += 1;
    return Response.json(body.documents.map((name, index) => (
      progressReady || index === 0
        ? { found: { name, fields: { completedAt: { timestampValue: `2026-11-18T09:0${index}:00Z` } } } }
        : { missing: name }
    )));
  });

  function call(path, auth, body) {
    return worker.fetch(new Request(origin + path, {
      method: body == null ? 'GET' : 'POST',
      headers: auth ? { Authorization: `Bearer ${auth}` } : {},
      body: body == null ? undefined : JSON.stringify(body),
    }), env);
  }
  const issue = '/api/certificates/issue';
  const history = '/api/certificates';
  const share = '/api/certificates/share';
  assert.equal((await (await call('/')).json()).ready, true);
  for (const auth of [null, wrongProject, forged]) {
    assert.equal((await call(issue, auth, { courseId })).status, 401);
  }
  assert.equal((await call(issue, unverified, { courseId })).status, 403);
  assert.equal((await call(issue, learner, { courseId: '../other' })).status, 400);
  assert.equal((await call(issue, learner, { courseId })).status, 409);
  assert.deepEqual(await (await call(history, learner)).json(), { certificates: [] });
  lessonCount = 0;
  assert.equal((await call(issue, learner, { courseId })).status, 409);
  lessonCount = 2;
  progressReady = true;
  const results = await Promise.all([call(issue, learner, { courseId }), call(issue, learner, { courseId })]);
  const [first, second] = await Promise.all(results.map((response) => response.json()));
  assert.equal(first.certificate.certificateId, second.certificate.certificateId);
  assert.equal(first.certificate.completedAt, '2026-11-18T09:01:00.000Z');
  assert.equal(first.certificate.learnerName, 'प्रियंका <Student>');
  assert.equal(first.certificate.shareEnabled, false);
  assert.ok(checkedProgress >= 2);
  assert.deepEqual(await (await call(history, stranger)).json(), { certificates: [] });

  const verify = `/verify?code=${first.certificate.certificateId}`;
  assert.equal((await call(verify)).status, 404);
  assert.equal((await call(share, stranger, { courseId, enabled: true })).status, 404);
  assert.equal((await call(share, learner, { courseId, enabled: true })).status, 200);
  const verified = await call(verify);
  assert.equal(verified.status, 200);
  const html = await verified.text();
  assert.match(html, /&lt;Student&gt;/);
  assert.doesNotMatch(html, /<Student>|learner@example/);
  assert.match(verified.headers.get('Cache-Control'), /no-store/);
  assert.equal((await call(share, learner, { courseId, enabled: false })).status, 200);
  assert.equal((await call(verify)).status, 404);
  assert.equal((await (await call(history, learner)).json()).certificates.length, 1);
});
