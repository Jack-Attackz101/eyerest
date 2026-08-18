// Vercel serverless function: waitlist signup and admin list
// Storage: Vercel KV (Upstash Redis) via REST API, so no npm packages needed.
// Emails:  Resend (optional). Set RESEND_API_KEY + RESEND_FROM in Vercel env vars.
//
// Admin:   GET /api/waitlist?pw=XXXX  returns the count AND every email.
//          The password is checked HERE, on the server, on purpose. If it were
//          checked in the browser, anyone could read the page source, skip the
//          check and pull the list. Set ADMIN_PASS in Vercel to change it.

// No fallback. This used to read `process.env.ADMIN_PASS || <a literal>`, and
// because this repo is public that literal was a published password: any deploy
// target without the variable set accepted it, silently, and the whole waitlist
// was readable by anyone who read the source. Setting the variable in Vercel
// closed that on production, but the pattern would come back on the next preview
// branch or deploy target, or the day someone removes the variable.
//
// So it fails closed. A missing secret refuses every gated request with a 500,
// which is a visible misconfiguration rather than an invisible open door. A 401
// would be worse here: it looks exactly like a wrong password, so nobody would
// know the gate had stopped being a gate. Signing up and the public count do not
// involve the password, so they keep working either way.
const ADMIN_PASS = process.env.ADMIN_PASS;
if (!ADMIN_PASS) {
  console.error('ADMIN_PASS is not set, refusing every gated request');
}

/** True when a password is required but none is configured to check against. */
function gateUnavailable(res) {
  if (ADMIN_PASS) return false;
  console.error('ADMIN_PASS is not set, refusing an admin request');
  res.status(500).json({ error: 'Server misconfigured' });
  return true;
}

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

/** constant-time-ish compare, so the password cannot be guessed by timing */
function samePass(given) {
  if (!ADMIN_PASS) return false;   // no secret configured, so nothing can match
  const a = String(given || '');
  const b = ADMIN_PASS;
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

module.exports = async function handler(req, res) {
  const kvUrl   = process.env.UPSTASH_REDIS_REST_URL   || process.env.KV_REST_API_URL;
  const kvToken = process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN;

  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  // never let a proxy or the browser cache the admin list
  res.setHeader('Cache-Control', 'no-store');

  if (req.method === 'OPTIONS') return res.status(200).end();

  if (!kvUrl || !kvToken) {
    return res.status(503).json({ error: 'Storage not configured. Add Vercel KV to this project.' });
  }

  // ---- GET: count for anyone, full list only with the password ----
  if (req.method === 'GET') {
    const url = new URL(req.url, 'http://x');
    const pw  = url.searchParams.get('pw');

    const count = (await redis(kvUrl, kvToken, 'SCARD', 'iris:waitlist')) ?? 0;

    if (pw === null) return res.json({ count });          // plain count, unchanged
    if (gateUnavailable(res)) return;                     // before the compare
    if (!samePass(pw)) {
      // deliberately vague, and slow enough to make guessing tedious
      await new Promise((r) => setTimeout(r, 700));
      return res.status(401).json({ error: 'Wrong password' });
    }

    const emails = (await redis(kvUrl, kvToken, 'SMEMBERS', 'iris:waitlist')) || [];
    emails.sort();
    return res.json({ count, emails });
  }

  // ---- POST: join the waitlist ----
  if (req.method === 'POST') {
    const body  = await readBody(req);
    const email = (body.email || '').trim().toLowerCase();

    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return res.status(400).json({ error: 'Invalid email' });
    }

    const added = await redis(kvUrl, kvToken, 'SADD', 'iris:waitlist', email);

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
<p style="margin-top:48px;font-size:12px;color:#bbb">The Iris team</p>
</body></html>`,
          text: "You're on the Iris waitlist. We'll email you the moment Iris is ready to download.",
        }),
      }).catch(() => {}); // non-fatal
    }

    return res.json({ success: true, new: added === 1 });
  }

  // ---- DELETE: remove one address, for pruning test or bad entries ----
  if (req.method === 'DELETE') {
    if (gateUnavailable(res)) return;                     // before the compare
    const url = new URL(req.url, 'http://x');
    if (!samePass(url.searchParams.get('pw'))) {
      await new Promise((r) => setTimeout(r, 700));
      return res.status(401).json({ error: 'Wrong password' });
    }
    const body  = await readBody(req);
    const email = (body.email || '').trim().toLowerCase();
    if (!email) return res.status(400).json({ error: 'No email given' });

    const removed = await redis(kvUrl, kvToken, 'SREM', 'iris:waitlist', email);
    const count   = (await redis(kvUrl, kvToken, 'SCARD', 'iris:waitlist')) ?? 0;
    return res.json({ success: true, removed: removed === 1, count });
  }

  return res.status(405).json({ error: 'Method not allowed' });
};
