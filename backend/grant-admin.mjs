import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const [projectId, uid, extra] = process.argv.slice(2);
if (!projectId || !uid || extra || !/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(projectId)) {
  throw new Error('Usage: npm run grant-admin -- <firebase-project-id> <firebase-auth-uid>');
}
if (process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error('Unset FIREBASE_AUTH_EMULATOR_HOST before granting a role.');
}

const auth = getAuth(initializeApp({ credential: applicationDefault(), projectId }));
const user = await auth.getUser(uid);
if (!user.emailVerified || user.disabled) {
  throw new Error('Use an active Firebase user whose email is already verified.');
}
await auth.setCustomUserClaims(uid, { ...user.customClaims, admin: true });
console.log(`Administrator claim set for UID ${uid} in ${projectId}. Sign in again to refresh the token.`);
