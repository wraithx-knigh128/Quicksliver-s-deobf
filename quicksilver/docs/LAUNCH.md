# Launch checklist (nothing here has been done)

**Status: not published. No domain has been bought and nothing has been deployed.** This page is what is needed when you decide to.

## Domain (.com)

Availability and price were looked up read-only through Vercel's registrar on 2026-10-25. Nothing was reserved.

| Name | Available | First year | Renewal |
|---|---|---|---|
| quicksilverdeobf.com | yes | $11.25 | $11.25 |
| quicksilver-deobf.com | yes | $11.25 | $11.25 |
| quicksilverdeobfuscator.com | yes | $11.25 | $11.25 |
| qsdeobf.com | yes | $11.25 | $11.25 |
| quicksilverlua.com | yes | $11.25 | $11.25 |
| quicksilver-lua.com | yes | $11.25 | $11.25 |
| luadeobf.com | yes | $11.25 | $11.25 |
| quicksilverlab.com | yes | $11.25 | $11.25 |
| usequicksilver.com | yes | $11.25 | $11.25 |
| quicksilver.com, getquicksilver.com, deobfuscator.com | taken | | |

Availability can change at any time; check again right before buying. A `.com` is only "official" in the sense that you own it: nothing about the name ties it to the product until you point it at the deployment and put
the same name in the page (`<title>`, brand and About dialog already say "QuickSilver"). Check that the name does not collide with a trademark you care about before buying; "Quicksilver" is a common word and name.

## Steps, when you say go

1. Buy the domain (you confirm; it costs money).
2. Create the Vercel project from this repository's `quicksilver/` folder (no build command; output directory `.`; `vercel.json` already sets headers and the three functions).
3. Add the domain to the project and wait for DNS and the certificate.
4. Set `QS_ORIGIN_GITHUB_TOKEN` (no scopes) if the online half of the AI check should work; leave it unset and the page says it is not configured.
5. Decide on licensing (`docs/LICENSING.md`): generate keys and set the public key, or leave the site open.
6. Deploy a preview first, run `npm run test:e2e` against it, then promote.

## Before it goes public

* Read `THIRD_PARTY_NOTICES.md`: Prometheus requires its attribution sentence (it is in the About dialog, the README and the notices).
* The sample files are output of Prometheus, Hercules, IronBrew 2 and Zenfus plus constructed examples; their licences are in the notices. Output of Colisseum (AGPL-3.0) and of tools without a licence file is kept in the git-ignored `tests/corpus/obfuscated-local/`, and `/tests` is in `.vercelignore`, so it is not deployed.
* The AI check is a style estimate, not proof; the page says so. Do not present its percentages as accusations about a person.
* `index.html` carries `<meta name="robots" content="noindex, nofollow">` so a stray preview deployment is not indexed. Remove that line when the site is meant to be found. There is no `robots.txt`, no analytics and no third-party request.
