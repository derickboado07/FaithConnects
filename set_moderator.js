/**
 * set_moderator.js
 * Run: node set_moderator.js
 *
 * Sets role=moderator and status=active on a specific Firestore user document.
 * Requires: firebase-admin (installed globally or locally)
 *   npm install firebase-admin
 */

const { initializeApp, cert, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const PROJECT_ID  = 'faith-connects-c7a7e';
const USER_UID    = 'RxOS31hW8Ze7UKHrAuMJplqCqpo1';

// Uses Application Default Credentials (works after `firebase login` or if
// GOOGLE_APPLICATION_CREDENTIALS env var points to a service-account JSON).
initializeApp({ projectId: PROJECT_ID, credential: applicationDefault() });

const db = getFirestore();

async function main() {
  const ref = db.collection('users').doc(USER_UID);
  const snap = await ref.get();

  if (!snap.exists) {
    console.error(`❌  User document ${USER_UID} not found.`);
    process.exit(1);
  }

  console.log(`Found user: ${snap.data().email ?? snap.data().name ?? USER_UID}`);

  await ref.update({
    role:   'moderator',
    status: 'active',
  });

  console.log(`✅  Successfully set role=moderator, status=active on user ${USER_UID}`);
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
