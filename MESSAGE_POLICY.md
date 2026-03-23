# FaithConnects — Messaging & Suggestion Policy

Purpose
- Ensure conversations are encouraging, respectful, Christ-centered, and safe.

Tone & Language (app-level rules)
- Use kind, gentle, and respectful language.
- Avoid slang that may be offensive or inappropriate.
- Keep messages natural and conversational; avoid preachy or shaming language.

Allowed Emojis
- Only use emojis aligned with positivity and faith: 🙏 ❤️ ✨ 🙌 😊 📖 🕊️

Quick Reactions (recommended by the UI)
- "🙏 Praying for you"
- "❤️ Amen"
- "🙌 Praise God"
- "✨ Stay strong"
- "📖 God is with you"

Moderation Guidance
- Gently discourage hateful, violent, or abusive messages; respond with encouragement and redirection.
- Do not shame or publicly call out users. If content violates platform rules, escalate via moderation workflows.

Server-side Suggestion Service
- A basic rule-based suggestion function lives in `functions/index.js` (HTTP POST /suggest with `{ text }`).
- This function returns safe, encouraging suggestions and the permitted quick reactions.

Extensibility & Safety
- The server-side function is intentionally conservative (rule-based). If a more advanced ML model is integrated, ensure filters block hateful/violent content and preserve the allowed emoji/reaction lists.
