import { ArrowRight, ArrowUpRight, Shield, Smartphone, Sticker, Waves } from "lucide-react";

const principles = [
  {
    label: "Native enforcement",
    copy: "Uses Apple Screen Time shielding and Managed Settings instead of fake overlays or launch-detours.",
  },
  {
    label: "One anchor",
    copy: "Any cheap NFC sticker can become the paired release object. The app stores only its local fingerprint.",
  },
  {
    label: "No backend",
    copy: "No account, no sync, and no remote dependency in v1. The friction loop stays entirely on-device.",
  },
];

const unlockSteps = [
  {
    title: "Pick the blocked set",
    copy: "Turn your reflex apps and sites into one named mode.",
    icon: Shield,
  },
  {
    title: "Pair the sticker once",
    copy: "Scan a cheap NTAG sticker and bind its fingerprint to that mode.",
    icon: Sticker,
  },
  {
    title: "Walk to the release",
    copy: "To get the apps back, you need the phone, the app, and the paired anchor in the same place.",
    icon: Smartphone,
  },
];

const scanFacts = [
  "Scanning reads the sticker UID exposed by iPhone NFC APIs.",
  "Ancla hashes that identifier locally and compares it with the paired record.",
  "If it matches, the active shield clears. If it does not, nothing unlocks.",
];

const betaFacts = [
  "Other users can install through TestFlight as external testers.",
  "A public link can be opened to anyone after the first external build is approved.",
  "Apple allows up to 10,000 external testers per app.",
];

const stickerPicks = [
  {
    label: "Buy this one",
    note: "AliExpress NTAG213 standard adhesive sticker. Pick the 38 mm size if the listing offers it.",
    meta: "Default recommendation · standard adhesive",
    href: "https://s.click.aliexpress.com/e/_c3De6uih",
  },
  {
    label: "Amazon starter",
    note: "Standard NTAG213 sticker pack for most users. Use on plastic, paper, wood, or glass.",
    meta: "25 mm round · standard adhesive",
    href: "https://www.amazon.com/Stickers-Adhesive-Compatible-NFC-Enabled-Smartphones/dp/B07GFHLZD1",
  },
  {
    label: "AliExpress backup",
    note: "Smaller-pack fallback if you want a lighter first order instead of the default recommendation.",
    meta: "Backup recommendation · standard adhesive",
    href: "https://s.click.aliexpress.com/e/_c3SMBZ1j",
  },
  {
    label: "On-metal fallback",
    note: "Only buy this kind if the sticker will live on aluminum, steel, or another metal surface.",
    meta: "On-metal only · NTAG213",
    href: "https://s.click.aliexpress.com/e/_c3GSnHd7",
  },
];

