// Vercel serverless function: the current build, behind the admin gate.
//
// Same password as the waitlist list. ADMIN_PASS is read here on the server, so
// there is no second secret and nothing about this download exists in the page
// source for a visitor who has not entered it. The URL itself comes back in the
// response rather than being written into the HTML.
//
// WHAT IT SERVES
//
// The newest GitHub release asset ending in .dmg, not the binary committed at
// website/Iris.dmg. That binary is added by hand, so it goes stale every time a
// Swift file changes without someone remembering to rebuild it, which is how
// the download ended up twelve days behind the app. A release asset is produced
// by the release, so it cannot drift.
//
// The committed DMG stays as the fallback, for three cases that are all real:
// no release published yet, a release with no .dmg attached, and the GitHub API
// being unreachable or rate limited. The response always says which one it is
// serving so the panel can label it rather than guess.
//
// Three dates, because they are not the same thing:
//
//   lastModified  what the CDN serves for /Iris.dmg. Vercel stamps this at
//                 deploy time, not at build time, so on a freshly deployed site
//                 it reads as today even when the binary is weeks old. Shown
//                 because it is the file's own header, and labelled "served" so
//                 it cannot be mistaken for the build date. Only meaningful
//                 when the committed DMG is the thing being served.
//   builtAt       when the download was actually built: the release's published
//                 date, or for the committed DMG the commit that last touched
//                 website/Iris.dmg.
//   sourceAt      the newest commit touching the app sources under Iris/.
//
// builtAt more than STALE_DAYS behind sourceAt means the download is missing
// work that is already in the app, which is the same comparison the DMG
// freshness CI check makes.

// No fallback. This used to read `process.env.ADMIN_PASS || <a literal>`, and
// because this repo is public that literal was a published password: any deploy
// target without the variable set accepted it, silently. Setting the variable in
// Vercel closed that on production, but the pattern would come back on the next
// preview branch or deploy target, or the day someone removes the variable.
//
// So it fails closed. A missing secret refuses every gated request with a 500,
// which is a visible misconfiguration rather than an invisible open door. A 401
// would be worse here: it looks exactly like a wrong password, so nobody would
// know the gate had stopped being a gate.
const ADMIN_PASS  = process.env.ADMIN_PASS;
if (!ADMIN_PASS) {
  console.error('ADMIN_PASS is not set, refusing every gated request');
}

const REPO        = 'Jack-Attackz101/eyerest';
const DMG_PATH    = '/Iris.dmg';
const SOURCE_PATH = 'Iris';                 // every .swift file lives under here
const DMG_REPO_PATH = 'website/Iris.dmg';
const STALE_DAYS  = 7;

// The GitHub API is unauthenticated here, which is 60 requests an hour per IP.
// One admin opening the panel costs three, so this only bites if something goes
// wrong, but running out returns a confusing error rather than a download. The
// cache lives in module scope, so it is per warm instance: it cuts the calls a
// lot without pretending to be a global rate limiter.
const CACHE_MS = 5 * 60 * 1000;
const cache = new Map();

