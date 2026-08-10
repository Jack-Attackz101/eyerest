// Vercel serverless function: the current build, behind the admin gate.
//
// Same password as the waitlist list. ADMIN_PASS is read here on the server, so
// there is no second secret and nothing about this download exists in the page
// source for a visitor who has not entered it. The URL itself comes back in the
// response rather than being written into the HTML.
//
// Three dates, because they are not the same thing:
//
//   lastModified  what the CDN serves for /Iris.dmg. Vercel stamps this at
//                 deploy time, not at build time, so on a freshly deployed site
//                 it reads as today even when the binary is weeks old. Shown
//                 because it is the file's own header, and labelled "served" so
//                 it cannot be mistaken for the build date.
//   builtAt       the commit that last touched website/Iris.dmg. The DMG is a
//                 binary committed by hand, so this is when it was really built.
//   sourceAt      the newest commit touching the app sources under Iris/.
//
// builtAt more than STALE_DAYS behind sourceAt means the download is missing
// work that is already in the app, which is the same comparison the DMG
// freshness CI check makes.

const ADMIN_PASS  = process.env.ADMIN_PASS || '4242';
const REPO        = 'Jack-Attackz101/eyerest';
const DMG_PATH    = '/Iris.dmg';
const SOURCE_PATH = 'Iris';                 // every .swift file lives under here
const DMG_REPO_PATH = 'website/Iris.dmg';
const STALE_DAYS  = 7;

/** constant-time-ish compare, so the password cannot be guessed by timing */
function samePass(given) {
  const a = String(given || '');
  const b = ADMIN_PASS;
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** Date of the newest commit touching a path, or null if GitHub will not say. */
async function newestCommitDate(path) {
  const url = `https://api.github.com/repos/${REPO}/commits` +
              `?per_page=1&path=${encodeURIComponent(path)}`;
  try {
    const res = await fetch(url, {
      headers: { 'User-Agent': 'iris-website', Accept: 'application/vnd.github+json' },
    });
    if (!res.ok) return null;
    const commits = await res.json();
    return commits?.[0]?.commit?.committer?.date || null;
  } catch {
    return null;
  }
}

/** The Last-Modified header the site itself serves for the DMG. */
async function servedDate(req) {
  try {
    const proto = String(req.headers['x-forwarded-proto'] || 'https').split(',')[0];
    const host  = req.headers['x-forwarded-host'] || req.headers.host;
    if (!host) return null;
    const res = await fetch(`${proto}://${host}${DMG_PATH}`, { method: 'HEAD' });
    return res.headers.get('last-modified');
  } catch {
    return null;
  }
}

module.exports = async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  const url = new URL(req.url, 'http://x');
  if (!samePass(url.searchParams.get('pw'))) {
    // deliberately vague, and slow enough to make guessing tedious
    await new Promise((r) => setTimeout(r, 700));
    return res.status(401).json({ error: 'Wrong password' });
  }

  const [lastModified, builtAt, sourceAt] = await Promise.all([
    servedDate(req),
    newestCommitDate(DMG_REPO_PATH),
    newestCommitDate(SOURCE_PATH),
  ]);

  let daysBehind = null;
  if (builtAt && sourceAt) {
    daysBehind = Math.round(((Date.parse(sourceAt) - Date.parse(builtAt)) / 86400000) * 10) / 10;
  }

  return res.json({
    url: DMG_PATH,
    lastModified,
    builtAt,
    sourceAt,
    daysBehind,
    stale: daysBehind !== null && daysBehind > STALE_DAYS,
  });
};
