import assert from 'node:assert/strict'
import { access, readFile } from 'node:fs/promises'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = fileURLToPath(new URL('../dist/', import.meta.url))
const locales = ['en', 'fr', 'it']
const pages = ['', 'researchers/', 'privacy/', 'download/', 'use-cases/behavioral-observation/', 'use-cases/csv-export/']
const titles = new Set()
for (const locale of locales) {
  for (const page of pages) {
    const route = `/${locale}/${page}`
    const html = await readFile(join(root, route, 'index.html'), 'utf8')
    const title = html.match(/<title>(.*?)<\/title>/)?.[1]
    const description = html.match(/<meta name="description" content="([^"]*)"/)?.[1]
    assert(title?.includes('Key Recorder'), `Missing title: ${route}`)
    assert(!titles.has(title), `Duplicate page title: ${route}`)
    titles.add(title)
    assert(description && description.length > 30, `Missing description: ${route}`)
    assert(html.includes(`<html lang="${locale}">`), `Wrong language: ${route}`)
    assert(html.includes(`property="og:title" content="${title}"`), `Social title differs: ${route}`)
    assert(html.includes(`property="og:description" content="${description}"`), `Social description differs: ${route}`)
    assert.match(html, new RegExp(`rel="canonical" href="[^"]*${route}"`), `Wrong canonical: ${route}`)
    for (const alternate of locales) assert(html.includes(`hreflang="${alternate}"`), `Missing alternate: ${route}`)
    assert.equal((html.match(/<h1[ >]/g) || []).length, 1, `Expected one heading: ${route}`)
    assert(html.includes('href="#main-content"'), `Missing skip link: ${route}`)
    assert(html.includes('application/ld+json'), `Missing structured data: ${route}`)
    assert(!html.includes('[object Object]'), `Invalid prerender: ${route}`)
    if (!page || page === 'use-cases/csv-export/') {
      assert(html.includes('<table>') && html.includes('<caption>') && html.includes('scope="col"'), `Missing accessible CSV: ${route}`)
    }
    if (page === 'download/') {
      assert(html.includes('releases/latest') && html.includes('DMG') && html.includes('ad hoc'), `Incomplete download instructions: ${route}`)
    }
  }
}
const landing = await readFile(join(root, 'index.html'), 'utf8')
for (const locale of locales) assert(landing.includes(`href="/${locale}/"`), `Missing server-rendered language link: ${locale}`)
assert(landing.includes('<h1>Choose your language</h1>'), 'Language chooser must work without JavaScript')
await access(join(root, 'sitemap.xml'))
await access(join(root, 'robots.txt'))
console.log(`SEO, prerender and semantic checks passed for ${titles.size} localized routes and the language chooser`)
