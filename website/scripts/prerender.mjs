import { mkdir, readFile, rm, writeFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const dist = join(root, 'dist')
const server = join(root, 'dist-server')
const baseHtml = await readFile(join(dist, 'index.html'), 'utf8')
const { render } = await import(pathToFileURL(join(server, 'ssr.js')).href)
const siteUrl = (process.env.VITE_SITE_URL || 'http://localhost:5173').replace(/\/$/, '')
const routes = ['/', '/en/', '/en/researchers/', '/en/privacy/', '/en/download/', '/en/use-cases/behavioral-observation/', '/en/use-cases/csv-export/', '/fr/', '/fr/researchers/', '/fr/privacy/', '/fr/download/', '/fr/use-cases/behavioral-observation/', '/fr/use-cases/csv-export/', '/it/', '/it/researchers/', '/it/privacy/', '/it/download/', '/it/use-cases/behavioral-observation/', '/it/use-cases/csv-export/']
const escapeAttribute = (value) => value.replaceAll('&', '&amp;').replaceAll('"', '&quot;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')

await rm(server, { recursive: true, force: true })
for (const route of routes) {
  const { html, title: pageTitle, description: pageDescription } = await render(route)
  const title = escapeAttribute(pageTitle)
  const description = escapeAttribute(pageDescription)
  const locale = route.split('/')[1] || 'en'
  const localizedPath = route.replace(/^\/(en|fr|it)/, '')
  const alternates = ['en', 'fr', 'it'].map((item) => `<link rel="alternate" hreflang="${item}" href="${siteUrl}/${item}${localizedPath}" />`).join('')
  const fullUrl = `${siteUrl}${route}`
  const page = baseHtml.replace('<html lang="en">', `<html lang="${locale}">`).replace('<head>', `<head><link rel="canonical" href="${fullUrl}" />${alternates}<link rel="alternate" hreflang="x-default" href="${siteUrl}/" />`).replace('<title>Key Recorder — Measure observations, locally</title>', `<title>${title}</title>`).replace(/<meta name="description" content="[^"]*" \/>/, `<meta name="description" content="${description}" />`).replace(/<meta property="og:title" content="[^"]*" \/>/, `<meta property="og:title" content="${title}" />`).replace(/<meta property="og:description" content="[^"]*" \/>/, `<meta property="og:description" content="${description}" />`).replace(/<meta property="og:url" content="[^"]*" \/>/, `<meta property="og:url" content="${fullUrl}" />`).replace(/<meta name="twitter:title" content="[^"]*" \/>/, `<meta name="twitter:title" content="${title}" />`).replace(/<meta name="twitter:description" content="[^"]*" \/>/, `<meta name="twitter:description" content="${description}" />`).replace('<div id="root"></div>', `<div id="root">${html}</div>`)
  const target = join(dist, route.slice(1), 'index.html')
  await mkdir(dirname(target), { recursive: true })
  await writeFile(target, page)
}

const urls = routes.filter((route) => route !== '/').map((route) => `<url><loc>${siteUrl}${route}</loc>${['en', 'fr', 'it'].map((item) => `<xhtml:link rel="alternate" hreflang="${item}" href="${siteUrl}/${item}${route.replace(/^\/(en|fr|it)/, '')}" />`).join('')}<xhtml:link rel="alternate" hreflang="x-default" href="${siteUrl}/" /></url>`).join('')
await writeFile(join(dist, 'sitemap.xml'), `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">${urls}</urlset>`)
await writeFile(join(dist, 'robots.txt'), `User-agent: *\nAllow: /\nSitemap: ${siteUrl}/sitemap.xml\n`)
