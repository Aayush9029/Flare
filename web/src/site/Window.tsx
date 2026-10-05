import { AnimatePresence, motion } from "motion/react"
import { useEffect, useRef, useState, type ReactNode } from "react"

import { cn } from "@/lib/utils"
import type { Clip, Cue } from "./data"

const LIGHTS = [
  { color: "#ff5f57", glyph: "M3.5 3.5l5 5M8.5 3.5l-5 5" },
  { color: "#febc2e", glyph: "M3 6h6" },
  { color: "#28c840", glyph: "M6 3v6M3 6h6" },
]

export function TrafficLights({ className }: { className?: string }) {
  return (
    <div className={cn("flex items-center gap-[7px]", className)} aria-hidden>
      {LIGHTS.map(({ color, glyph }) => (
        <span key={color} style={{ background: color }} className="flex size-3 items-center justify-center rounded-full ring-[0.5px] ring-black/15">
          <svg viewBox="0 0 12 12" className="light-glyph size-2 stroke-black/55" strokeWidth={1.4} strokeLinecap="round" fill="none">
            <path d={glyph} />
          </svg>
        </span>
      ))}
    </div>
  )
}

export function Window({
  title,
  children,
  className,
  barClassName,
}: {
  title?: ReactNode
  children: ReactNode
  className?: string
  barClassName?: string
}) {
  return (
    <div className={cn("window flex flex-col overflow-hidden", className)}>
      <div className={cn("window-bar relative flex h-8 shrink-0 items-center px-3", barClassName)}>
        <TrafficLights />
        {title && (
          <span className="pointer-events-none absolute inset-x-16 truncate text-center text-[12px] font-medium text-black/45">
            {title}
          </span>
        )}
      </div>
      <div className="relative min-h-0 flex-1">{children}</div>
    </div>
  )
}

function useAutoplay() {
  const ref = useRef<HTMLVideoElement>(null)
  useEffect(() => {
    const video = ref.current
    if (!video) return
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) video.play().catch(() => {})
        else video.pause()
      },
      { rootMargin: "120px" },
    )
    observer.observe(video)
    return () => observer.disconnect()
  }, [])
  return ref
}

export function Video({ clip, className, cues, compact }: { clip: Clip; className?: string; cues?: Cue[]; compact?: boolean }) {
  const ref = useAutoplay()
  return (
    <>
      <video
        ref={ref}
        src={clip.src}
        poster={clip.poster}
        muted
        loop
        playsInline
        preload="none"
        aria-label={clip.title}
        className={cn("size-full object-cover", className)}
      />
      {cues && <CueOverlay video={ref} cues={cues} compact={compact} />}
    </>
  )
}

function CueOverlay({ video, cues, compact }: { video: React.RefObject<HTMLVideoElement | null>; cues: Cue[]; compact?: boolean }) {
  const [active, setActive] = useState<number | null>(null)

  useEffect(() => {
    const element = video.current
    if (!element) return
    let frame = 0
    const tick = () => {
      const t = element.currentTime
      let index: number | null = null
      cues.forEach((cue, i) => {
        if (t >= cue.t - 0.05 && t < cue.t + 1.1) index = i
      })
      setActive(index)
      frame = requestAnimationFrame(tick)
    }
    const start = () => {
      cancelAnimationFrame(frame)
      frame = requestAnimationFrame(tick)
    }
    const stop = () => cancelAnimationFrame(frame)
    element.addEventListener("play", start)
    element.addEventListener("pause", stop)
    return () => {
      stop()
      element.removeEventListener("play", start)
      element.removeEventListener("pause", stop)
    }
  }, [video, cues])

  return (
    <div className={cn("pointer-events-none absolute inset-x-0 flex justify-center", compact ? "bottom-2.5 scale-75" : "bottom-5")} aria-hidden>
      <AnimatePresence mode="popLayout">
        {active !== null && (
          <motion.div
            key={active}
            initial={{ opacity: 0, y: 10, scale: 0.9 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -6, scale: 0.96, transition: { duration: 0.18 } }}
            transition={{ type: "spring", stiffness: 520, damping: 30 }}
            className="flex gap-1.5 rounded-[14px] bg-black/35 p-1.5 backdrop-blur-md"
          >
            {cues[active].keys.map((key, i) => (
              <motion.kbd
                key={key + i}
                initial={{ y: 0 }}
                animate={{ y: [0, 3, 0] }}
                transition={{ duration: 0.22, delay: i * 0.05 }}
                className={cn(
                  "keycap inline-flex h-10 min-w-10 items-center justify-center rounded-[10px] px-2.5 font-sans text-[17px] font-medium text-ink",
                  key.length > 2 && "px-4 text-[14px]",
                )}
              >
                {key}
              </motion.kbd>
            ))}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

export function VideoWindow({
  clip,
  cues,
  className,
  caption = true,
}: {
  clip: Clip
  cues?: Cue[]
  className?: string
  caption?: boolean
}) {
  return (
    <figure className={cn("flex flex-col items-center gap-2.5", className)}>
      <Window className="w-full">
        <div className="aspect-[4/3] w-full">
          <Video clip={clip} cues={cues} />
        </div>
      </Window>
      {caption && <figcaption className="text-[13px] text-quiet">{clip.title}</figcaption>}
    </figure>
  )
}
