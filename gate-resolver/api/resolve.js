'use strict';

// Vercel serverless function: POST /api/resolve
//
// Uses the shared resolver/handler. The time budget is kept safely under the
// platform's function timeout, and the rate limiter is per warm instance
// (best-effort abuse control; a hard global cap would need a shared store).

const { createResolveHandler } = require('./_lib/handler.js');
const { RateLimiter } = require('./_lib/resolver.js');

const limiter = new RateLimiter({ windowMs: 60_000, max: 20 });

const handler = createResolveHandler({
  rateLimiter: limiter,
  resolveOptions: { budgetMs: 9_000, maxHops: 8, hopTimeoutMs: 8_000 },
});

module.exports = (req, res) => handler(req, res);
