// Per-IP attempt limiting for the two gated endpoints.
//
// The gate is a short code with a 700ms delay and nothing else, so end to end
// an attempt costs about a second and the whole space can be walked in a few
// hours. Behind it are the waitlist emails and the app build. Five wrong
// answers from one IP and that IP is refused for fifteen minutes.
//
// A lockout returns 429, not 401, so it is distinguishable: 401 means the
// password was wrong, 429 means stop asking. Counters live in the KV store that
// is already there, keyed by IP with a TTL, so nothing new is introduced and
// the records clean themselves up.
//
// The attempted password is never stored and never logged. Only a count.
//
// Underscore-prefixed so Vercel treats it as a module rather than an endpoint.

const MAX_ATTEMPTS = 5;
const LOCKOUT_SECONDS = 15 * 60;

const KV_URL = process.env.UPSTASH_REDIS_REST_URL || process.env.KV_REST_API_URL;
const KV_TOKEN = process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN;

/** The caller's IP, as Vercel reports it. */
function clientIP(req) {
  const forwarded = String(req.headers['x-forwarded-for'] || '');
  const first = forwarded.split(',')[0].trim();
  return first || String(req.headers['x-real-ip'] || '') || 'unknown';
}

async function command(...args) {
  const res = await fetch(KV_URL, {
    method: 'POST',
    headers: { Authorization: `Bearer ${KV_TOKEN}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(args),
  });
  const { result } = await res.json();
  return result;
}

const key = (ip) => `iris:authfail:${ip}`;

/**
 * Whether this IP is locked out, and for how much longer.
 *
 * If the store is unreachable this reports "not locked" rather than refusing
 * everyone: the password is still the thing protecting the endpoint, and a KV
 * outage should not take the panel down with it. It says so in the log.
 */
async function lockoutFor(ip) {
  if (!KV_URL || !KV_TOKEN) return null;
  try {
    const attempts = Number(await command('GET', key(ip))) || 0;
    if (attempts < MAX_ATTEMPTS) return null;
    const ttl = Number(await command('TTL', key(ip)));
    return { retryAfter: ttl > 0 ? ttl : LOCKOUT_SECONDS, attempts };
  } catch {
    console.error('rate limit store unreachable, allowing the attempt through');
    return null;
  }
}

/** Count one wrong password. The window restarts on every failure. */
async function recordFailure(ip) {
  if (!KV_URL || !KV_TOKEN) return 0;
  try {
    const attempts = Number(await command('INCR', key(ip))) || 1;
    await command('EXPIRE', key(ip), String(LOCKOUT_SECONDS));
    return attempts;
  } catch {
    return 0;
  }
}

/** A correct password clears that IP's record. */
async function clearFailures(ip) {
  if (!KV_URL || !KV_TOKEN) return;
  try {
    await command('DEL', key(ip));
  } catch {
    // The key expires on its own, so there is nothing to recover from here.
  }
}

/**
 * The whole dance for one gated request.
 *
 * Returns true when the response has been sent and the handler should stop.
 * Keeps the shape of both endpoints the same, so neither grows its own version
 * of this and they cannot drift apart.
 */
async function refuseIfLockedOut(req, res) {
  const ip = clientIP(req);
  const lock = await lockoutFor(ip);
  if (!lock) return false;
  res.setHeader('Retry-After', String(lock.retryAfter));
  res.status(429).json({ error: 'Too many attempts. Try again later.' });
  return true;
}

module.exports = {
  MAX_ATTEMPTS,
  LOCKOUT_SECONDS,
  clientIP,
  lockoutFor,
  recordFailure,
  clearFailures,
  refuseIfLockedOut,
};
