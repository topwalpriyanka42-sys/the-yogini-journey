export class RequestError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export const courseIdPattern = /^[A-Za-z0-9_-]{1,128}$/;
const maxLessons = 500;

async function googleJson(url, options) {
  const response = await fetch(url, options);
  if (!response.ok) {
    if (response.status === 429) throw new RequestError(503, 'Please try again later.');
    throw new RequestError(502, 'Firebase is currently unavailable.');
  }
  return response.json();
}

export async function authenticate(request, env) {
  const header = request.headers.get('Authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token || token.length > 8192) throw new RequestError(401, 'Sign in again to continue.');

  let claims;
  try {
    const parts = token.split('.');
    if (parts.length !== 3) throw new Error('Malformed Firebase token');
    const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    claims = JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(base64), (character) => character.charCodeAt(0))));
  } catch {
    throw new RequestError(401, 'Sign in again to continue.');
  }
  const project = env.FIREBASE_PROJECT_ID;
  if (!claims || typeof claims !== 'object' || claims.aud !== project || claims.iss !== `https://securetoken.google.com/${project}` ||
      typeof claims.sub !== 'string' || !claims.sub || claims.sub.length > 128 ||
      typeof claims.exp !== 'number' || claims.exp * 1000 <= Date.now()) {
    throw new RequestError(401, 'Sign in again to continue.');
  }

  const url = new URL('https://identitytoolkit.googleapis.com/v1/accounts:lookup');
  url.searchParams.set('key', env.FIREBASE_API_KEY);
  const verified = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ idToken: token }),
  });
  if (verified.status === 400 || verified.status === 401 || verified.status === 403) {
    throw new RequestError(401, 'Firebase could not verify your sign-in.');
  }
  if (!verified.ok) throw new RequestError(503, 'Sign-in verification is temporarily unavailable.');
  const learner = (await verified.json()).users?.[0];
  if (!learner || learner.localId !== claims.sub || learner.disabled) {
    throw new RequestError(401, 'Sign in again to continue.');
  }
  if (!learner.emailVerified || claims.email_verified !== true) {
    throw new RequestError(403, 'Verify your email in Profile first.');
  }
  return { uid: learner.localId, name: learner.displayName?.trim(), token };
}

function publishedFilter() {
  return { fieldFilter: { field: { fieldPath: 'published' }, op: 'EQUAL', value: { booleanValue: true } } };
}

export async function eligibleCourse(env, account, courseId) {
  const database = `projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents`;
  const url = `https://firestore.googleapis.com/v1/${database}`;
  const coursePath = `${database}/courses/${courseId}`;
  const options = (body) => ({
    method: 'POST',
    headers: { Authorization: `Bearer ${account.token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const courseRows = await googleJson(`${url}:runQuery`, options({
    structuredQuery: {
      from: [{ collectionId: 'courses' }],
      where: { compositeFilter: { op: 'AND', filters: [
        publishedFilter(),
        { fieldFilter: { field: { fieldPath: '__name__' }, op: 'EQUAL', value: { referenceValue: coursePath } } },
      ] } },
      limit: 1,
    },
  }));
  const courseRow = courseRows.find((row) => row.document);
  const title = courseRow?.document.fields?.title?.stringValue?.trim();
  const readTime = courseRow?.readTime;
  if (!title || title.length > 120 || typeof readTime !== 'string') {
    throw new RequestError(409, 'This course cannot issue a certificate.');
  }

  const lessonRows = await googleJson(`${url}/courses/${courseId}:runQuery`, options({
    structuredQuery: { from: [{ collectionId: 'lessons' }], where: publishedFilter(), limit: maxLessons + 1 },
    readTime,
  }));
  const lessonIds = lessonRows.filter((row) => row.document)
    .map((row) => row.document.name.split('/').at(-1));
  if (!lessonIds.length || lessonIds.length > maxLessons) {
    throw new RequestError(409, 'This course has no eligible lesson list.');
  }
  const progressRoot = `${database}/users/${account.uid}/courses/${courseId}/lesson_progress`;
  const paths = lessonIds.map((id) => `${progressRoot}/${id}`);
  const records = await googleJson(`${url}:batchGet`, options({ documents: paths, readTime }));
  const recorded = new Map(records.map(({ found }) => [found?.name, found?.fields?.completedAt?.timestampValue]));
  let completed = -Infinity;
  for (const path of paths) {
    const timestamp = Date.parse(recorded.get(path));
    if (!Number.isFinite(timestamp)) throw new RequestError(409, 'Mark every published lesson complete first.');
    completed = Math.max(completed, timestamp);
  }
  return { title, completedAt: new Date(completed).toISOString() };
}
