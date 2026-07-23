// Vercel serverless function — waitlist signup + admin count
// Storage: Vercel KV (Upstash Redis) via REST API — no npm packages needed.
// Emails:  Resend (optional). Set RESEND_API_KEY + RESEND_FROM in Vercel env vars.

async function readBody(req) {
  return new Promise((resolve) => {
    let raw = '';
    req.on('data', (c) => { raw += c; });
    req.on('end', () => { try { resolve(JSON.parse(raw)); } catch { resolve({}); } });
    req.on('error', () => resolve({}));
  });
}

async function redis(url, token, ...command) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(command),
  });
  const { result } = await res.json();
  return result;
}

module.exports = async function handler(req, res) {
  // Vercel KV (legacy) or Upstash Redis (current Vercel marketplace name)
  const kvUrl   = process.env.UPSTASH_REDIS_REST_URL   || process.env.KV_REST_API_URL;
  const kvToken = process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN;

  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();

  if (!kvUrl || !kvToken) {
    return res.status(503).json({ error: 'Storage not configured — add Vercel KV to this project.' });
  }

  // GET — secret admin: how many signups?
  if (req.method === 'GET') {
    const count = await redis(kvUrl, kvToken, 'SCARD', 'iris:waitlist');
    return res.json({ count: count ?? 0 });
  }

  // POST — join the waitlist
  if (req.method === 'POST') {
    const body  = await readBody(req);
    const email = (body.email || '').trim().toLowerCase();

    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return res.status(400).json({ error: 'Invalid email' });
    }

    // SADD returns 1 if brand-new, 0 if already in set (no duplicate stored)
    const added = await redis(kvUrl, kvToken, 'SADD', 'iris:waitlist', email);

    // Confirmation email via Resend — only for new signups, non-fatal if it fails
    if (added === 1 && process.env.RESEND_API_KEY) {
      await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from:    process.env.RESEND_FROM || 'Iris <onboarding@resend.dev>',
          to:      [email],
          subject: "You're on the Iris waitlist",
          html: `<!DOCTYPE html><html><body style="font-family:system-ui,sans-serif;max-width:520px;margin:48px auto;padding:0 24px;color:#1c1c1c;line-height:1.7">
<p style="font-size:11px;font-family:monospace;color:#aaa;letter-spacing:.1em;margin-bottom:32px">IRIS</p>
<h1 style="font-size:26px;margin:0 0 16px;font-weight:600">You're on the list.</h1>
<p style="color:#555;margin:0">We'll email you the moment Iris is ready to download.<br>Until then, take a break from your screen once in a while.</p>
<p style="margin-top:48px;font-size:12px;color:#bbb">— The Iris team</p>
</body></html>`,
          text: "You're on the Iris waitlist. We'll email you the moment Iris is ready to download.",
        }),
      }).catch(() => {}); // non-fatal
    }

    return res.json({ success: true, new: added === 1 });
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
