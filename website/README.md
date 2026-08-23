# Key Recorder website

React/Vite site for the Key Recorder macOS app. It is a static, multilingual
site with English, French and Italian routes, localized metadata, and
pre-rendered HTML for search engines.

## Development

```bash
npm install
npm run dev
```

## Checks

```bash
npm run typecheck
npm run lint
npm run test
npm run build
```

The build generates localized pages, `sitemap.xml`, and `robots.txt`.

For deployment, set `VITE_SITE_URL` to the public site origin. For a GitHub
Pages project site, also set `VITE_BASE_PATH=/key-recorder/`; custom domains
use `VITE_BASE_PATH=/`.
