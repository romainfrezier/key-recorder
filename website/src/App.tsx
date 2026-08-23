import { useEffect } from 'react'
import { Link, Route, Routes, useLocation, useNavigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { localeFromPath, locales, type Locale } from './i18n'
import './App.css'

const releaseUrl = 'https://github.com/romainfrezier/key-recorder/releases/latest'

function useSiteMeta() {
  const { i18n } = useTranslation()
  const { pathname } = useLocation()
  const locale = localeFromPath(pathname)
  useEffect(() => {
    const updateMeta = () => {
      document.documentElement.lang = locale
      document.title = i18n.t('seo.title')
      document.querySelector('meta[name="description"]')?.setAttribute('content', i18n.t('seo.description'))
    }
    if (i18n.language === locale) updateMeta()
    else void i18n.changeLanguage(locale).then(updateMeta)
  }, [i18n, locale])
  return locale
}

function Header({ locale }: { locale: Locale }) {
  const { t } = useTranslation()
  const path = useLocation().pathname
  const sectionPath = path.replace(/^\/(en|fr|it)/, '') || '/'
  return <header className="site-header">
    <Link className="brand" to={`/${locale}/`} aria-label="Key Recorder home"><img className="brand-mark" src={`${import.meta.env.BASE_URL}key-recorder-icon.png`} alt="" /><span>Key Recorder</span></Link>
    <nav className="main-nav" aria-label={t('nav.label')}><Link to={`/${locale}/researchers/`}>{t('nav.researchers')}</Link><Link to={`/${locale}/privacy/`}>{t('nav.privacy')}</Link><Link to={`/${locale}/download/`}>{t('nav.download')}</Link></nav>
    <div className="header-actions"><div className="language-switcher" aria-label={t('language.label')}>{locales.map((item) => <Link key={item} className={item === locale ? 'active' : ''} to={`/${item}${sectionPath}`} hrefLang={item}>{item.toUpperCase()}</Link>)}</div><a className="button button-small button-dark" href={releaseUrl} target="_blank" rel="noreferrer">{t('nav.cta')}</a></div>
  </header>
}

function Footer({ locale }: { locale: Locale }) {
  const { t } = useTranslation()
  return <footer className="site-footer"><div><div className="footer-brand"><img className="brand-mark" src={`${import.meta.env.BASE_URL}key-recorder-icon.png`} alt="" /> Key Recorder</div><p>{t('footer.tagline')}</p></div><div className="footer-links"><Link to={`/${locale}/researchers/`}>{t('nav.researchers')}</Link><Link to={`/${locale}/privacy/`}>{t('nav.privacy')}</Link><a href="https://github.com/romainfrezier/key-recorder" target="_blank" rel="noreferrer">GitHub ↗</a><a className="support-link" href="https://buymeacoffee.com/romainfrezier" target="_blank" rel="noreferrer">{t('footer.support')} ↗</a></div><div className="footer-note">{t('footer.license')}</div></footer>
}

function HomePage({ locale }: { locale: Locale }) {
  const { t } = useTranslation()
  const features = [1, 2, 3].map((number) => ({ title: t(`home.features.${number}.title`), body: t(`home.features.${number}.body`) }))
  return <>
    <section className="hero section-shell"><div className="hero-copy"><p className="eyebrow"><span className="eyebrow-line" />{t('home.eyebrow')}</p><h1>{t('home.hero.title')} <em>{t('home.hero.emphasis')}</em></h1><p className="hero-intro">{t('home.hero.body')}</p><div className="hero-actions"><a className="button button-primary" href={releaseUrl} target="_blank" rel="noreferrer">{t('home.hero.cta')} <span>↗</span></a><Link className="text-link" to={`/${locale}/researchers/`}>{t('home.hero.secondary')} <span>↓</span></Link></div><p className="micro-note"><span className="apple-dot">●</span>{t('home.hero.requirement')}</p></div><figure className="hero-screenshot"><div className="screenshot-frame"><img src={`${import.meta.env.BASE_URL}screenshots/key-recorder-configuration.png`} alt={t('home.screenshot.alt')} /></div><figcaption><img src={`${import.meta.env.BASE_URL}key-recorder-icon.png`} alt="" /><span>{t('home.screenshot.caption')}</span></figcaption></figure></section>
    <section className="statement-band"><div className="section-shell band-inner"><p>{t('home.statement')}</p><span className="band-arrow">↓</span></div></section>
    <section className="section-shell feature-section"><div className="section-heading"><p className="eyebrow"><span className="eyebrow-line" />{t('home.featuresEyebrow')}</p><h2>{t('home.featuresTitle')}</h2></div><div className="feature-grid">{features.map((feature, index) => <article className="feature-card" key={feature.title}><div className={`feature-number feature-number-${index + 1}`}>0{index + 1}</div><h3>{feature.title}</h3><p>{feature.body}</p></article>)}</div></section>
    <section className="section-shell observation-section"><div className="observation-copy"><p className="eyebrow"><span className="eyebrow-line" />{t('home.example.eyebrow')}</p><h2>{t('home.example.title')}</h2><p>{t('home.example.body')}</p><Link className="text-link" to={`/${locale}/researchers/`}>{t('home.example.link')} <span>↗</span></Link></div><div className="observation-sheet"><div className="sheet-label">PROTOCOL / 2026–A</div><div className="sheet-rule" /><div className="sheet-row sheet-head"><span>{t('home.example.csv.interval')}</span><span>FOOD DISPENSER</span><span>LEVER</span></div><div className="sheet-row"><span>0s – 30s</span><span className="measure-coral">12.450</span><span className="measure-blue">4.200</span></div><div className="sheet-row"><span>30s – 60s</span><span className="measure-coral">8.100</span><span className="measure-blue">10.000</span></div><div className="sheet-rule" /><div className="sheet-row sheet-total"><span>TOTAL</span><span>20.550</span><span>14.200</span></div><p className="sheet-caption">{t('home.example.caption')}</p></div></section>
    <section className="download-band"><div className="section-shell download-inner"><div><p className="eyebrow eyebrow-light"><span className="eyebrow-line" />{t('home.download.eyebrow')}</p><h2>{t('home.download.title')}</h2></div><a className="button button-light" href={releaseUrl} target="_blank" rel="noreferrer">{t('home.download.cta')} <span>↗</span></a></div></section>
  </>
}

function InformationPage({ locale, page }: { locale: Locale; page: 'researchers' | 'privacy' | 'download' }) {
  const { t } = useTranslation()
  const sections = page === 'researchers' ? ['prepare', 'record', 'read'] : page === 'privacy' ? ['local', 'permissions', 'limits'] : ['requirements', 'install', 'release']
  return <section className="section-shell info-page"><p className="eyebrow"><span className="eyebrow-line" />{t(`${page}.eyebrow`)}</p><h1>{t(`${page}.title`)}</h1><p className="info-lead">{t(`${page}.intro`)}</p><div className="info-list">{sections.map((section, index) => <article key={section} className="info-item"><div className="info-index">0{index + 1}</div><div><h2>{t(`${page}.${section}.title`)}</h2><p>{t(`${page}.${section}.body`)}</p>{page === 'download' && section === 'release' && <a className="text-link" href={releaseUrl} target="_blank" rel="noreferrer">{t('download.release.link')} ↗</a>}</div></article>)}</div><Link className="button button-dark info-button" to={`/${locale}/`}>{t('common.backHome')}</Link></section>
}

function LanguageLanding() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  return <main className="language-landing"><div className="landing-card"><img className="brand-mark" src={`${import.meta.env.BASE_URL}key-recorder-icon.png`} alt="" /><p className="eyebrow">KEY RECORDER / SELECT LANGUAGE</p><h1>{t('landing.title')}</h1><div className="landing-options">{locales.map((locale) => <button key={locale} type="button" onClick={() => navigate(`/${locale}/`)}><span>{locale === 'en' ? 'English' : locale === 'fr' ? 'Français' : 'Italiano'}</span><span>↗</span></button>)}</div></div></main>
}

function LocalizedSite() {
  const locale = useSiteMeta()
  return <><Header locale={locale} /><main><Routes><Route path="/" element={<HomePage locale={locale} />} /><Route path="/researchers/" element={<InformationPage locale={locale} page="researchers" />} /><Route path="/privacy/" element={<InformationPage locale={locale} page="privacy" />} /><Route path="/download/" element={<InformationPage locale={locale} page="download" />} /><Route path="*" element={<HomePage locale={locale} />} /></Routes></main><Footer locale={locale} /></>
}

export default function App() {
  return <Routes><Route path="/" element={<LanguageLanding />} /><Route path="/:locale/*" element={<LocalizedSite />} /></Routes>
}