function AnchorGlyph({ size = 42 }: { size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 128 128"
      fill="none"
      aria-hidden="true"
    >
      <circle cx="64" cy="19" r="9" stroke="currentColor" strokeWidth="8" />
      <path d="M64 28V88" stroke="currentColor" strokeWidth="8" strokeLinecap="round" />
      <path d="M40 50H88" stroke="currentColor" strokeWidth="8" strokeLinecap="round" />
      <path
        d="M28 78C28 98.9868 44.1177 116 64 116C83.8823 116 100 98.9868 100 78"
        stroke="currentColor"
        strokeWidth="8"
        strokeLinecap="round"
      />
      <path
        d="M28 78L14 64"
        stroke="currentColor"
        strokeWidth="8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M28 78L42 64"
        stroke="currentColor"
        strokeWidth="8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M100 78L86 64"
        stroke="currentColor"
        strokeWidth="8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M100 78L114 64"
        stroke="currentColor"
        strokeWidth="8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function AnchorMedallion() {
  return (
    <div className="float-mark relative flex h-20 w-20 items-center justify-center rounded-[2rem] border border-[var(--line)] bg-[rgba(255,255,255,0.94)] text-slate-900 shadow-[var(--shadow)]">
      <div className="absolute inset-2 rounded-[1.45rem] border border-[rgba(148,163,184,0.18)]" />
      <div className="relative">
        <AnchorGlyph />
      </div>
    </div>
  );
}

export default function Home() {
  return (
    <main className="noise min-h-[100dvh] overflow-hidden px-4 py-4 text-[var(--foreground)] md:px-6">
      <div className="mx-auto flex min-h-[calc(100dvh-2rem)] w-full max-w-[1440px] flex-col rounded-[2rem] border border-[var(--line)] bg-[var(--surface)] shadow-[var(--shadow)] backdrop-blur-xl">
        <header className="flex items-center justify-between gap-4 border-b border-[var(--line)] px-5 py-4 md:px-8">
          <div className="flex items-center gap-3">
            <AnchorMedallion />
            <div>
              <div className="text-[0.74rem] font-medium uppercase tracking-[0.26em] text-[var(--ink-muted)]">
                Ancla
              </div>
              <div className="text-sm text-[var(--ink-soft)]">
                Physical friction for iPhone app blocking
              </div>
            </div>
          </div>
          <a
            href="#waitlist"
            className="pressable inline-flex h-11 items-center justify-center rounded-full border border-[var(--line-strong)] bg-[var(--surface-strong)] px-5 text-sm font-medium text-slate-900"
          >
            Join the beta
          </a>
        </header>

        <section className="grid flex-1 grid-cols-1 gap-7 px-5 py-8 md:grid-cols-[minmax(0,1.06fr)_minmax(400px,0.94fr)] md:px-8 md:py-10">
          <div className="flex flex-col justify-between gap-10">
            <div className="space-y-7">
              <div className="rise-in inline-flex w-fit items-center gap-2 rounded-full border border-[var(--line)] bg-[rgba(248,250,252,0.92)] px-3 py-2 text-xs font-medium uppercase tracking-[0.22em] text-[var(--ink-muted)]">
                <Waves className="h-3.5 w-3.5" />
                Slate ritual
              </div>

              <div className="space-y-5">
                <h1
                  className="rise-in max-w-[10ch] text-[3.2rem] font-[620] leading-[0.9] tracking-[-0.078em] text-slate-950 md:text-[6.1rem]"
                  style={{ animationDelay: "70ms" }}
                >
                  Put distance between impulse and unlock.
                </h1>
                <p
                  className="rise-in max-w-[35rem] text-lg leading-8 text-[var(--ink-soft)] md:text-[1.14rem]"
                  style={{ animationDelay: "130ms" }}
                >
                  Ancla pairs Apple Screen Time shielding with one NFC sticker.
                  If you want Instagram, YouTube, or Safari back, you have to
                  stand up, find the anchor, and scan on purpose.
                </p>
              </div>

              <div
                className="rise-in flex flex-col gap-3 sm:flex-row"
                style={{ animationDelay: "200ms" }}
              >
                <a
                  id="waitlist"
                  href="mailto:contact@micr.dev?subject=Ancla%20beta"
                  className="pressable inline-flex h-13 items-center justify-center gap-2 rounded-full bg-slate-950 px-6 text-sm font-medium text-white"
                >
                  Request TestFlight access
                  <ArrowRight className="h-4 w-4" />
                </a>
                <a
                  href="#sticker-guide"
                  className="pressable inline-flex h-13 items-center justify-center rounded-full border border-[var(--line-strong)] px-6 text-sm font-medium text-slate-900"
                >
                  See sticker picks
                </a>
              </div>

              <div
                className="rise-in border-y border-[var(--line)] py-5"
                style={{ animationDelay: "260ms" }}
              >
                <div className="grid gap-5 md:grid-cols-[minmax(180px,0.36fr)_minmax(0,1fr)]">
                  <div className="flex flex-col gap-2">
                    <div className="text-[0.7rem] font-medium uppercase tracking-[0.2em] text-[var(--ink-muted)]">
                      Core rule
                    </div>
                    <p className="text-[1.25rem] leading-8 tracking-[-0.03em] text-slate-950">
                      The release path cannot live on the same glass surface as
                      the temptation.
                    </p>
                  </div>

                  <div className="divide-y divide-[var(--line)] border-l border-[var(--line)] pl-5">
                    {principles.map((principle) => (
                      <div key={principle.label} className="space-y-2 py-3 first:pt-0 last:pb-0">
                        <div className="text-[0.7rem] font-medium uppercase tracking-[0.2em] text-[var(--ink-muted)]">
                          {principle.label}
                        </div>
                        <p className="text-sm leading-7 text-[var(--ink-soft)]">{principle.copy}</p>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>

            <div className="rise-in space-y-4" style={{ animationDelay: "330ms" }}>
              <div className="text-xs font-medium uppercase tracking-[0.22em] text-[var(--ink-muted)]">
                Why this shape works
              </div>
              <p className="max-w-[36rem] text-base leading-7 text-[var(--ink-soft)]">
                Most blockers fail because the override stays one tap away.
                Ancla moves the exit condition into the room around you, so
                breaking focus costs movement and intent.
              </p>
              <div className="grid gap-3 border-t border-[var(--line)] pt-3 sm:grid-cols-3 sm:divide-x sm:divide-[var(--line)]">
                {scanFacts.map((fact, index) => (
                  <div key={fact} className="space-y-2 sm:px-3 sm:first:pl-0 sm:last:pr-0">
                    <div className="text-[0.68rem] font-medium uppercase tracking-[0.22em] text-[var(--ink-muted)]">
                      Scan {index + 1}
                    </div>
                    <p className="text-sm leading-6 text-[var(--ink-soft)]">{fact}</p>
                  </div>
                ))}
              </div>
            </div>
          </div>

          <div className="rise-in flex flex-col gap-4" style={{ animationDelay: "160ms" }}>
            <div className="overflow-hidden rounded-[2rem] border border-[var(--line)] bg-[rgba(255,255,255,0.7)] shadow-[var(--shadow)]">
              <div className="flex items-center justify-between border-b border-[var(--line)] px-5 py-4">
                <div>
                  <div className="text-xs font-medium uppercase tracking-[0.2em] text-[var(--ink-muted)]">
                    Active ritual
                  </div>
                  <div className="text-[1.7rem] font-medium tracking-[-0.04em] text-slate-950">
                    Work block
                  </div>
                </div>
                <div className="inline-flex items-center gap-2 rounded-full border border-[var(--line)] bg-white px-3 py-2 text-xs font-medium text-slate-700">
                  <span className="inline-flex h-2 w-2 rounded-full bg-emerald-500" />
                  Armed
                </div>
              </div>

              <div className="border-b border-[var(--line)] bg-slate-950 px-5 py-5 text-white">
                <div className="mb-2 text-xs font-medium uppercase tracking-[0.2em] text-slate-400">
                  Release condition
                </div>
                <p className="text-lg font-medium tracking-[-0.03em]">
                  The paired anchor has to be in the room.
                </p>
                <p className="mt-2 max-w-[29rem] text-sm leading-6 text-slate-300">
                  Wrong stickers do nothing. The unlock path stays local,
                  intentional, and physically annoying by design.
                </p>
              </div>

              <div className="grid gap-0 md:grid-cols-[minmax(0,0.92fr)_minmax(0,1.08fr)]">
                <div className="border-b border-[var(--line)] px-5 py-5 md:border-b-0 md:border-r">
                  <div className="mb-3 text-xs font-medium uppercase tracking-[0.2em] text-[var(--ink-muted)]">
                    Blocked set
                  </div>
                  <div className="text-lg font-medium tracking-[-0.03em] text-slate-950">
                    Social + video
                  </div>
                  <p className="mt-2 text-sm leading-6 text-[var(--ink-soft)]">
                    Instagram, X, YouTube, TikTok, Safari, and the usual drift
                    routes.
                  </p>
                </div>
                <div className="px-5 py-5">
                  <div className="mb-3 text-xs font-medium uppercase tracking-[0.2em] text-[var(--ink-muted)]">
                    Paired anchor
                  </div>
                  <div className="flex items-center gap-4">
                    <div className="relative flex h-16 w-16 items-center justify-center rounded-[1.25rem] border border-[var(--line)] bg-slate-50 text-slate-950">
                      <div className="absolute inset-[7px] rounded-[1rem] border border-[rgba(148,163,184,0.26)]" />
                      <AnchorGlyph size={28} />
                    </div>
                    <div>
                      <div className="text-base font-medium text-slate-950">NTAG sticker</div>
                      <p className="mt-1 text-sm leading-6 text-[var(--ink-soft)]">
                        One cheap sticker becomes the physical key for this
                        mode.
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              <div id="ritual" className="px-5 py-5">
                <div className="mb-4 flex items-center justify-between">
                  <div className="text-sm font-medium tracking-[-0.02em] text-slate-950">
                    Unlock sequence
                  </div>
                  <div className="text-[0.72rem] font-medium uppercase tracking-[0.22em] text-[var(--ink-muted)]">
                    3 steps
                  </div>
                </div>

                <div className="divide-y divide-[var(--line)] border-y border-[var(--line)]">
                  {unlockSteps.map((step, index) => {
                    const Icon = step.icon;

                    return (
                      <div key={step.title} className="flex items-start gap-4 py-4">
                        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-slate-100 text-slate-900">
                          <Icon className="h-4 w-4" />
                        </div>
                        <div className="min-w-0 flex-1">
                          <div className="mb-1 text-[0.68rem] font-medium uppercase tracking-[0.22em] text-[var(--ink-muted)]">
                            Step {index + 1}
                          </div>
                          <div className="text-sm font-medium text-slate-950">{step.title}</div>
                          <p className="mt-1 text-sm leading-6 text-[var(--ink-soft)]">{step.copy}</p>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>

            <div className="grid gap-6 border-t border-[var(--line)] px-1 pt-2 md:grid-cols-[0.82fr_1.18fr]">
              <div className="space-y-4 py-3">
                <div className="text-xs font-medium uppercase tracking-[0.22em] text-[var(--ink-muted)]">
                  TestFlight
                </div>
                <p className="max-w-[24rem] text-sm leading-6 text-[var(--ink-soft)]">
                  Other users can use Ancla through TestFlight once the first
                  external beta build clears Apple review.
                </p>
                <div className="space-y-3 border-y border-[var(--line)] py-3">
                  {betaFacts.map((fact, index) => (
                    <div key={fact} className="flex gap-3">
                      <div className="pt-0.5 text-[0.68rem] font-medium uppercase tracking-[0.22em] text-[var(--ink-muted)]">
                        0{index + 1}
                      </div>
                      <p className="text-sm leading-6 text-[var(--ink-soft)]">{fact}</p>
                    </div>
                  ))}
                </div>
                <a
                  href="https://developer.apple.com/testflight/"
                  target="_blank"
                  rel="noreferrer"
                  className="pressable inline-flex items-center gap-2 text-sm font-medium text-slate-900"
                >
                  Read Apple TestFlight docs
                  <ArrowUpRight className="h-4 w-4" />
                </a>
              </div>

              <div id="sticker-guide" className="space-y-4 py-3">
                <div className="text-xs font-medium uppercase tracking-[0.22em] text-[var(--ink-muted)]">
                  What to buy
                </div>
                <p className="max-w-[34rem] text-sm leading-6 text-[var(--ink-soft)]">
                  Buy a standard NTAG213 sticker. If you just want the answer:
                  use the AliExpress recommendation below and choose the 38 mm
                  version when it is available. Only buy on-metal tags if the
                  sticker will live on metal.
                </p>
                <div className="divide-y divide-[var(--line)] border-y border-[var(--line)]">
                  {stickerPicks.map((pick) => (
                    <a
                      key={pick.label}
                      href={pick.href}
                      target="_blank"
                      rel="noreferrer"
                      className="pressable flex items-start justify-between gap-4 py-4"
                    >
                      <div className="min-w-0 space-y-1">
                        <div className="text-sm font-medium text-slate-950">{pick.label}</div>
                        <p className="text-sm leading-6 text-[var(--ink-soft)]">{pick.note}</p>
                        <div className="text-[0.68rem] font-medium uppercase tracking-[0.22em] text-[var(--ink-muted)]">
                          {pick.meta}
                        </div>
                      </div>
                      <ArrowUpRight className="mt-1 h-4 w-4 shrink-0 text-slate-500" />
                    </a>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </section>
      </div>
    </main>
  );
}
