// Optional revocation check, deployed as a Vercel serverless function (GET /api/license?id=QS-...).
//
// Licences are verified offline in the browser; this endpoint only answers "has this id been revoked?".
// Revoke a licence by adding its id to the QS_REVOKED_IDS environment variable (comma separated) and
// redeploying or editing the variable. It reveals nothing about other licences.

export default function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  const id = String((req.query && req.query.id) || '');
  if (!/^QS-[A-Z0-9-]{4,40}$/.test(id)) {
    res.status(400).send(JSON.stringify({ error: 'invalid id' }));
    return;
  }
  const revoked = (process.env.QS_REVOKED_IDS || '').split(',').map((s) => s.trim()).filter(Boolean);
  res.status(200).send(JSON.stringify({ id, revoked: revoked.includes(id) }));
}