async function cached(key, load) {
  const hit = cache.get(key);
  if (hit && Date.now() - hit.at < CACHE_MS) return hit.value;
  const value = await load();
  cache.set(key, { at: Date.now(), value });
  return value;
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

async function github(pathAndQuery) {
  const res = await fetch(`https://api.github.com/repos/${REPO}${pathAndQuery}`, {
    headers: { 'User-Agent': 'iris-website', Accept: 'application/vnd.github+json' },
  });
  return res;
}

/**
 * The newest release asset ending in .dmg.
 *
 * Returns one of:
 *   { state: 'release', tag, url, sizeBytes, publishedAt }
 *   { state: 'none' }          no release yet, or the latest one has no .dmg
 *   { state: 'unreachable' }   GitHub said no, or the network did
 *
 * "none" is a real answer and gets cached. "unreachable" is not, so it is not.
 */
async function latestReleaseDmg() {
  const hit = cache.get('release');
  if (hit && Date.now() - hit.at < CACHE_MS) return hit.value;

  let result;
  try {
    const res = await github('/releases/latest');
    if (res.status === 404) {
      result = { state: 'none', why: 'no release published yet' };
    } else if (!res.ok) {
      result = { state: 'unreachable', why: `the GitHub API answered ${res.status}` };
    } else {
      const release = await res.json();
      const asset = (release.assets || []).find((a) => String(a.name).toLowerCase().endsWith('.dmg'));
      result = asset
        ? {
            state: 'release',
            tag: release.tag_name || release.name || 'latest',
            url: asset.browser_download_url,
            sizeBytes: asset.size,
            publishedAt: release.published_at || asset.updated_at || null,
          }
        : { state: 'none', why: `release ${release.tag_name || 'latest'} has no .dmg asset` };
    }
  } catch {
    result = { state: 'unreachable', why: 'could not reach the GitHub API' };
  }

  if (result.state !== 'unreachable') cache.set('release', { at: Date.now(), value: result });
  return result;
}

/** Date of the newest commit touching a path, or null if GitHub will not say. */
async function newestCommitDate(path) {
  return cached('commit:' + path, async () => {
    try {
      const res = await github(`/commits?per_page=1&path=${encodeURIComponent(path)}`);
      if (!res.ok) return null;
      const commits = await res.json();
      return commits?.[0]?.commit?.committer?.date || null;
    } catch {
      return null;
    }
  });
}

/** The Last-Modified header and size the site itself serves for the DMG. */
async function servedDmg(req) {
  try {
    const proto = String(req.headers['x-forwarded-proto'] || 'https').split(',')[0];
    const host  = req.headers['x-forwarded-host'] || req.headers.host;
    if (!host) return { lastModified: null, sizeBytes: null };
    const res = await fetch(`${proto}://${host}${DMG_PATH}`, { method: 'HEAD' });
    const size = Number(res.headers.get('content-length'));
    return {
      lastModified: res.headers.get('last-modified'),
      sizeBytes: Number.isFinite(size) && size > 0 ? size : null,
    };
  } catch {
    return { lastModified: null, sizeBytes: null };
  }
}

module.exports = async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  // Before the compare, not after: with no secret configured there is nothing to
  // compare against, and this must not be mistakable for a wrong password.
  if (!ADMIN_PASS) {
    console.error('ADMIN_PASS is not set, refusing /api/build');
    return res.status(500).json({ error: 'Server misconfigured' });
  }

  const url = new URL(req.url, 'http://x');
  if (!samePass(url.searchParams.get('pw'))) {
    // deliberately vague, and slow enough to make guessing tedious
    await new Promise((r) => setTimeout(r, 700));
    return res.status(401).json({ error: 'Wrong password' });
  }

  const [release, served, dmgCommitAt, sourceAt] = await Promise.all([
    latestReleaseDmg(),
    servedDmg(req),
    newestCommitDate(DMG_REPO_PATH),
    newestCommitDate(SOURCE_PATH),
  ]);

  const serving = release.state === 'release'
    ? {
        source: 'release',
        sourceLabel: `GitHub release ${release.tag}`,
        url: release.url,
        sizeBytes: release.sizeBytes,
        builtAt: release.publishedAt,
        note: null,
      }
    : {
        source: 'committed',
        sourceLabel: 'committed DMG',
        url: DMG_PATH,
        sizeBytes: served.sizeBytes,
        builtAt: dmgCommitAt,
        note: `${release.why}, serving the committed DMG`,
      };

  let daysBehind = null;
  if (serving.builtAt && sourceAt) {
    daysBehind = Math.round(((Date.parse(sourceAt) - Date.parse(serving.builtAt)) / 86400000) * 10) / 10;
  }

  return res.json({
    ...serving,
    sourceAt,
    daysBehind,
    stale: daysBehind !== null && daysBehind > STALE_DAYS,
    // only meaningful for the committed file, see the note at the top
    lastModified: serving.source === 'committed' ? served.lastModified : null,
  });
};
