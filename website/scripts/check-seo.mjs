import { access, readFile } from 'node:fs/promises'
import { join } from 'node:path'

const root = new URL('../', import.meta.url)
const routes = ['/en/', '/en/researchers/', '/en/privacy/', '/en/download/', '/en/use-cases/behavioral-observation/', '/en/use-cases/csv-export/', '/fr/', '/fr/researchers/', '/fr/privacy/', '/fr/download/', '/fr/use-cases/behavioral-observation/', '/fr/use-cases/csv-export/', '/it/', '/it/researchers/', '/it/privacy/', '/it/download/', '/it/use-cases/behavioral-observation/', '/it/use-cases/csv-export/']
for (const route of routes) {
  const path = join(root.pathname, 'dist', route.slice(1), 'index.html')
  await access(path)
  const html = await readFile(path, 'utf8')
  if (!html.includes('Key Recorder') || !html.includes('rel="canonical"') || !html.includes('hreflang="en"') || !html.includes('hreflang="fr"') || !html.includes('hreflang="it"') || !html.includes('application/ld+json') || !html.includes('og:title')) throw new Error(`SEO metadata missing for ${route}`)
}
await access(join(root.pathname, 'dist', 'sitemap.xml'))
await access(join(root.pathname, 'dist', 'robots.txt'))
console.log(`SEO checks passed for ${routes.length} localized routes`)
