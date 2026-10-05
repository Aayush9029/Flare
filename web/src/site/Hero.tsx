import { motion } from "motion/react"
import { useState, type CSSProperties, type ReactNode } from "react"

import { AppleLogo } from "@/components/AppleLogo"
import { APP, CLIPS, DOWNLOAD, media, SOURCE, type Clip, type Cue } from "./data"
import { Video, Window } from "./Window"
import { Wordmark } from "./Wordmark"

type Item =
  | { kind: "clip"; clip: Clip | (Clip & { cues: Cue[] }); aspect: string; width: number; style: CSSProperties; rotate?: number }
  | { kind: "sticker"; name: string; alt: string; width: number; style: CSSProperties; rotate?: number }

const ITEMS: Item[] = [
  { kind: "clip", clip: CLIPS.hello, aspect: "3/4", width: 190, style: { left: "4%", top: "17%" } },
  { kind: "clip", clip: APP.summon, aspect: "4/3", width: 260, style: { left: "calc(50% - 130px)", top: "5%" } },
  { kind: "clip", clip: CLIPS.kitchen, aspect: "16/10", width: 330, style: { right: "3.5%", top: "13%" } },
  { kind: "clip", clip: CLIPS.cafe, aspect: "16/10", width: 300, style: { left: "3%", bottom: "9%" } },
  { kind: "clip", clip: CLIPS.night, aspect: "3/4", width: 190, style: { right: "4%", bottom: "7%" } },
  { kind: "sticker", name: "hello", alt: "Hello, my name is flare sticker", width: 128, style: { left: "20%", top: "10%" }, rotate: -7 },
  { kind: "sticker", name: "globe", alt: "", width: 62, style: { right: "27%", top: "12%" } },
  { kind: "sticker", name: "bolt", alt: "", width: 76, style: { right: "25%", top: "33%" }, rotate: 12 },
  { kind: "sticker", name: "command", alt: "", width: 74, style: { left: "19%", top: "47%" }, rotate: -10 },
  { kind: "sticker", name: "notabs", alt: "No new tabs stamp", width: 150, style: { left: "25%", bottom: "7%" }, rotate: -6 },
  { kind: "sticker", name: "coffee", alt: "", width: 78, style: { right: "21%", bottom: "13%" }, rotate: 8 },
  { kind: "sticker", name: "mac", alt: "", width: 84, style: { right: "30%", bottom: "8%" }, rotate: -4 },
]

function Draggable({
  children,
  style,
  rotate = 0,
  index,
  onFront,
  z,
}: {
  children: ReactNode
  style: CSSProperties
  rotate?: number
  index: number
  onFront: () => void
  z: number
}) {
  return (
    <motion.div
      drag
      dragMomentum={false}
      onPointerDown={onFront}
      initial={{ opacity: 0, scale: 0.6, rotate: 0 }}
      animate={{ opacity: 1, scale: 1, rotate }}
      whileDrag={{ scale: 1.04, rotate: 0, cursor: "grabbing" }}
      transition={{ type: "spring", stiffness: 260, damping: 22, delay: 0.35 + index * 0.06 }}
      style={{ ...style, zIndex: z }}
      className="absolute cursor-grab touch-none select-none"
    >
      {children}
    </motion.div>
  )
}

export function Hero() {
  const [order, setOrder] = useState<number[]>(() => ITEMS.map((_, i) => i))
  const front = (i: number) => setOrder((current) => [...current.filter((n) => n !== i), i])

  return (
    <section id="top" className="desk-dots relative overflow-hidden pt-11">
      <div className="relative mx-auto max-w-[1600px] lg:min-h-[max(100svh,860px)]">
        <div aria-hidden className="absolute inset-0 hidden lg:block">
          {ITEMS.map((item, i) => (
            <Draggable key={i} index={i} style={item.style} rotate={item.rotate} z={order.indexOf(i) + 1} onFront={() => front(i)}>
              {item.kind === "clip" ? (
                <figure className="flex flex-col items-center gap-2" style={{ width: item.width }}>
                  <Window className="w-full">
                    <div style={{ aspectRatio: item.aspect }} className="pointer-events-none relative">
                      <Video clip={item.clip} cues={"cues" in item.clip ? item.clip.cues : undefined} compact />
                    </div>
                  </Window>
                  <figcaption className="text-[12px] text-quiet">{item.clip.title}</figcaption>
                </figure>
              ) : (
                <img
                  src={media(`stickers/${item.name}.webp`)}
                  alt={item.alt}
                  draggable={false}
                  style={{ width: item.width, "--bob": `${4.5 + (i % 3) * 0.8}s`, "--bob-delay": `${-i * 0.7}s` } as CSSProperties}
                  className="sticker-bob drop-shadow-[0_8px_14px_rgba(30,21,53,0.25)]"
                />
              )}
            </Draggable>
          ))}
        </div>

        <div className="pointer-events-none relative z-30 flex flex-col items-center justify-center px-6 pt-20 pb-12 text-center lg:min-h-[max(100svh,860px)] lg:pt-72 lg:pb-16">
          <motion.div
            initial={{ opacity: 0, y: 18 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
            className="pointer-events-auto flex flex-col items-center"
          >
            <h1 className="text-[clamp(88px,13vw,196px)] leading-[0.86] tracking-[-0.055em]">
              <Wordmark delay={0.15} />
            </h1>
            <p className="mt-5 max-w-md text-balance text-[21px] leading-snug text-black/75 sm:text-[25px]">
              AI that floats over every app on your Mac.
            </p>
            <div className="mt-8 flex flex-wrap items-center justify-center gap-3">
              <a href={DOWNLOAD} className="pill-violet hop-on-hover inline-flex h-12 items-center gap-2 rounded-full px-6 text-[17px] font-medium text-white">
                <AppleLogo className="hop size-4 -translate-y-px" />
                Download for Mac
              </a>
              <a href={SOURCE} className="pill-white inline-flex h-12 items-center rounded-full px-6 text-[17px] font-medium">
                View on GitHub
              </a>
            </div>
            <p className="mt-4 text-[14px] text-quiet">Free and open source. macOS 26 or later.</p>
          </motion.div>
        </div>

        <div className="no-scrollbar relative z-20 flex snap-x gap-4 overflow-x-auto px-6 pb-14 lg:hidden">
          {[APP.summon, CLIPS.hello, CLIPS.cafe, CLIPS.kitchen].map((clip) => (
            <figure key={clip.title} className="flex w-64 shrink-0 snap-center flex-col items-center gap-2">
              <Window className="w-full">
                <div className="aspect-[4/3]">
                  <Video clip={clip} />
                </div>
              </Window>
              <figcaption className="text-[12px] text-quiet">{clip.title}</figcaption>
            </figure>
          ))}
        </div>
      </div>
    </section>
  )
}
