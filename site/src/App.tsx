import { Brand } from "./components/Brand";
import { MemoryScene } from "./components/MemoryScene";
import { PoeticScene } from "./components/PoeticScene";
import { Reveal } from "./components/Reveal";
import { downloadURL, repositoryURL } from "./release";

function Arrow() {
  return <span aria-hidden="true">↘</span>;
}

export function App() {
  return (
    <>
      <a className="skip-link" href="#main">Skip to content</a>

      <main id="main">
      <div className="hero-shell" id="top">
        <header className="site-header">
          <Brand />
          <nav aria-label="Primary navigation">
            <a href="#story">The idea</a>
            <a href="#memory">Memory</a>
            <a href="#privacy">Privacy</a>
            <a href="#install">Install</a>
          </nav>
          <a className="header-download" href={downloadURL}>
            Download <Arrow />
          </a>
        </header>

          <section className="hero" aria-labelledby="hero-title">
            <div className="hero__copy">
              <p className="eyebrow"><span /> Voice, with context</p>
              <h1 id="hero-title">
                Your words,<br />
                with their world <em>intact.</em>
              </h1>
              <p className="hero__lede">
                Hold ⌥ and talk while you work. When a thought needs the screen, draw a circle. Your words arrive with the moment still attached.
              </p>
              <div className="hero__actions">
                <a className="button button--primary" href={downloadURL}>
                  Download for Mac <Arrow />
                </a>
                <a className="button button--quiet" href="#story">Follow the thread</a>
              </div>
              <p className="release-note">macOS 14+ · Apple silicon · Free and open source</p>
            </div>

            <PoeticScene />
          </section>
      </div>

        <section className="aside-note" aria-label="Linefeed in one line">
          <span>One voice</span>
          <span>One gesture</span>
          <span>One complete thought</span>
        </section>

        <section className="story section" id="story" aria-labelledby="story-title">
          <Reveal className="story__statement">
            <p className="eyebrow eyebrow--center">The missing half of a sentence</p>
            <h2 id="story-title">
              Sometimes the shortest explanation is <em>“this thing, right here.”</em>
            </h2>
            <p>
              Linefeed lets your pointer finish the sentence. Speak as you normally would, circle the part of the screen you mean, and keep moving.
            </p>
          </Reveal>

          <div className="thought-path" aria-label="How Linefeed keeps speech and visual context together">
            <svg className="thought-path__thread" viewBox="0 0 1100 520" aria-hidden="true">
              <path d="M78 92C236 16 315 173 463 128C620 81 584 259 762 238C930 219 876 426 1030 426" />
            </svg>
            <Reveal className="thought thought--voice">
              <small>00:00</small>
              <span className="thought__orb"><i /><i /><i /><i /><i /></span>
              <h3>A voice begins.</h3>
              <p>No special commands. Just the thought as it comes.</p>
            </Reveal>
            <Reveal className="thought thought--gesture" delay={90}>
              <small>00:12</small>
              <span className="thought__circle">this</span>
              <h3>A circle gives it somewhere to land.</h3>
              <p>The screen becomes part of the sentence.</p>
            </Reveal>
            <Reveal className="thought thought--whole" delay={180}>
              <small>00:18</small>
              <span className="thought__return">↵</span>
              <h3>The thought arrives whole.</h3>
              <p>Words and the moment they describe, together.</p>
            </Reveal>
          </div>
        </section>

        <section className="memory section" id="memory" aria-labelledby="memory-title">
          <Reveal className="memory__copy">
            <p className="eyebrow">A memory for every moment</p>
            <h2 id="memory-title">Nothing loses its place.</h2>
            <p>
              A second screenshot belongs to a second part of the thought. Linefeed remembers the difference, even after the moment has passed.
            </p>
          </Reveal>
          <Reveal className="memory__visual" delay={100}>
            <MemoryScene />
          </Reveal>
        </section>

        <section className="privacy section" id="privacy" aria-labelledby="privacy-title">
          <Reveal className="privacy__lead">
            <span className="privacy__face" aria-hidden="true">•‿•</span>
            <p className="eyebrow eyebrow--light">Quiet by nature</p>
            <h2 id="privacy-title">What happens on your screen stays in the room.</h2>
            <p>Linefeed works locally, asks only for what it needs, and never turns your voice into someone else’s data.</p>
          </Reveal>

          <div className="privacy__details">
            <Reveal><span>01</span><strong>Voice stays on your Mac.</strong><p>Transcription runs locally. No account, no audio upload.</p></Reveal>
            <Reveal delay={70}><span>02</span><strong>You decide what is seen.</strong><p>A screenshot happens only when you draw the circle.</p></Reveal>
            <Reveal delay={140}><span>03</span><strong>Your history is yours.</strong><p>Revisit it, copy it, reveal it, or clear it whenever you like.</p></Reveal>
          </div>
        </section>

        <section className="install section" id="install" aria-labelledby="install-title">
          <Reveal className="install__intro">
            <p className="eyebrow">Installing the preview</p>
            <h2 id="install-title">One small pause.<br /><em>Then you’re in.</em></h2>
            <p>
              Linefeed is not yet notarized by Apple, so macOS may stop the first launch. You only need to allow it once.
            </p>
          </Reveal>

          <ol className="install__steps">
            <li>
              <Reveal className="install__step">
                <span className="install__number">01</span>
                <div>
                  <h3>Move Linefeed to Applications.</h3>
                  <p>Open the DMG, then drag Linefeed onto the Applications folder.</p>
                </div>
              </Reveal>
            </li>
            <li>
              <Reveal className="install__step" delay={70}>
                <span className="install__number">02</span>
                <div>
                  <h3>Try opening it once.</h3>
                  <p>Open Linefeed from Applications. When macOS pauses, close the message.</p>
                </div>
              </Reveal>
            </li>
            <li>
              <Reveal className="install__step" delay={140}>
                <span className="install__number">03</span>
                <div>
                  <h3>Choose Open Anyway.</h3>
                  <p>Go to System Settings → Privacy &amp; Security, scroll to Security, then choose Open Anyway and confirm.</p>
                </div>
              </Reveal>
            </li>
          </ol>

          <Reveal className="install__finish" delay={180}>
            <div className="install__setting" aria-hidden="true">
              <span>Privacy &amp; Security</span>
              <i />
              <strong>Open Anyway</strong>
            </div>
            <p>After that, Linefeed opens normally from Applications.</p>
            <a href="https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac" target="_blank" rel="noreferrer">
              View Apple’s guide <Arrow />
            </a>
          </Reveal>
        </section>

        <section className="finale section" aria-labelledby="download-title">
          <Reveal className="finale__card">
            <span className="finale__thread" aria-hidden="true" />
            <p className="eyebrow eyebrow--center">Linefeed for macOS</p>
            <h2 id="download-title">Leave less room for<br /><em>“which part?”</em></h2>
            <p>Download the preview. Setup will guide you through the rest.</p>
            <a className="button button--ink" href={downloadURL}>
              Download Linefeed <Arrow />
            </a>
            <small>Free and open source · Apple silicon</small>
          </Reveal>
        </section>
      </main>

      <footer className="site-footer">
        <Brand inverse />
        <p>Your words, with their world intact.</p>
        <nav aria-label="Footer links">
          {repositoryURL && <a href={repositoryURL}>Source</a>}
          <a href="#privacy">Privacy</a>
          <a href="#install">Install</a>
        </nav>
        <small>© {new Date().getFullYear()} Linefeed.</small>
      </footer>
    </>
  );
}
