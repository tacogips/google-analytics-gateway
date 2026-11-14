# Konjac Pubpage: Tag Embedding and Deployment Notes

Findings from repo exploration on 2026-08-24 (source: ../konjac).
This is the verification target for the end-to-end gateway test: embed a Google tag
into the konjac product page, deploy, and observe hits via the gateway's GA4
realtime/report queries.

## Site shape

- Static multi-page site under `konjac/pubpage/`, built with Vite 8 (6 HTML entry
  points declared in `pubpage/vite.config.js`), deployed as a Cloudflare Worker with
  static assets (worker name `konjac-product`, config `pubpage/wrangler.jsonc`).
- Deployed URL: https://konjac-note.com (plus www + legacy konjaknote.com hosts that
  301 to the apex via `pubpage/src/worker.js`).
- Every page loads the shared ES module `pubpage/src/main.js`; there is no shared
  head partial (each of the 6 pages has its own literal <head>).
- No existing gtag/GTM snippet or measurement id anywhere in the repo.

## Deploy commands (konjac/mise.toml lines 44-85)

```bash
mise run page:install   # npm --prefix pubpage ci
mise run page:check     # npm run build && npm run validate
mise run page:deploy    # kinko exec --env CLOUDFLARE_API_TOKEN,CLOUDFLARE_ACCOUNT_ID -- npm --prefix pubpage run deploy
```

`npm run deploy` = `npm run check && wrangler deploy`, so the build validator gates
every deploy. Cloudflare credentials come from the konjac repo-scoped kinko vault.

## Hard blockers to clear when embedding a tag

1. CSP in `pubpage/public/_headers`: `script-src 'self'` blocks gtag.js and
   `connect-src 'self'` blocks GA4 beacons. Minimum edit: add
   `https://www.googletagmanager.com` to script-src and
   `https://*.google-analytics.com https://*.analytics.google.com
   https://www.googletagmanager.com` to connect-src.
2. `pubpage/scripts/validate-build.mjs` rejects any built HTML matching
   `/<script[^>]+src=["']https?:/i`. Either relax the regex or (preferred) load the
   tag from `src/main.js` so no external <script> appears in HTML.
3. The validator also asserts `_headers` still contains
   `Content-Security-Policy:`, `X-Konjac-Deployment: workers-static-assets`, and
   `Cross-Origin-Opener-Policy: same-origin` — preserve those keys when editing.

## Recommended embedding approach

Inject the gtag bootstrap from `pubpage/src/main.js` (single file, loaded by all 6
pages, bundled first-party so `script-src 'self'` covers the bootstrap; only the
external gtag.js script-src entry + GA connect-src entries are needed in CSP).
Tradeoff: tag fires after module load rather than in <head> — acceptable for a GA4
page_view verification.

## Docs to update in konjac when the tag ships

- `design-docs/specs/product-page.md` (build/deployment contract section)
- `PRIVACY.md` section "Websites, cookies, analytics, and support" (analytics/consent
  claim becomes load-bearing)
- `README.md` deploy runbook if commands change
