import { mkdir, readFile, rm, writeFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const dist = join(root, 'dist')
const server = join(root, 'dist-server')
const baseHtml = await readFile(join(dist, 'index.html'), 'utf8')
const { render } = await import(pathToFileURL(join(server, 'ssr.js')).href)
const siteUrl = (process.env.VITE_SITE_URL || 'http://localhost:5173').replace(/\/$/, '')
const routes = ['/', '/en/', '/en/researchers/', '/en/privacy/', '/en/download/', '/fr/', '/fr/researchers/', '/fr/privacy/', '/fr/download/', '/it/', '/it/researchers/', '/it/privacy/', '/it/download/']

await rm(server, { recursive: true, force: true })
for (const route of routes) {
  if (route === '/') continue
  const html = await render(route)
  const locale = route.split('/')[1]
  const title = locale === 'fr' ? 'Key Recorder — Mesurer les observations, localement' : locale === 'it' ? 'Key Recorder — Misura le osservazioni, localmente' : 'Key Recorder — Measure observations, locally'
  const description = locale === 'fr' ? 'Un instrument macOS ciblé pour les observations comportementales courtes et contrôlées.' : locale === 'it' ? 'Uno strumento macOS essenziale per osservazioni comportamentali brevi e controllate.' : 'A focused macOS instrument for short, controlled behavioral observations.'
  const localizedPath = route.replace(/^\/(en|fr|it)/, '')
  const alternates = ['en', 'fr', 'it'].map((item) => `<link rel="alternate" hreflang="${item}" href="${siteUrl}/${item}${localizedPath}" />`).join('')
  const fullUrl = `${siteUrl}${route}`
  const page = baseHtml.replace('<html lang="en">', `<html lang="${locale}">`).replace('<head>', `<head><link rel="canonical" href="${fullUrl}" />${alternates}<link rel="alternate" hreflang="x-default" href="${siteUrl}/" />`).replace('<title>Key Recorder — Measure observations, locally</title>', `<title>${title}</title>`).replace(/<meta name="description" content="[^"]*" \/>/, `<meta name="description" content="${description}" />`).replace('<div id="root"></div>', `<div id="root">${html}</div>`)
  const target = join(dist, route.slice(1), 'index.html')
  await mkdir(dirname(target), { recursive: true })
  await writeFile(target, page)
}

const urls = routes.filter((route) => route !== '/').map((route) => `<url><loc>${siteUrl}${route}</loc>${['en', 'fr', 'it'].map((item) => `<xhtml:link rel="alternate" hreflang="${item}" href="${siteUrl}/${item}${route.replace(/^\/(en|fr|it)/, '')}" />`).join('')}<xhtml:link rel="alternate" hreflang="x-default" href="${siteUrl}/" /></url>`).join('')
await writeFile(join(dist, 'sitemap.xml'), `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">${urls}</urlset>`)
await writeFile(join(dist, 'robots.txt'), `User-agent: *\nAllow: /\nSitemap: ${siteUrl}/sitemap.xml\n`)
