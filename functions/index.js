const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Simple, rule-based suggestion endpoint.
// POST body: { text: 'message text' }
exports.suggest = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  const text = (req.body && req.body.text) ? String(req.body.text).toLowerCase() : '';
  const suggestions = [];

  if (!text) {
    suggestions.push('Hi — how can I pray for you? 🙏');
    suggestions.push('Thinking of you — sending prayers and love. ❤️');
  } else {
    if (text.includes('tired') || text.includes('exhaust') || text.includes('burnout')) {
      suggestions.push('Praying for strength for you. God is with you always ❤️');
      suggestions.push('I’m so sorry you’re tired — I’ll pray for rest and renewal. 🙏');
    }
    if (text.includes('stressed') || text.includes('anx') || text.includes('worried')) {
      suggestions.push('I’m praying that God gives you peace and clarity. 🕊️');
      suggestions.push('Stay strong — God walks with you through this. ✨');
    }
    if (text.includes('sad') || text.includes('down') || text.includes('lonely')) {
      suggestions.push('You’re not alone — praying for comfort and hope. 🙏');
      suggestions.push('Holding you in prayer and believing for brighter days. ❤️');
    }
  }

  // Fallback
  if (suggestions.length === 0) {
    suggestions.push('I’m praying for you — how can I help? 🙏');
  }

  const reactions = [
    '🙏 Praying for you',
    '❤️ Amen',
    '🙌 Praise God',
    '✨ Stay strong',
    '📖 God is with you',
  ];

  res.json({ suggestions: suggestions.slice(0, 5), reactions });
});

// Callable function to delete a message document securely.
// Expects data: { convoId: string, messageId: string }
exports.deleteMessage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  const uid = context.auth.uid;
  const convoId = data && data.convoId ? String(data.convoId) : null;
  const messageId = data && data.messageId ? String(data.messageId) : null;
  if (!convoId || !messageId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing convoId or messageId');
  }

  const msgRef = admin.firestore().collection('conversations').doc(convoId).collection('messages').doc(messageId);
  const snap = await msgRef.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError('not-found', 'Message not found');
  }
  const dataSnap = snap.data();
  const senderId = dataSnap && dataSnap.senderId ? String(dataSnap.senderId) : null;

  // Allow delete if the caller is the original sender, or has admin claim
  const isAdmin = context.auth.token && context.auth.token.admin === true;
  if (uid !== senderId && !isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Insufficient permission to delete message');
  }

  await msgRef.delete();
  return { success: true };
});

// HTTP endpoint that deletes a message after verifying the caller's ID token.
// POST JSON body: { convoId: string, messageId: string }
// Authorization: Bearer <ID_TOKEN>
exports.deleteMessageHttp = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }
  const authHeader = req.get('Authorization') || req.get('authorization') || '';
  const match = authHeader.match(/^Bearer (.*)$/);
  if (!match) {
    res.status(401).json({ error: 'Missing Authorization header' });
    return;
  }
  const idToken = match[1];
  let decoded;
  try {
    decoded = await admin.auth().verifyIdToken(idToken);
  } catch (e) {
    res.status(401).json({ error: 'Invalid ID token' });
    return;
  }
  const uid = decoded.uid;
  const convoId = req.body && req.body.convoId ? String(req.body.convoId) : null;
  const messageId = req.body && req.body.messageId ? String(req.body.messageId) : null;
  if (!convoId || !messageId) {
    res.status(400).json({ error: 'Missing convoId or messageId' });
    return;
  }

  const msgRef = admin.firestore().collection('conversations').doc(convoId).collection('messages').doc(messageId);
  const snap = await msgRef.get();
  if (!snap.exists) {
    res.status(404).json({ error: 'Message not found' });
    return;
  }
  const dataSnap = snap.data();
  const senderId = dataSnap && dataSnap.senderId ? String(dataSnap.senderId) : null;
  const isAdmin = decoded.admin === true;
  if (uid !== senderId && !isAdmin) {
    res.status(403).json({ error: 'Insufficient permission' });
    return;
  }
  try {
    await msgRef.delete();
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: String(e) });
  }
});
