import { useEffect, useRef } from 'react'
import { Link, NavLink, Route, Routes, useLocation } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { getPageMeta, localeFromPath, locales, type Locale } from './i18n'
import './App.css'

const releaseUrl = 'https://github.com/romainfrezier/key-recorder/releases/latest'
const screenshotUrl = `${import.meta.env.BASE_URL}screenshots/key-recorder-configuration.png`
const languageNames = { en: 'English', fr: 'Français', it: 'Italiano' }

function AppIcon() {
  return <img className="brand-mark" src={`${import.meta.env.BASE_URL}key-recorder-icon.png`} alt="" width="36" height="36" />
}

function useSiteMeta() {
  const { i18n } = useTranslation()
  const { pathname } = useLocation()
  const previousPath = useRef(pathname)
  const locale = localeFromPath(pathname)
  useEffect(() => {
    const { title, description } = getPageMeta(pathname)
    document.documentElement.lang = locale
    document.title = title
    for (const [selector, value] of [
      ['meta[name="description"]', description],
      ['meta[property="og:title"]', title],
      ['meta[property="og:description"]', description],
      ['meta[name="twitter:title"]', title],
      ['meta[name="twitter:description"]', description],
    ]) document.querySelector(selector)?.setAttribute('content', value)
    const base = new URL(import.meta.env.BASE_URL, import.meta.env.VITE_SITE_URL || window.location.origin)
    const url = new URL(pathname.replace(/^\//, ''), base).href
    document.querySelector('link[rel="canonical"]')?.setAttribute('href', url)
    document.querySelector('meta[property="og:url"]')?.setAttribute('content', url)
    document.querySelectorAll<HTMLLinkElement>('link[rel="alternate"]').forEach((link) => {
      link.href = new URL(link.hreflang === 'x-default' ? '' : `${link.hreflang}${pathname.replace(/^\/(en|fr|it)/, '')}`, base).href
    })
    void i18n.changeLanguage(locale)
    if (previousPath.current !== pathname) {
      window.scrollTo({ top: 0, behavior: 'instant' })
      document.querySelector<HTMLElement>('main')?.focus({ preventScroll: true })
      previousPath.current = pathname
    }
  }, [i18n, locale, pathname])
  return locale
}

function Header({ locale }: { locale: Locale }) {
  const { t } = useTranslation(undefined, { lng: locale })
  const sectionPath = useLocation().pathname.replace(/^\/(en|fr|it)/, '') || '/'
  return <header className="site-header">
    <Link className="brand" to={`/${locale}/`}><AppIcon /><span translate="no">Key Recorder</span></Link>
    <nav className="main-nav" aria-label={t('nav.label')}>
      <NavLink to={`/${locale}/researchers/`}>{t('nav.researchers')}</NavLink>
      <NavLink to={`/${locale}/privacy/`}>{t('nav.privacy')}</NavLink>
      <NavLink to={`/${locale}/download/`}>{t('nav.download')}</NavLink>
    </nav>
    <nav className="language-switcher" aria-label={t('language.label')}>
      {locales.map((item) => <Link key={item} aria-current={item === locale ? 'page' : undefined} to={`/${item}${sectionPath}`} hrefLang={item} lang={item} aria-label={languageNames[item]}>{item.toUpperCase()}</Link>)}
    </nav>
  </header>
}

function Footer({ locale }: { locale: Locale }) {
  const { t } = useTranslation(undefined, { lng: locale })
  return <footer className="site-footer">
    <div><Link className="brand" to={`/${locale}/`}><AppIcon /><span translate="no">Key Recorder</span></Link><p>{t('footer.tagline')}</p></div>
    <div className="footer-links">
      <Link to={`/${locale}/researchers/`}>{t('nav.researchers')}</Link>
      <Link to={`/${locale}/privacy/`}>{t('nav.privacy')}</Link>
      <a href="https://github.com/romainfrezier/key-recorder">GitHub</a>
      <a href="https://buymeacoffee.com/romainfrezier">{t('footer.support')}</a>
    </div>
    <p className="footer-note">{t('footer.license')}</p>
  </footer>
}

function StructuredData({ locale }: { locale: Locale }) {
  const { t } = useTranslation(undefined, { lng: locale })
  const data = [
    { '@context': 'https://schema.org', '@type': 'Organization', name: 'Key Recorder', url: 'https://key-recorder.com/', logo: `https://key-recorder.com${import.meta.env.BASE_URL}key-recorder-icon.png`, sameAs: ['https://github.com/romainfrezier/key-recorder', 'https://buymeacoffee.com/romainfrezier'] },
    { '@context': 'https://schema.org', '@type': 'SoftwareApplication', name: 'Key Recorder', operatingSystem: 'macOS 15.1 or later', applicationCategory: 'UtilitiesApplication', description: t('seo.description'), inLanguage: locale, url: `https://key-recorder.com/${locale}/`, downloadUrl: releaseUrl, offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' } },
  ]
  return <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(data) }} />
}

function CSVExample({ locale }: { locale: Locale }) {
  const { t } = useTranslation(undefined, { lng: locale })
  return <div className="observation-sheet">
    <table>
      <caption>{t('home.example.caption')}</caption>
      <thead><tr><th scope="col">{t('home.example.csv.interval')}</th><th scope="col">{t('home.protocol.keyA')}</th><th scope="col">{t('home.protocol.keyB')}</th></tr></thead>
      <tbody>
        <tr><th scope="row">0s – 30s</th><td>12.450</td><td>4.200</td></tr>
        <tr><th scope="row">30s – 60s</th><td>8.100</td><td>10.000</td></tr>
      </tbody>
      <tfoot><tr><th scope="row">TOTAL</th><td>20.550</td><td>14.200</td></tr></tfoot>
    </table>
  </div>
}

function HomePage({ locale }: { locale: Locale }) {
  const { t } = useTranslation(undefined, { lng: locale })
  return <>
    <section className="hero section-shell">
      <div className="hero-copy">
        <h1>{t('home.hero.title')}<br />{t('home.hero.emphasis')}</h1>
        <div className="hero-description">
          <p className="hero-intro">{t('home.hero.body')}</p>
          <div className="hero-actions"><Link className="button button-primary" to={`/${locale}/download/`}>{t('home.hero.cta')}</Link><Link className="text-link" to={`/${locale}/researchers/`}>{t('home.hero.secondary')}</Link></div>
          <p className="micro-note">{t('home.hero.requirement')}</p>
        </div>
      </div>
      <ul className="product-facts" role="list"><li>{t('common.keys')}</li><li>{t('common.local')}</li><li>{t('common.format')}</li></ul>
      <figure className="hero-screenshot">
        <a className="screenshot-frame" href={screenshotUrl} target="_blank" rel="noreferrer" aria-label={t('common.enlarge')}><img src={screenshotUrl} alt={t('home.screenshot.alt')} width="1175" height="768" fetchPriority="high" /></a>
        <figcaption>{t('home.screenshot.caption')}</figcaption>
      </figure>
    </section>
    <section className="section-shell feature-section" aria-labelledby="workflow-title">
      <h2 id="workflow-title">{t('home.featuresTitle')}</h2>
      <ol className="workflow-steps" role="list">{[1, 2, 3].map((step) => <li key={step}><span className="step-number" aria-hidden="true">{step}</span><h3>{t(`home.features.${step}.title`)}</h3><p>{t(`home.features.${step}.body`)}</p></li>)}</ol>
    </section>
    <section className="data-section">
      <div className="section-shell observation-section"><div className="observation-copy"><h2>{t('home.example.title')}</h2><p>{t('home.example.body')}</p><Link className="text-link" to={`/${locale}/use-cases/csv-export/`}>{t('useCases.csv.title')}</Link></div><CSVExample locale={locale} /></div>
    </section>
    <section className="section-shell use-case-section" aria-labelledby="use-cases-title">
      <h2 id="use-cases-title">{t('useCases.homeTitle')}</h2>
      <div className="use-case-list">{(['observation', 'csv'] as const).map((page) => <article key={page}><h3><Link to={`/${locale}/use-cases/${page === 'observation' ? 'behavioral-observation' : 'csv-export'}/`}>{t(`useCases.${page}.title`)}</Link></h3><p>{t(`useCases.${page}.intro`)}</p></article>)}</div>
    </section>
    <section className="download-band"><div className="section-shell download-inner"><h2>{t('home.download.title')}</h2><div><Link className="button button-light" to={`/${locale}/download/`}>{t('home.hero.cta')}</Link><p>{t('home.hero.requirement')}</p></div></div></section>
  </>
}

type InformationPageKey = 'researchers' | 'privacy' | 'download' | 'observation' | 'csv'
const informationSections = {
  researchers: ['prepare', 'record', 'read'],
  privacy: ['local', 'permissions', 'limits'],
  download: ['requirements', 'install', 'release'],
  observation: ['sections.1', 'sections.2', 'sections.3'],
  csv: ['sections.1', 'sections.2', 'sections.3'],
}

function InformationPage({ locale, page }: { locale: Locale; page: InformationPageKey }) {
  const { t } = useTranslation(undefined, { lng: locale })
  const prefix = page === 'observation' || page === 'csv' ? `useCases.${page}` : page
  return <section className="section-shell info-page">
    <Link className="text-link back-link" to={`/${locale}/`}>{t('common.backHome')}</Link>
    <h1>{t(`${prefix}.title`)}</h1>
    <p className="info-lead">{t(`${prefix}.intro`)}</p>
    {page === 'download' && <div className="download-details"><a className="button button-primary" href={releaseUrl}>{t('common.download')}</a><p>{t('common.downloadNote')}</p></div>}
    <div className="info-list">{informationSections[page].map((section) => <article key={section} className="info-item"><h2>{t(`${prefix}.${section}.title`)}</h2><p>{t(`${prefix}.${section}.body`)}</p></article>)}</div>
    {page === 'csv' && <CSVExample locale={locale} />}
    {page !== 'download' && <Link className="button button-primary info-button" to={`/${locale}/download/`}>{t('home.hero.cta')}</Link>}
  </section>
}

function LanguageLanding() {
  return <main className="language-landing" id="main-content" tabIndex={-1}><div className="landing-card">
    <div className="brand"><AppIcon /><span translate="no">Key Recorder</span></div>
    <h1>Choose your language</h1>
    <nav className="landing-options" aria-label="Language">{locales.map((locale) => <Link key={locale} to={`/${locale}/`} lang={locale} hrefLang={locale}>{languageNames[locale]}</Link>)}</nav>
  </div></main>
}

function LocalizedSite({ locale }: { locale: Locale }) {
  const { t } = useTranslation(undefined, { lng: locale })
  return <>
    <a className="skip-link" href="#main-content">{t('common.skip')}</a>
    <Header locale={locale} /><StructuredData locale={locale} />
    <main id="main-content" tabIndex={-1}><Routes>
      <Route path="/" element={<HomePage locale={locale} />} />
      <Route path="/researchers/" element={<InformationPage locale={locale} page="researchers" />} />
      <Route path="/privacy/" element={<InformationPage locale={locale} page="privacy" />} />
      <Route path="/download/" element={<InformationPage locale={locale} page="download" />} />
      <Route path="/use-cases/behavioral-observation/" element={<InformationPage locale={locale} page="observation" />} />
      <Route path="/use-cases/csv-export/" element={<InformationPage locale={locale} page="csv" />} />
      <Route path="*" element={<HomePage locale={locale} />} />
    </Routes></main><Footer locale={locale} />
  </>
}

export default function App() {
  const locale = useSiteMeta()
  return <Routes><Route path="/" element={<LanguageLanding />} /><Route path="/:locale/*" element={<LocalizedSite locale={locale} />} /></Routes>
}
