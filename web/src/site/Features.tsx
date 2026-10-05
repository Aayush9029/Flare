import { motion, useInView } from "motion/react"
import { useEffect, useRef, useState } from "react"

import { cn } from "@/lib/utils"
import { APP, type Clip, type Cue } from "./data"
import { VideoWindow } from "./Window"

type Feature = {
  you: string
  flare: string
  title: string
  body: string
  clip: Clip & { cues: Cue[] }
}

const FEATURES: Feature[] = [
  {
    you: "what's 250 USD in CAD right now?",
    flare: "C$352.45. I checked a live rate.",
    title: "Looks it up when it has to",
    body: "Flare searches the web on its own when a question needs today's facts, and links every source.",
    clip: APP.websearch,
  },
  {
    you: "walk me through a proper mushroom risotto",
    flare: "on it. ingredients first.",
    title: "Answers you can scan",
    body: "Tables, steps, and code blocks stream in as clean text, so the answer is easy to read at a glance.",
    clip: APP.risotto,
  },
  {
    you: "draw a tiny isometric desk",
    flare: "here you go",
    title: "Ask for a picture",
    body: "Describe it and Flare draws it in the chat. Every image stays on your Mac.",
    clip: APP.image,
  },
  {
    you: "now compare WireGuard and OpenVPN",
    flare: "queued. sending when I finish.",
    title: "Type the next question now",
    body: "Keep typing while Flare answers. Your next question goes out the moment the reply lands.",
    clip: APP.queue,
  },
  {
    you: "what did it say about Kyoto?",
    flare: "found it: Best Time to Visit Kyoto",
    title: "Find any chat with ⌘K",
    body: "Search every message you have sent or received. Results appear as you type.",
    clip: APP.search,
  },
]

function Bubble({ tone, children, delay }: { tone: "you" | "flare"; children: string; delay: number }) {
  const ref = useRef<HTMLDivElement>(null)
  const inView = useInView(ref, { once: true, margin: "-120px" })
  const [typing, setTyping] = useState(tone === "flare")

  useEffect(() => {
    if (!inView || tone !== "flare") return
    const id = window.setTimeout(() => setTyping(false), (delay + 1.1) * 1000)
    return () => window.clearTimeout(id)
  }, [inView, tone, delay])

  return (
    <div ref={ref}>
      <motion.div
        layout
        initial={{ opacity: 0, scale: 0.85, y: 8 }}
        animate={inView ? { opacity: 1, scale: 1, y: 0 } : undefined}
        transition={{ type: "spring", stiffness: 380, damping: 26, delay, layout: { type: "spring", stiffness: 420, damping: 32 } }}
        className={cn(
          "relative w-fit max-w-[19rem] rounded-[22px] px-5 py-3 text-[20px] leading-snug text-ink",
          tone === "you" ? "bubble-you origin-bottom-left rounded-bl-md" : "bubble-flare origin-top-left rounded-tl-md",
        )}
      >
        {typing ? (
          <span className="flex h-[1.375em] items-center gap-1.5" aria-label="Flare is typing">
            {[0, 1, 2].map((dot) => (
              <span key={dot} style={{ animationDelay: `${dot * 0.15}s` }} className="typing-dot size-2 rounded-full bg-ink/60" />
            ))}
          </span>
        ) : (
          <motion.span initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ duration: 0.25 }} className="block">
            {children}
          </motion.span>
        )}
      </motion.div>
    </div>
  )
}

export function Features() {
  return (
    <section id="features" className="desk-dots px-6 pb-24">
      <div className="mx-auto flex max-w-6xl flex-col gap-28 sm:gap-36">
        {FEATURES.map((feature, i) => (
          <article
            key={feature.title}
            className={cn(
              "grid items-center gap-10 lg:grid-cols-[5fr_7fr] lg:gap-16",
              i % 2 === 1 && "lg:grid-cols-[7fr_5fr]",
            )}
          >
            <div className={cn("flex flex-col", i % 2 === 1 && "lg:order-2")}>
              <div className="flex flex-col gap-3">
                <Bubble tone="you" delay={0}>{feature.you}</Bubble>
                <Bubble tone="flare" delay={0.35}>{feature.flare}</Bubble>
              </div>
              <h2 className="mt-10 text-[28px] leading-tight font-semibold tracking-[-0.02em]">{feature.title}</h2>
              <p className="mt-3 max-w-[26rem] text-[18px] leading-relaxed text-quiet">{feature.body}</p>
            </div>
            <VideoWindow clip={feature.clip} cues={feature.clip.cues} className={cn(i % 2 === 1 && "lg:order-1")} />
          </article>
        ))}
      </div>
    </section>
  )
}
