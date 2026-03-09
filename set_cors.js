#!/usr/bin/env node
// Applies cors.json to the Firebase Storage bucket using the Firebase CLI's
// stored OAuth credentials. Run with: node set_cors.js
const fs = require('fs');
const path = require('path');
const https = require('https');
const os = require('os');

const PROJECT_ID = 'faith-connects-c7a7e';
const BUCKET = `${PROJECT_ID}.firebasestorage.app`;

const corsConfig = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'cors.json'), 'utf8')
);

// Read stored Firebase CLI token
const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
const fbConfig = JSON.parse(fs.readFileSync(configPath, 'utf8'));

// Use firebase-tools' bundled google-auth-library for correct OAuth flow
const FBT_ROOT = 'C:\\Users\\deric\\AppData\\Roaming\\npm\\node_modules\\firebase-tools';
const { UserRefreshClient } = require(path.join(FBT_ROOT, 'node_modules', 'google-auth-library'));

function setCors(bucket, accessToken, corsBody) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({ cors: corsBody });
    const req = https.request({
      hostname: 'storage.googleapis.com',
      path: `/storage/v1/b/${encodeURIComponent(bucket)}?fields=cors`,
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
        'Authorization': `Bearer ${accessToken}`,
      },
    }, (res) => {
      let data = '';
      res.on('data', d => data += d);
      res.on('end', () => {
        resolve({ status: res.statusCode, body: data });
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function main() {
  const refresh = fbConfig.tokens?.refresh_token;
  if (!refresh) {
    console.error('No Firebase CLI refresh token found. Run: firebase login');
    process.exit(1);
  }

  // Use the same client credentials firebase-tools uses
  const client = new UserRefreshClient(
    '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh
  );

  console.log('Getting fresh access token via google-auth-library...');
  const tokenResponse = await client.getAccessToken();
  const accessToken = tokenResponse.token;
  if (!accessToken) {
    console.error('Could not get access token.');
    process.exit(1);
  }
  console.log('Token obtained successfully.\n');

  // Probe bucket existence via Firebase Storage file API (read-only, no admin perms needed)
  async function probeBucket(bucketName) {
    return new Promise((resolve) => {
      const req = https.request({
        hostname: 'firebasestorage.googleapis.com',
        path: `/v0/b/${encodeURIComponent(bucketName)}/o?maxResults=1`,
        method: 'GET',
        headers: { 'Authorization': `Bearer ${accessToken}` },
      }, (res) => {
        let data = '';
        res.on('data', d => data += d);
        res.on('end', () => resolve({ status: res.statusCode, body: data }));
      });
      req.on('error', () => resolve({ status: -1, body: '' }));
      req.end();
    });
  }

  const candidates = [
    `${PROJECT_ID}.firebasestorage.app`,
    `${PROJECT_ID}.appspot.com`,
  ];

  let resolvedBucket = null;
  for (const candidate of candidates) {
    console.log(`Probing Firebase Storage bucket: ${candidate} ...`);
    const res = await probeBucket(candidate);
    console.log(`  HTTP ${res.status}`);
    if (res.status !== 404) {
      resolvedBucket = candidate;
      console.log(`  ✓ Bucket found: ${candidate}`);
      break;
    }
  }

  if (!resolvedBucket) {
    console.error('\nNeither bucket variant was found via Firebase Storage API.');
    console.error('CORS setup requires the Google Cloud Console.');
    console.error(`Go to: https://console.cloud.google.com/storage/browser?project=${PROJECT_ID}`);
    process.exit(1);
  }

  const gcsBucketName = resolvedBucket;

  // Use the GCS JSON API directly to PATCH the bucket CORS config.
  const body = JSON.stringify({ cors: corsConfig });
  const patchResult = await new Promise((resolve, reject) => {
    const req = https.request({
      hostname: 'storage.googleapis.com',
      path: `/storage/v1/b/${encodeURIComponent(gcsBucketName)}?fields=cors`,
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
        'Authorization': `Bearer ${accessToken}`,
      },
    }, (res) => {
      let data = '';
      res.on('data', d => data += d);
      res.on('end', () => resolve({ status: res.statusCode, body: data }));
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });

  if (patchResult.status === 200) {
    let parsed;
    try { parsed = JSON.parse(patchResult.body); } catch (_) {}
    console.log(`✓ CORS applied successfully to gs://${gcsBucketName}`);
    if (parsed?.cors) console.log('Configured CORS:', JSON.stringify(parsed.cors, null, 2));
  } else {
    let reason = patchResult.body;
    try { reason = JSON.parse(patchResult.body).error?.message || reason; } catch (_) {}
    console.error(`HTTP ${patchResult.status}: ${reason}`);
    process.exit(1);
  }
}

main().catch(e => { console.error('Error:', e.message); process.exit(1); });
