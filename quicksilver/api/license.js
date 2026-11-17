// Optional revocation check, deployed as a Vercel serverless function (GET /api/license?id=QS-...).
//
// Licences are verified offline in the browser; this endpoint only answers "has this id been revoked?".
// Revoke a licence by adding its id to the QS_REVOKED_IDS environment variable (comma separated) and
// redeploying or editing the variable. It reveals nothing about other licences.
//
// Written against the plain Node response (statusCode/setHeader/end) so it behaves the same on Vercel, in tests and
// behind any Node server; it does not depend on Vercel's res.status()/res.send() helpers.

const json = (res, status, body, headers = {}) => {
  res.statusCode = status;
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  for (const [k, v] of Object.entries(headers)) res.setHeader(k, v);
  res.end(JSON.stringify(body));
};

export function createHandler({ env = process.env } = {}) {
  return function handler(req, res) {
    if (req.method && req.method !== 'GET') { json(res, 405, { error: 'GET only' }, { Allow: 'GET' }); return; }
    const raw = (req.query && req.query.id) ?? new URL(req.url || '/', 'http://x').searchParams.get('id') ?? '';
    const id = typeof raw === 'string' ? raw : '';
    if (!/^QS-[A-Z0-9-]{4,40}$/.test(id)) { json(res, 400, { error: 'invalid id' }); return; }
    const revoked = (env.QS_REVOKED_IDS || '').split(',').map((s) => s.trim()).filter(Boolean);
    json(res, 200, { id, revoked: revoked.includes(id) });
  };
}

export default createHandler();
