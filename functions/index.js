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

// HTTP endpoint to send a message after verifying the caller is a member of the conversation.
// POST JSON body: { convoId: string, text: string }
// Authorization: Bearer <ID_TOKEN>
exports.sendMessageHttp = functions.https.onRequest(async (req, res) => {
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
  const text = req.body && req.body.text ? String(req.body.text) : '';
  if (!convoId || !text) {
    res.status(400).json({ error: 'Missing convoId or text' });
    return;
  }
  const convoRef = admin.firestore().collection('conversations').doc(convoId);
  const convoSnap = await convoRef.get();
  if (!convoSnap.exists) {
    res.status(404).json({ error: 'Conversation not found' });
    return;
  }
  const convo = convoSnap.data();
  const participants = convo && convo.participants ? convo.participants : [];
  if (!participants.includes(uid)) {
    res.status(403).json({ error: 'User is not a member of the conversation' });
    return;
  }
  try {
    const now = new Date().toISOString();
    const messagesRef = convoRef.collection('messages');
    const docRef = messagesRef.doc();
    await docRef.set({ senderId: uid, senderName: decoded.name || '', text: text, ts: now });
    await convoRef.set({ lastMessage: text, lastSenderId: uid, updatedAt: now }, { merge: true });
    res.json({ success: true, messageId: docRef.id });
  } catch (e) {
    res.status(500).json({ error: String(e) });
  }
});

// HTTP endpoint to add a member to a group (admin-only).
// POST JSON body: { convoId: string, uidToAdd: string }
// Authorization: Bearer <ID_TOKEN>
exports.addGroupMemberHttp = functions.https.onRequest(async (req, res) => {
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
  const uidToAdd = req.body && req.body.uidToAdd ? String(req.body.uidToAdd) : null;
  if (!convoId || !uidToAdd) {
    res.status(400).json({ error: 'Missing convoId or uidToAdd' });
    return;
  }
  const convoRef = admin.firestore().collection('conversations').doc(convoId);
  const convoSnap = await convoRef.get();
  if (!convoSnap.exists) {
    res.status(404).json({ error: 'Conversation not found' });
    return;
  }
  const convo = convoSnap.data();
  if (convo.type !== 'group') {
    res.status(400).json({ error: 'Not a group conversation' });
    return;
  }
  const admins = convo && convo.admins ? convo.admins : [];
  const isAdmin = admins.includes(uid) || decoded.admin === true;
  if (!isAdmin) {
    res.status(403).json({ error: 'Only admins can add members' });
    return;
  }
  try {
    await convoRef.update({ participants: admin.firestore.FieldValue.arrayUnion(uidToAdd) });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: String(e) });
  }
});

// HTTP endpoint to remove a member from a group (admin-only).
// POST JSON body: { convoId: string, uidToRemove: string }
// Authorization: Bearer <ID_TOKEN>
exports.removeGroupMemberHttp = functions.https.onRequest(async (req, res) => {
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
  const uidToRemove = req.body && req.body.uidToRemove ? String(req.body.uidToRemove) : null;
  if (!convoId || !uidToRemove) {
    res.status(400).json({ error: 'Missing convoId or uidToRemove' });
    return;
  }
  const convoRef = admin.firestore().collection('conversations').doc(convoId);
  const convoSnap = await convoRef.get();
  if (!convoSnap.exists) {
    res.status(404).json({ error: 'Conversation not found' });
    return;
  }
  const convo = convoSnap.data();
  if (convo.type !== 'group') {
    res.status(400).json({ error: 'Not a group conversation' });
    return;
  }
  const admins = convo && convo.admins ? convo.admins : [];
  const isAdmin = admins.includes(uid) || decoded.admin === true;
  if (!isAdmin) {
    res.status(403).json({ error: 'Only admins can remove members' });
    return;
  }
  try {
    await convoRef.update({ participants: admin.firestore.FieldValue.arrayRemove(uidToRemove), admins: admin.firestore.FieldValue.arrayRemove(uidToRemove) });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: String(e) });
  }
});

// HTTP endpoint to rename a group (admin-only).
// POST JSON body: { convoId: string, newName: string }
// Authorization: Bearer <ID_TOKEN>
exports.renameGroupHttp = functions.https.onRequest(async (req, res) => {
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
  const newName = req.body && req.body.newName ? String(req.body.newName) : null;
  if (!convoId || !newName) {
    res.status(400).json({ error: 'Missing convoId or newName' });
    return;
  }
  const convoRef = admin.firestore().collection('conversations').doc(convoId);
  const convoSnap = await convoRef.get();
  if (!convoSnap.exists) {
    res.status(404).json({ error: 'Conversation not found' });
    return;
  }
  const convo = convoSnap.data();
  if (convo.type !== 'group') {
    res.status(400).json({ error: 'Not a group conversation' });
    return;
  }
  const admins = convo && convo.admins ? convo.admins : [];
  const isAdmin = admins.includes(uid) || decoded.admin === true;
  if (!isAdmin) {
    res.status(403).json({ error: 'Only admins can rename group' });
    return;
  }
  try {
    await convoRef.update({ name: newName, updatedAt: new Date().toISOString() });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: String(e) });
  }
});
