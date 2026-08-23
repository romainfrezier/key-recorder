import { renderToString } from 'react-dom/server'
import { MemoryRouter } from 'react-router-dom'
import App from './App'
import i18n, { localeFromPath } from './i18n'

export async function render(url: string) {
  await i18n.changeLanguage(localeFromPath(url))
  const basename = import.meta.env.BASE_URL === '/' ? undefined : import.meta.env.BASE_URL.replace(/\/$/, '')
  const entry = basename ? `${basename}${url}` : url
  return renderToString(<MemoryRouter basename={basename} initialEntries={[entry]}><App /></MemoryRouter>)
}
