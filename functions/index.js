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
