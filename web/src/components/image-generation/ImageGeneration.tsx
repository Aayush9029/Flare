import { useEffect, useMemo, useRef, useState, type CSSProperties, type ReactNode } from "react"

import { cn } from "@/lib/utils"

import { createEngine, supportsWebGL2, type Engine } from "./engine"
import { PRESETS, type PresetMode, type PresetName } from "./presets"

export type ImageGenerationProps = {
  images: string[]
  preset?: PresetName
  theme?: "dark" | "light"
  /** Overrides the preset's 5 palette hexes, e.g. to tint the mosaic. */
  colors?: readonly string[]
  /** Card colour the mosaic fades against. Defaults to the preset value. */
  cardBg?: string
  /** Controlled reveal. Leave undefined to drive the cycle with `autoReveal`. */
  reveal?: boolean
  autoReveal?: boolean
  /** Seconds the shader churns before each auto reveal. */
  idleSeconds?: number
  /** Seconds an auto-revealed image stays up before it dissolves back. */
  holdSeconds?: number
  alt?: string
  className?: string
  style?: CSSProperties
  children?: ReactNode
}

function prefersReducedMotion(): boolean {
  if (typeof window === "undefined") return false
  return window.matchMedia?.("(prefers-reduced-motion: reduce)").matches ?? false
}

export function ImageGeneration({
  images,
  preset = "pixels-organic",
  theme = "dark",
  colors,
  cardBg,
  reveal,
  autoReveal = false,
  idleSeconds = 1.4,
  holdSeconds = 3.2,
  alt = "",
  className,
  style,
  children,
}: ImageGenerationProps) {
  const hostRef = useRef<HTMLDivElement>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const engineRef = useRef<Engine | null>(null)

  const [fallback, setFallback] = useState(() => prefersReducedMotion() || !supportsWebGL2())
  const [settled, setSettled] = useState(false)
  const [index, setIndex] = useState(0)
  const [autoRevealed, setAutoRevealed] = useState(false)

  const src = images[index] ?? images[0] ?? ""
  const base = PRESETS[preset][theme]
  const paletteKey = colors?.join(",") ?? ""
  const mode = useMemo<PresetMode>(() => {
    if (!paletteKey && !cardBg) return base
    const next = paletteKey ? (paletteKey.split(",") as PresetMode["colors"]) : base.colors
    return { ...base, colors: next, cardBg: cardBg ?? base.cardBg }
  }, [base, paletteKey, cardBg])

  useEffect(() => {
    if (fallback) return
    const canvas = canvasRef.current
    const host = hostRef.current
    if (!canvas || !host) return

    const engine = createEngine({ canvas, preset: mode, image: src, onSettle: setSettled })
    if (!engine) {
      setFallback(true)
      return
    }
    engineRef.current = engine

    const resizeObserver = new ResizeObserver(() => engine.resize())
    resizeObserver.observe(host)

    const intersectionObserver = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) engine.setVisible(entry.isIntersecting && !document.hidden)
      },
      { rootMargin: "128px" },
    )
    intersectionObserver.observe(host)

    const onVisibility = () => engine.setVisible(!document.hidden)
    document.addEventListener("visibilitychange", onVisibility)

    return () => {
      resizeObserver.disconnect()
      intersectionObserver.disconnect()
      document.removeEventListener("visibilitychange", onVisibility)
      engine.dispose()
      engineRef.current = null
    }
    // `mode` is stable per preset/theme pair.
  }, [fallback, mode])

  useEffect(() => {
    engineRef.current?.setImage(src)
  }, [src])

  const revealed = reveal ?? autoRevealed

  useEffect(() => {
    engineRef.current?.setReveal(revealed)
  }, [revealed])

  useEffect(() => {
    if (!autoReveal || reveal !== undefined) return
    const revealMs = mode.reveal.duration * 1000
    let timer = 0
    const step = (on: boolean) => {
      setAutoRevealed(on)
      if (on) {
        timer = window.setTimeout(() => step(false), revealMs + holdSeconds * 1000)
      } else {
        timer = window.setTimeout(() => {
          if (images.length > 1) setIndex((current) => (current + 1) % images.length)
          step(true)
        }, idleSeconds * 1000)
      }
    }
    timer = window.setTimeout(() => step(true), idleSeconds * 1000)
    return () => window.clearTimeout(timer)
  }, [autoReveal, reveal, images.length, idleSeconds, holdSeconds, mode.reveal.duration])

  const showImage = fallback ? revealed : settled

  return (
    <div
      ref={hostRef}
      className={cn("relative overflow-hidden", className)}
      style={style}
      role={alt ? "img" : undefined}
      aria-label={alt || undefined}
    >
      {children}
      {src && (
        <img
          src={src}
          alt=""
          aria-hidden
          draggable={false}
          className={cn("absolute inset-0 size-full object-cover", fallback && "transition-opacity duration-500")}
          style={{ opacity: showImage ? 1 : 0 }}
        />
      )}
      {!fallback && (
        <canvas
          ref={canvasRef}
          aria-hidden
          className="absolute inset-0 size-full"
          style={{ opacity: showImage ? 0 : 1 }}
        />
      )}
    </div>
  )
}

export default ImageGeneration
