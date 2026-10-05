import { Check } from "lucide-react"
import { motion } from "motion/react"
import type { CSSProperties } from "react"

import { AppleLogo } from "@/components/AppleLogo"
import { asset, BREW, DOWNLOAD, media, PROVIDERS, RELEASES, SOURCE } from "./data"
import { Window } from "./Window"
import { Wordmark } from "./Wordmark"

export function Models() {
  return (
    <section className="desk-dots px-6 py-28">
      <div className="mx-auto grid max-w-6xl items-center gap-14 lg:grid-cols-2">
        <div>
          <h2 className="max-w-md text-balance text-[40px] leading-[1.05] font-semibold tracking-[-0.03em] sm:text-[52px]">
            Bring the AI you already pay for
          </h2>
          <p className="mt-4 max-w-md text-[18px] leading-relaxed text-quiet">
            Sign in with your ChatGPT account, paste an API key, or point Flare at Ollama or LM Studio and keep everything on your Mac.
          </p>
        </div>
        <Window title="Providers" className="mx-auto w-full max-w-lg">
          <div className="grid grid-cols-3 gap-x-2 gap-y-6 bg-white px-6 py-8 sm:grid-cols-5">
            {PROVIDERS.map((provider) => (
              <motion.div key={provider.id} whileHover={{ y: -3 }} className="flex flex-col items-center gap-2">
                <div className="flex size-14 items-center justify-center rounded-[14px] bg-desk ring-1 ring-black/[0.06]">
                  <img src={asset(`providers/${provider.id}.svg`)} alt="" className="size-7" />
                </div>
                <span className="text-[12px] text-black/70">{provider.name}</span>
              </motion.div>
            ))}
          </div>
        </Window>
      </div>
    </section>
  )
}

export function Note() {
  return (
    <section className="desk-dots relative px-6 py-24">
      <img
        src={media("stickers/shortcut.webp")}
        alt=""
        className="sticker-bob absolute top-6 left-[4%] z-10 hidden w-40 -rotate-6 drop-shadow-[0_8px_14px_rgba(30,21,53,0.25)] lg:block"
      />
      <img
        src={media("stickers/bolt.webp")}
        alt=""
        style={{ "--bob-delay": "-2s" } as CSSProperties}
        className="sticker-bob absolute right-[4%] bottom-6 z-10 hidden w-20 rotate-12 drop-shadow-[0_8px_14px_rgba(30,21,53,0.25)] lg:block"
      />
      <div className="relative mx-auto max-w-3xl">
        <Window
          title="Notes"
          barClassName="bg-[linear-gradient(#f7eeb5,#efe39a)] border-b-[#d9c96a]"
        >
          <div className="bg-white px-7 py-8 text-[20px] leading-[1.6] text-black/70 sm:px-10 sm:text-[21px]">
            <p>We ask AI small things all day. Each time it costs a new tab, a sign-in, and the thought we were holding.</p>
            <p className="mt-5">
              Flare is one shortcut away in every app. <span className="marker text-ink">Ask, read the answer, and you're back to work.</span>
            </p>
            <p className="mt-5">Every chat is saved on your Mac, not on our servers. There is no account to make.</p>
          </div>
        </Window>
      </div>
    </section>
  )
}

const INCLUDED = ["Every feature, on every Mac", "No trial, no license key", "Chats stored on your Mac", "Works with your own AI account"]

export function OpenSource() {
  return (
    <section id="open-source" className="desk-dots px-6 pt-10 pb-32">
      <div className="mx-auto flex max-w-md flex-col items-center text-center">
        <img src={asset("icon.png")} alt="" className="size-20 drop-shadow-[0_12px_20px_rgba(30,21,53,0.3)]" />
        <h2 className="mt-6 text-[40px] leading-[1.05] font-semibold tracking-[-0.03em] sm:text-[52px]">Free and open source</h2>
        <p className="mt-3 text-[18px] text-quiet">MIT licensed. Download the signed app, or read the code and build it yourself.</p>
        <ul className="mt-8 flex flex-col gap-2.5 text-left text-[17px]">
          {INCLUDED.map((line, i) => (
            <li key={line} className="flex items-center gap-3">
              <motion.span
                initial={{ scale: 0, rotate: -40 }}
                whileInView={{ scale: 1, rotate: 0 }}
                viewport={{ once: true, margin: "-60px" }}
                transition={{ type: "spring", stiffness: 500, damping: 16, delay: 0.1 + i * 0.12 }}
                className="flex size-5 items-center justify-center rounded-full bg-violet text-white"
              >
                <Check className="size-3" strokeWidth={3} />
              </motion.span>
              {line}
            </li>
          ))}
        </ul>
        <div className="mt-10 flex flex-wrap items-center justify-center gap-3">
          <a href={DOWNLOAD} className="pill-violet hop-on-hover inline-flex h-12 items-center gap-2 rounded-full px-6 text-[17px] font-medium text-white">
            <AppleLogo className="hop size-4 -translate-y-px" />
            Download for Mac
          </a>
          <a href={SOURCE} className="pill-white inline-flex h-12 items-center rounded-full px-6 text-[17px] font-medium">
            View on GitHub
          </a>
        </div>
        <code className="mt-5 rounded-full bg-black/[0.05] px-4 py-1.5 font-mono text-[13px] text-ink select-all">{BREW}</code>
        <p className="mt-4 text-[14px] text-quiet">Requires macOS 26 or later.</p>
      </div>
    </section>
  )
}

export function Footer() {
  return (
    <footer className="overflow-hidden border-t border-black/[0.07] bg-desk">
      <div className="mx-auto grid max-w-6xl gap-10 px-6 pt-14 text-[14px] sm:grid-cols-[2fr_1fr_1fr]">
        <div>
          <p className="font-semibold">Flare by Optimal Apps</p>
          <p className="mt-2 max-w-xs text-quiet">
            The people in our clips are AI generated. Every Flare screen you see is a real screen recording of the app.
          </p>
        </div>
        <div className="flex flex-col gap-2">
          <p className="font-semibold">Product</p>
          <a href="#features" className="text-quiet hover:text-ink">Features</a>
          <a href="#shortcuts" className="text-quiet hover:text-ink">Shortcuts</a>
          <a href="#open-source" className="text-quiet hover:text-ink">Open source</a>
        </div>
        <div className="flex flex-col gap-2">
          <p className="font-semibold">Get it</p>
          <a href={DOWNLOAD} className="text-quiet hover:text-ink">Download</a>
          <a href={SOURCE} className="text-quiet hover:text-ink">Source code</a>
          <a href={RELEASES} className="text-quiet hover:text-ink">Changelog</a>
        </div>
      </div>
      <p aria-hidden className="mt-10 -mb-[0.2em] text-center text-[clamp(120px,30vw,420px)] leading-[0.8] tracking-[-0.06em] text-black/[0.06] select-none">
        <Wordmark entrance={false} />
      </p>
    </footer>
  )
}
