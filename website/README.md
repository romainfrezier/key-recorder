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
npm run build
npm run test
```

The build generates the language chooser, localized pages, `sitemap.xml`, and
`robots.txt`. Tests inspect the built HTML, so run them after the build.

The screenshot illustrates the earlier two-key interface; its caption makes
that explicit. The current app supports one to seven configured keys.

The macOS Quality workflow filters pushes and PRs to app sources, native tests,
the Xcode project, distribution scripts, and its own workflow file. App tags
and manual runs still build a verified DMG; `v*-site` tags do not.

For deployment, set `VITE_SITE_URL` to the public site origin. For a GitHub
Pages project site, also set `VITE_BASE_PATH=/key-recorder/`; custom domains
use `VITE_BASE_PATH=/`.
