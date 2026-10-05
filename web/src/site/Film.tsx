import { Play, Volume2, VolumeX } from "lucide-react"
import { useEffect, useRef, useState } from "react"

import type { Clip } from "./data"
import { Window } from "./Window"

export function Film({ clip, className }: { clip: Clip; className?: string }) {
  const video = useRef<HTMLVideoElement>(null)
  const [started, setStarted] = useState(false)
  const [muted, setMuted] = useState(true)

  useEffect(() => {
    const element = video.current
    if (!element) return
    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) element.play().catch(() => {})
      else element.pause()
    })
    observer.observe(element)
    return () => observer.disconnect()
  }, [])

  const playWithSound = () => {
    const element = video.current
    if (!element) return
    element.currentTime = 0
    element.muted = false
    setStarted(true)
    setMuted(false)
    element.play().catch(() => {})
  }

  const toggleSound = () => {
    const element = video.current
    if (!element) return
    element.muted = !element.muted
    setMuted(element.muted)
  }

  return (
    <Window title={clip.title} className={className}>
      <div className="relative aspect-video bg-black">
        <video
          ref={video}
          src={clip.src}
          poster={clip.poster}
          muted
          loop
          playsInline
          preload="metadata"
          className="size-full object-cover"
        />
        {started ? (
          <button
            type="button"
            onClick={toggleSound}
            aria-label={muted ? "Unmute" : "Mute"}
            className="absolute right-4 bottom-4 flex size-10 items-center justify-center rounded-full bg-black/40 text-white backdrop-blur-md transition-colors hover:bg-black/60"
          >
            {muted ? <VolumeX className="size-4" /> : <Volume2 className="size-4" />}
          </button>
        ) : (
          <button
            type="button"
            onClick={playWithSound}
            className="absolute bottom-4 left-1/2 flex -translate-x-1/2 items-center gap-2 rounded-full bg-white/85 py-2 pr-4 pl-3.5 text-[14px] font-medium text-ink shadow-lg backdrop-blur-md transition-transform hover:scale-[1.03] active:scale-[0.98] sm:bottom-6 sm:py-2.5 sm:pr-5 sm:pl-4 sm:text-[15px]"
          >
            <Play className="size-4 fill-current" />
            Play with sound
          </button>
        )}
      </div>
    </Window>
  )
}
