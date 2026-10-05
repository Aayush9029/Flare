import {
  ArrowUp,
  ChevronLeft,
  ChevronRight,
  ChevronsUpDown,
  Copy,
  Download,
  Folder,
  Lock,
  PanelLeft,
  Plus,
  Search,
  Sparkles,
  SquarePen,
  Zap,
} from "lucide-react"
import { AnimatePresence, motion, useInView, useReducedMotion, type Variants } from "motion/react"
import { useEffect, useLayoutEffect, useRef, useState, type CSSProperties, type ReactNode } from "react"

import { AppleLogo } from "@/components/AppleLogo"
import { ImageGeneration } from "@/components/image-generation"
import { cn } from "@/lib/utils"

const base = import.meta.env.BASE_URL
const asset = (path: string) => `${base}assets/${path}`


const FEATURES = [
  { id: "answers", label: "Answers", title: "Answers worth reading", body: "Tables, steps, and clear answers, streamed in.", dwell: 8500 },
  { id: "search", label: "Search", title: "Find any chat in seconds", body: "Press Command K and search everything you've asked.", dwell: 9500 },
  { id: "images", label: "Images", title: "Ask for a picture", body: "Describe it. Flare draws it right in the chat.", dwell: 9000 },
] as const

type FeatureId = (typeof FEATURES)[number]["id"]

const ANSWERS_PROMPT = "Walk me through a proper mushroom risotto."

const RECIPE_ROWS = [
  ["Arborio rice", "180 g", "Do not rinse it"],
  ["Mixed mushrooms", "250 g", "Torn, not sliced"],
  ["Chicken stock", "900 ml", "Kept at a simmer"],
  ["Dry white wine", "80 ml", "Room temperature"],
  ["Shallot and garlic", "1 and 2 cloves", "Finely diced"],
  ["Butter and parmesan", "40 g each", "Cold, added last"],
] as const

const RECIPE_STEPS = [
  "Colour the mushrooms in a dry hot pan, then set them aside.",
  "Soften the shallot, add the rice, and toast it for two minutes.",
  "Pour in the wine and stir until the pan is almost dry.",
  "Add the stock a ladle at a time, then beat in the butter and parmesan off the heat.",
]

const SEARCHES = [
  {
    query: "trip",
    results: [
      { title: "Weekend in Lisbon", snippet: "Three days, mostly on foot, with a day trip to Sintra…", time: "2 hours ago" },
      { title: "Packing list for Japan in May", snippet: "Light layers, a compact umbrella, and cash for…", time: "Yesterday" },
      { title: "Road trip playlist ideas", snippet: "Upbeat for the morning, mellow after lunch…", time: "3 days ago" },
      { title: "Best time to visit Kyoto", snippet: "Late March for blossoms or November for…", time: "Last week" },
    ],
  },
  {
    query: "rent",
    results: [
      { title: "Lease renewal questions", snippet: "What to ask before signing another year…", time: "Today" },
      { title: "Split the deposit fairly", snippet: "Three tenants, one moved out in March…", time: "Monday" },
      { title: "Rent versus buy in Toronto", snippet: "Ran the numbers at 5.4% over seven years…", time: "2 weeks ago" },
    ],
  },
  {
    query: "swift",
    results: [
      { title: "Why does this actor deadlock", snippet: "The await inside the initialiser is the…", time: "Yesterday" },
      { title: "Sendable for a cache type", snippet: "Wrap the dictionary in an actor, or use…", time: "4 days ago" },
      { title: "SwiftUI list scroll jank", snippet: "The body reads the whole model, so every…", time: "Last month" },
    ],
  },
]

const ease = [0.22, 1, 0.36, 1] as const


const rise: Variants = {
  hidden: { opacity: 0, y: 8 },
  shown: { opacity: 1, y: 0, transition: { duration: 0.45, ease } },
}

const stagger = (gap: number, delay = 0): Variants => ({
  hidden: {},
  shown: { transition: { staggerChildren: gap, delayChildren: delay } },
})

function useSearchCycle(searches: typeof SEARCHES) {
  const [index, setIndex] = useState(0)
  const [text, setText] = useState("")
  const [shown, setShown] = useState(false)

  useEffect(() => {
    const { query } = searches[index]
    const timers: number[] = []
    let at = index === 0 ? 400 : 220
    const schedule = (delay: number, run: () => void) => {
      at += delay
      timers.push(window.setTimeout(run, at))
    }
    for (let i = 1; i <= query.length; i += 1) schedule(100, () => setText(query.slice(0, i)))
    schedule(280, () => setShown(true))
    schedule(1400, () => setShown(false))
    for (let i = query.length - 1; i >= 0; i -= 1) schedule(45, () => setText(query.slice(0, i)))
    schedule(220, () => setIndex((current) => (current + 1) % searches.length))
    return () => timers.forEach(window.clearTimeout)
  }, [index, searches])

  return { text, shown, results: searches[index].results }
}

function useDelayedFlag(ms: number) {
  const [flag, setFlag] = useState(false)
  useEffect(() => {
    const t = window.setTimeout(() => setFlag(true), ms)
    return () => window.clearTimeout(t)
  }, [ms])
  return flag
}

function WallpaperArt({ id }: { id: string }) {
  const blob = (name: string, color: string) => (
    <radialGradient id={`${id}-${name}`}>
      <stop offset="0" stopColor={color} />
      <stop offset="0.5" stopColor={color} stopOpacity="0.6" />
      <stop offset="1" stopColor={color} stopOpacity="0" />
    </radialGradient>
  )
  return (
    <>
      <defs>
        <linearGradient id={`${id}-base`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#e3e6fb" />
          <stop offset="0.5" stopColor="#ece4fa" />
          <stop offset="1" stopColor="#f6e4ee" />
        </linearGradient>
        {blob("violet", "#a598fb")}
        {blob("blue", "#8fb8fb")}
        {blob("pink", "#efa9d2")}
        {blob("coral", "#f4cdb6")}
        {blob("cyan", "#b4def5")}
        <filter id={`${id}-soft`} x="-10%" y="-10%" width="120%" height="120%">
          <feGaussianBlur stdDeviation="18" />
        </filter>
      </defs>
      <rect width="1600" height="1000" fill={`url(#${id}-base)`} />
      <ellipse cx="380" cy="300" rx="560" ry="440" fill={`url(#${id}-violet)`} />
      <ellipse cx="1260" cy="220" rx="520" ry="400" fill={`url(#${id}-blue)`} />
      <ellipse cx="1180" cy="840" rx="600" ry="440" fill={`url(#${id}-pink)`} />
      <ellipse cx="340" cy="900" rx="520" ry="380" fill={`url(#${id}-coral)`} />
      <ellipse cx="820" cy="540" rx="420" ry="320" fill={`url(#${id}-cyan)`} />
      <g fill="none" stroke="#fff" strokeLinecap="round" filter={`url(#${id}-soft)`}>
        <path d="M-100 720 C 260 480, 620 940, 1000 640 S 1500 320, 1750 520" strokeWidth="64" strokeOpacity="0.5" />
        <path d="M-100 860 C 320 700, 700 1040, 1120 760 S 1560 520, 1750 680" strokeWidth="22" strokeOpacity="0.45" />
        <path d="M-100 240 C 300 120, 560 420, 960 260 S 1460 60, 1750 220" strokeWidth="46" strokeOpacity="0.4" />
        <path d="M-100 560 C 360 420, 640 760, 1040 520 S 1480 300, 1750 420" strokeWidth="14" strokeOpacity="0.4" />
      </g>
    </>
  )
}

function Wallpaper({ id, className, style }: { id: string; className?: string; style?: CSSProperties }) {
  return (
    <svg aria-hidden className={className} style={style} viewBox="0 0 1600 1000" preserveAspectRatio="xMidYMid slice">
      <WallpaperArt id={id} />
    </svg>
  )
}

type Offset = { x: number; y: number; w: number; h: number; ww: number; wh: number }

function Refraction({ offset }: { offset: Offset }) {
  const { x, y, w, h, ww, wh } = offset
  if (!ww) return null
  const pad = 48
  return (
    <svg aria-hidden className="pointer-events-none absolute inset-0 size-full" viewBox={`0 0 ${ww} ${wh}`}>
      <defs>
        <filter
          id="glass"
          filterUnits="userSpaceOnUse"
          x={-pad}
          y={-pad}
          width={ww + pad * 2}
          height={wh + pad * 2}
          colorInterpolationFilters="sRGB"
        >
          <feGaussianBlur in="SourceGraphic" stdDeviation="9" result="blur" />
          <feTurbulence type="fractalNoise" baseFrequency="0.006 0.009" numOctaves="2" seed="9" result="noise" />
          <feGaussianBlur in="noise" stdDeviation="2" result="softNoise" />
          <feDisplacementMap in="blur" in2="softNoise" scale="36" xChannelSelector="R" yChannelSelector="G" result="warped" />
          <feSpecularLighting in="softNoise" surfaceScale="4" specularConstant="0.55" specularExponent="26" lightingColor="#fff" result="spec">
            <feDistantLight azimuth="225" elevation="60" />
          </feSpecularLighting>
          <feComposite in="spec" in2="warped" operator="in" result="specClip" />
          <feComposite in="specClip" in2="warped" operator="arithmetic" k2="0.6" k3="1" />
        </filter>
        <linearGradient id="glass-tint" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity="0.6" />
          <stop offset="0.45" stopColor="#fff" stopOpacity="0.3" />
          <stop offset="1" stopColor="#fff" stopOpacity="0.42" />
        </linearGradient>
        <linearGradient id="glass-rim" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity="1" />
          <stop offset="0.5" stopColor="#fff" stopOpacity="0.35" />
          <stop offset="1" stopColor="#fff" stopOpacity="0.85" />
        </linearGradient>
      </defs>
      <g filter="url(#glass)">
        <rect x={-pad} y={-pad} width={ww + pad * 2} height={wh + pad * 2} fill="#ece4fa" />
        <svg x={-x} y={-y} width={w} height={h} viewBox="0 0 1600 1000" preserveAspectRatio="xMidYMid slice">
          <WallpaperArt id="wp-glass" />
        </svg>
      </g>
      <rect width={ww} height={wh} fill="url(#glass-tint)" />
      <rect x="0.75" y="0.75" width={ww - 1.5} height={wh - 1.5} rx="23.25" fill="none" stroke="url(#glass-rim)" strokeWidth="1.5" />
      <rect x="2.5" y="2.5" width={ww - 5} height={wh - 5} rx="21.5" fill="none" stroke="#3b2a6b" strokeOpacity="0.06" strokeWidth="1" />
    </svg>
  )
}

function MenuBar() {
  const date = new Intl.DateTimeFormat("en-US", { weekday: "short", month: "short", day: "numeric" }).format(new Date())
  return (
    <div className="absolute inset-x-0 top-0 flex h-7 items-center justify-between bg-white/35 px-3 text-[11px] font-medium text-black/75 sm:px-4 sm:text-[12px]">
      <div className="flex items-center gap-3.5">
        <AppleLogo className="size-3" />
        <span className="font-semibold">Flare</span>
        <span className="hidden sm:inline">File</span>
        <span className="hidden sm:inline">Edit</span>
        <span className="hidden sm:inline">View</span>
        <span className="hidden sm:inline">Go</span>
        <span className="hidden sm:inline">Window</span>
        <span className="hidden sm:inline">Help</span>
      </div>
      <div className="flex items-center gap-3">
        <Zap className="size-3 fill-current" />
        <span className="hidden sm:inline">{date}</span>
        <span>9:41 AM</span>
      </div>
    </div>
  )
}

function You({ children }: { children: ReactNode }) {
  return (
    <div>
      <p className="text-xs text-muted-foreground">You</p>
      <p className="mt-1 text-[15px] leading-snug">{children}</p>
    </div>
  )
}

function FlareLine({ extra, icon }: { extra?: string; icon?: ReactNode }) {
  return (
    <p className="flex items-center gap-1.5 text-xs font-medium text-muted-foreground">
      <span className="flex items-center gap-1 text-primary">
        <Zap className="size-3 fill-current" />
        Flare
      </span>
      <span>·</span>
      <span className="flex items-center gap-1">
        <img src={asset("providers/openai.svg")} alt="" className="size-3 opacity-70" />
        OpenAI
      </span>
      {extra && (
        <>
          <span>·</span>
          <span className="flex items-center gap-1">
            {icon}
            {extra}
          </span>
        </>
      )}
    </p>
  )
}

function AnswersChat({ className }: { className?: string }) {
  return (
    <motion.div variants={stagger(0.34, 0.05)} initial="hidden" animate="shown" className={cn("flex flex-col gap-2.5", className)}>
      <motion.div variants={rise}>
        <You>{ANSWERS_PROMPT}</You>
      </motion.div>
      <motion.div variants={rise}>
        <FlareLine />
      </motion.div>
      <motion.p variants={rise} className="text-[15px] leading-snug">
        Thirty minutes of steady stirring, for two. Keep the stock hot in a second pan.
      </motion.p>
      <motion.table variants={rise} className="w-full border-separate border-spacing-0 overflow-hidden rounded-lg text-[13px] ring-1 ring-black/[0.08]">
        <thead>
          <tr className="bg-black/[0.04] text-left font-semibold text-black/80">
            <th className="px-2.5 py-1">Ingredient</th>
            <th className="px-2.5 py-1">Amount</th>
            <th className="px-2.5 py-1">Notes</th>
          </tr>
        </thead>
        <tbody className="text-black/75">
          {RECIPE_ROWS.map(([ingredient, amount, note]) => (
            <tr key={ingredient}>
              <td className="border-t border-black/[0.08] px-2.5 py-1">{ingredient}</td>
              <td className="border-t border-black/[0.08] px-2.5 py-1 whitespace-nowrap">{amount}</td>
              <td className="border-t border-black/[0.08] px-2.5 py-1 text-muted-foreground">{note}</td>
            </tr>
          ))}
        </tbody>
      </motion.table>
      <motion.ol variants={stagger(0.12)} className="list-decimal space-y-1 pl-5 text-[15px] leading-snug">
        {RECIPE_STEPS.map((step) => (
          <motion.li key={step} variants={rise}>
            {step}
          </motion.li>
        ))}
      </motion.ol>
    </motion.div>
  )
}

function AnswersDemo() {
  return (
    <div className="px-6 pb-6 pt-5">
      <AnswersChat />
    </div>
  )
}

function SearchDemo() {
  const { text, shown, results } = useSearchCycle(SEARCHES)
  return (
    <div className="relative">
      {/* Safari's GPU blur paints a magenta line across this layer; an SVG filter keeps the blur in software. */}
      <svg aria-hidden className="absolute size-0">
        <filter id="search-soft">
          <feGaussianBlur stdDeviation="1.5" />
        </filter>
      </svg>
      <div className="px-5 pb-6 pt-5 opacity-40 [filter:url(#search-soft)]">
        <AnswersChat />
      </div>
      <motion.div
        initial={{ opacity: 0, scale: 0.96, y: 6 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        transition={{ duration: 0.35, ease }}
        className="absolute inset-x-4 top-5 overflow-hidden rounded-2xl bg-white/90 ring-1 ring-black/[0.08] shadow-[0_24px_60px_-20px_rgba(20,10,60,0.4)] sm:inset-x-6 sm:top-6"
      >
        <div className="flex items-center gap-2.5 px-3.5 py-2.5 text-[14px]">
          <Search className="size-4 text-black/45" />
          <span className="text-black/85">
            {text}
            <span className="ml-px inline-block h-4 w-px translate-y-0.5 animate-pulse bg-[#2f7cf6]" />
          </span>
        </div>
        <AnimatePresence mode="wait">
          {shown && (
            <motion.ul
              key={text}
              variants={stagger(0.08)}
              initial="hidden"
              animate="shown"
              exit={{ opacity: 0, transition: { duration: 0.15 } }}
              className="border-t border-black/[0.06] p-1.5"
            >
              {results.map((result, index) => (
                <motion.li
                  key={result.title}
                  variants={rise}
                  className={cn(
                    "flex items-start justify-between gap-3 rounded-xl px-2.5 py-2",
                    index === 0 && "bg-black/[0.05]",
                  )}
                >
                  <div className="min-w-0">
                    <p className="truncate text-[13px] font-semibold text-black/85">{result.title}</p>
                    <p className="truncate text-[11px] text-black/50">{result.snippet}</p>
                  </div>
                  <span className="shrink-0 pt-0.5 text-[11px] text-black/40">{result.time}</span>
                </motion.li>
              ))}
            </motion.ul>
          )}
        </AnimatePresence>
      </motion.div>
    </div>
  )
}

const ART_MOSAIC = ["#0f0b18", "#4a4459", "#b3a8cf", "#0f0b18", "#d9cff2"]

function ArtCard({ src, alt, ready }: { src: string; alt: string; ready: boolean }) {
  return (
    <ImageGeneration
      images={[src]}
      preset="pixels-organic"
      theme="dark"
      colors={ART_MOSAIC}
      cardBg="#0d0a14"
      reveal={ready}
      alt={alt}
      className="aspect-square rounded-2xl bg-[#0d0a14] ring-1 ring-white/10"
    />
  )
}

function ImagesDemo() {
  const first = useDelayedFlag(3000)
  const second = useDelayedFlag(4200)
  const sparkle = (
    <motion.span
      animate={second ? { rotate: 0, scale: 1 } : { rotate: [0, 25, -15, 0], scale: [1, 1.3, 0.9, 1] }}
      transition={{ duration: 1.4, repeat: second ? 0 : Infinity, ease: "easeInOut" }}
      className="inline-flex"
    >
      <Sparkles className="size-3" />
    </motion.span>
  )
  return (
    <div className="px-6 pb-6 pt-5">
      <motion.div variants={stagger(0.22, 0.1)} initial="hidden" animate="shown" className="flex flex-col gap-3">
        <motion.div variants={rise}>
          <You>Two simple, modern NASA style pictures of a purple galaxy.</You>
        </motion.div>
        <motion.div variants={rise}>
          <FlareLine extra="Image" icon={sparkle} />
        </motion.div>
        <motion.div variants={rise} className="grid grid-cols-2 gap-2.5">
          <ArtCard src={asset("art-galaxy-1.webp")} alt="A purple spiral galaxy in deep space" ready={first} />
          <ArtCard src={asset("art-galaxy-2.webp")} alt="A glowing purple nebula" ready={second} />
        </motion.div>
        <AnimatePresence>
          {second && (
            <motion.div
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 1, duration: 0.4, ease }}
              className="flex gap-1.5"
            >
              {[
                { icon: Copy, label: "Copy" },
                { icon: Download, label: "Save" },
              ].map(({ icon: Icon, label }) => (
                <span
                  key={label}
                  className="inline-flex items-center gap-1 rounded-full bg-white/80 px-2.5 py-1 text-[11px] font-medium text-black/60 ring-1 ring-black/[0.06] transition-colors hover:bg-white hover:text-black/80"
                >
                  <Icon className="size-3" />
                  {label}
                </span>
              ))}
            </motion.div>
          )}
        </AnimatePresence>
      </motion.div>
    </div>
  )
}

function ChatInput({
  placeholder,
  action,
  className,
  typing,
}: {
  placeholder: string
  action: ReactNode
  className?: string
  typing?: boolean
}) {
  return (
    <div
      className={cn(
        "flex h-11 items-center gap-2 rounded-full bg-white/90 pl-4 pr-1.5 text-[14px] ring-1 ring-[#2f7cf6]/50 shadow-[0_0_0_4px_rgba(47,124,246,0.14)]",
        className,
      )}
    >
      <span className={cn("flex-1 truncate", typing ? "text-foreground" : "text-muted-foreground")}>
        {placeholder}
        {typing && <span className="ml-px inline-block h-4 w-px translate-y-0.5 animate-pulse rounded bg-[#2f7cf6]" />}
      </span>
      <span className="flex shrink-0 items-center gap-0.5 text-xs font-medium text-foreground/80">
        5.6 Sol
        <ChevronsUpDown className="size-3" />
      </span>
      <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-[#2f7cf6] text-white">
        {action}
      </span>
    </div>
  )
}

function IdleChat({ typed }: { typed: string }) {
  // Centred in the top of the window: the docked window is cut off at the
  // screen edge, so the block has to sit above that cut.
  return (
    <div className="flex h-[68%] flex-col items-center justify-center gap-5 px-6">
      <div className="flex flex-col items-center gap-2 text-center">
        <img src={asset("icon.png")} alt="" className="size-11 rounded-[12px] shadow-sm" />
        <p className="text-[16px] font-semibold tracking-tight">Flare</p>
        <p className="text-[13px] text-muted-foreground">Type to get started.</p>
      </div>
      <ChatInput
        className="w-full max-w-[26rem]"
        placeholder={typed || "Ask anything"}
        typing={typed.length > 0}
        action={<ArrowUp className="size-4" />}
      />
    </div>
  )
}

function FlareWindow({
  feature,
  offset,
  live,
  typed,
  sent,
}: {
  feature: FeatureId
  offset: Offset
  live: boolean
  typed: string
  sent: boolean
}) {
  return (
    <div className="relative h-full overflow-hidden rounded-[24px] shadow-[0_30px_80px_-20px_rgba(40,20,80,0.45)]">
      <Refraction offset={offset} />
      <div className="relative h-full">
        <AnimatePresence mode="wait" initial={false}>
          <motion.div
            className="h-full"
            key={live ? feature : sent ? "sending" : "idle"}
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -6 }}
            transition={{ duration: 0.22, ease }}
          >
            {!live && !sent && <IdleChat typed={typed} />}
            {live && feature === "answers" && <AnswersDemo />}
            {live && feature === "search" && <SearchDemo />}
            {live && feature === "images" && <ImagesDemo />}
          </motion.div>
        </AnimatePresence>
      </div>
    </div>
  )
}

function TrafficLights() {
  return (
    <span className="flex gap-[3px]">
      {["#ff5f57", "#febc2e", "#28c840"].map((color) => (
        <span key={color} className="size-[5px] rounded-full sm:size-1.5" style={{ backgroundColor: color }} />
      ))}
    </span>
  )
}

function AppWindow({ className, children }: { className?: string; children: ReactNode }) {
  return (
    <div
      className={cn(
        "absolute overflow-hidden rounded-[10px] ring-1 ring-black/[0.14] shadow-[0_26px_60px_-26px_rgba(20,10,60,0.6)]",
        className,
      )}
    >
      {children}
    </div>
  )
}

const SAFARI_NAV = ["Store", "Mac", "iPad", "iPhone", "Watch", "Vision", "AirPods", "Support"]

const SAFARI_CARDS = [
  { title: "M4 Pro", body: "Up to 24 hours of battery life." },
  { title: "Liquid Retina XDR", body: "1,600 nits of peak brightness." },
  { title: "Thunderbolt 5", body: "Three ports, up to 120Gb/s." },
]

function SafariWindow({ className }: { className?: string }) {
  return (
    <AppWindow className={cn("flex aspect-[4/3] flex-col", className)}>
      <div className="flex shrink-0 items-center gap-1.5 border-b border-black/[0.08] bg-[#f2f2f4]/95 px-2 py-1.5 backdrop-blur-md">
        <TrafficLights />
        <PanelLeft className="ml-1 size-2.5 text-black/35" />
        <ChevronLeft className="size-2.5 text-black/35" />
        <ChevronRight className="size-2.5 text-black/20" />
        <span className="mx-auto flex items-center gap-1 rounded bg-black/[0.07] px-8 py-[1px] text-[7px] leading-[12px] text-black/55">
          <Lock className="size-[7px]" />
          apple.com
        </span>
        <Plus className="size-2.5 text-black/35" />
      </div>
      <div className="flex flex-1 flex-col overflow-hidden bg-white">
        <div className="flex shrink-0 items-center gap-2.5 bg-[#f5f5f7] px-3 py-1 text-[7px] text-black/70">
          <AppleLogo className="size-[8px]" />
          {SAFARI_NAV.map((item) => (
            <span key={item}>{item}</span>
          ))}
          <Search className="ml-auto size-[7px] text-black/50" />
        </div>
        <div className="flex flex-1 flex-col items-center justify-center px-4 pt-3 text-center">
          <p className="text-[15px] font-semibold tracking-tight text-black/85">MacBook Pro</p>
          <p className="mt-0.5 text-[9px] font-medium text-black/60">Mind-blowing. Head-turning.</p>
          <p className="mt-1 text-[7px] text-[#0071e3]">Learn more &gt;&nbsp;&nbsp;&nbsp;&nbsp;Buy &gt;</p>
          <div className="mt-3 w-[58%]">
            <div className="rounded-t-[6px] bg-gradient-to-b from-[#35353c] to-[#1d1d21] p-[2px] pb-[3px]">
              <div className="aspect-[16/10] rounded-[4px] bg-gradient-to-br from-[#5b62d8] via-[#9a6fd0] to-[#e094b4]" />
            </div>
            <div className="mx-auto h-[4px] w-[110%] rounded-b-[4px] bg-gradient-to-b from-[#cbced5] to-[#a5a9b2]" />
          </div>
        </div>
        <div className="grid shrink-0 grid-cols-3 gap-2 p-3">
          {SAFARI_CARDS.map((card) => (
            <div key={card.title} className="rounded-md bg-[#f5f5f7] px-2 py-1.5">
              <p className="text-[7px] font-semibold text-black/75">{card.title}</p>
              <p className="mt-[1px] text-[6px] leading-[8px] text-black/45">{card.body}</p>
            </div>
          ))}
        </div>
      </div>
    </AppWindow>
  )
}

const NOTES_FOLDERS = [
  ["Notes", "23"],
  ["Trips", "6"],
  ["Work", "11"],
  ["Recipes", "4"],
]

const NOTES_LIST = [
  { title: "Montreal trip", preview: "Old Montreal, then the Plateau", time: "9:41 AM" },
  { title: "Groceries", preview: "Arborio rice, mushrooms, stock", time: "Yesterday" },
  { title: "Reading list", preview: "Two long essays, one novel", time: "Tuesday" },
  { title: "Studio lease", preview: "Ask about the renewal terms", time: "28 Aug" },
  { title: "Camera settings", preview: "Shutter 1/125, ISO 400", time: "21 Aug" },
  { title: "Gift ideas", preview: "Headphones, a good notebook", time: "14 Aug" },
  { title: "Bike service", preview: "New chain, brake pads, cables", time: "9 Aug" },
]

function NotesWindow({ className }: { className?: string }) {
  return (
    <AppWindow className={cn("flex aspect-[7/5] flex-col", className)}>
      <div className="flex shrink-0 items-center gap-1.5 border-b border-black/[0.08] bg-[#f2f2f4]/95 px-2 py-1.5 backdrop-blur-md">
        <TrafficLights />
        <span className="ml-auto flex items-center gap-2">
          <Search className="size-2.5 text-black/35" />
          <SquarePen className="size-2.5 text-[#d9a400]" />
        </span>
      </div>
      <div className="flex flex-1 overflow-hidden bg-white text-[7px] leading-[10px]">
        <div className="w-[23%] space-y-[3px] bg-[#f2f2f4]/85 p-2">
          <p className="px-1 text-[6px] font-semibold uppercase tracking-wide text-black/35">iCloud</p>
          {NOTES_FOLDERS.map(([name, count], index) => (
            <p
              key={name}
              className={cn(
                "flex items-center gap-1 rounded px-1 py-[3px]",
                index === 0 ? "bg-black/[0.07] text-black/70" : "text-black/45",
              )}
            >
              <Folder className="size-[7px] shrink-0 text-[#d9a400]" />
              <span className="truncate">{name}</span>
              <span className="ml-auto text-black/30">{count}</span>
            </p>
          ))}
        </div>
        <div className="w-[32%] border-x border-black/[0.07]">
          {NOTES_LIST.map((note, index) => (
            <div
              key={note.title}
              className={cn("px-2 py-[5px]", index === 0 ? "bg-[#ffd60a]/45" : "border-t border-black/[0.05]")}
            >
              <p className="truncate font-semibold text-black/75">{note.title}</p>
              <p className="truncate text-black/40">
                <span className="text-black/55">{note.time}</span> {note.preview}
              </p>
            </div>
          ))}
        </div>
        <div className="flex-1 space-y-1 p-2.5">
          <p className="text-center text-[6px] text-black/35">4 September 2026 at 9:41</p>
          <p className="text-[10px] font-semibold text-black/85">Montreal trip</p>
          <p className="text-black/60">Two days, mostly walking. Book the train by Friday.</p>
          <p className="text-black/45">Day one is Old Montreal, lunch near the market, then the Plateau in the afternoon.</p>
          <p className="text-black/45">Day two: Mount Royal early, bagels on the way back.</p>
          <span className="block h-[3px] w-full rounded-full bg-black/[0.07]" />
          <span className="block h-[3px] w-5/6 rounded-full bg-black/[0.07]" />
          <span className="block h-[3px] w-2/3 rounded-full bg-black/[0.07]" />
        </div>
      </div>
    </AppWindow>
  )
}

function Desktop({ hidden }: { hidden: boolean }) {
  return (
    <motion.div
      aria-hidden
      initial={false}
      animate={hidden ? { opacity: 0, scale: 0.99 } : { opacity: 1, scale: 1 }}
      transition={{ duration: 0.8, ease, delay: hidden ? 2.2 : 0 }}
      className="absolute inset-0"
    >
      <SafariWindow className="left-[4%] top-[9%] w-[50%]" />
      <NotesWindow className="right-[3%] top-[36%] w-[44%]" />
    </motion.div>
  )
}

function MacScreen({ feature, live }: { feature: FeatureId; live: boolean }) {
  const screenRef = useRef<HTMLDivElement>(null)
  const windowRef = useRef<HTMLDivElement>(null)
  const reduced = useReducedMotion()
  // Stricter than `live`: the entrance should play when the screen is actually
  // on screen, not when its first pixels cross the fold.
  const entered = useInView(screenRef, { amount: 0.45, once: true })
  const [opened, setOpened] = useState(false)
  const [ready, setReady] = useState(false)
  const [typed, setTyped] = useState("")
  const [sent, setSent] = useState(false)
  const [offset, setOffset] = useState<Offset>({ x: 0, y: 0, w: 0, h: 0, ww: 0, wh: 0 })

  // The intro reads as a real send: the prompt types into the field, goes off,
  // and only then does the window open.
  useEffect(() => {
    if (!entered) return
    if (reduced) {
      setTyped(ANSWERS_PROMPT)
      setSent(true)
      setOpened(true)
      return
    }
    const timers: number[] = []
    let at = 520
    const step = (delay: number, run: () => void) => {
      at += delay
      timers.push(window.setTimeout(run, at))
    }
    for (let i = 1; i <= ANSWERS_PROMPT.length; i += 1) step(30, () => setTyped(ANSWERS_PROMPT.slice(0, i)))
    step(400, () => {
      setSent(true)
      setOpened(true)
    })
    return () => timers.forEach(window.clearTimeout)
  }, [entered, reduced])

  // The demo starts once the window has zoomed in, so the answer is never half
  // streamed by the time it lands. `onAnimationComplete` drives the normal
  // path; this timer covers viewports where the screen never reaches the
  // entrance threshold. It must not read `reduced`, which reports true on the
  // first render before the media query resolves.
  useEffect(() => {
    if (!entered) return
    const t = window.setTimeout(() => setReady(true), 4500)
    return () => window.clearTimeout(t)
  }, [entered])

  // Last resort for a viewport so short that the screen never reaches the
  // entrance threshold: the demo still has to run.
  useEffect(() => {
    if (!live) return
    const t = window.setTimeout(() => setReady(true), 7000)
    return () => window.clearTimeout(t)
  }, [live])

  useLayoutEffect(() => {
    const screen = screenRef.current
    const win = windowRef.current
    if (!screen || !win) return
    // Layout offsets, not client rects: the window sits inside an animated
    // scale wrapper, and a rect measured mid-animation would leave the
    // refraction sampling the wrong part of the wallpaper.
    const measure = () => {
      let x = 0
      let y = 0
      let node: HTMLElement | null = win
      while (node && node !== screen) {
        x += node.offsetLeft
        y += node.offsetTop
        node = node.offsetParent as HTMLElement | null
      }
      setOffset({ x, y, w: screen.clientWidth, h: screen.clientHeight, ww: win.offsetWidth, wh: win.offsetHeight })
    }
    measure()
    const observer = new ResizeObserver(measure)
    observer.observe(screen)
    observer.observe(win)
    return () => observer.disconnect()
  }, [])

  return (
    <div className="rounded-[20px] shadow-[0_40px_100px_-30px_rgba(20,10,60,0.45)] ring-1 ring-black/10">
      <div ref={screenRef} className="relative aspect-[4/5] overflow-hidden rounded-[20px] sm:aspect-[16/9]">
        <Wallpaper id="wp" className="absolute inset-0 size-full" />
        <MenuBar />
        <Desktop hidden={reduced ? true : entered} />
        <motion.div
          // Scaling the whole screen layer keeps the shrunken window pinned to
          // the bottom-right at any aspect ratio, and leaves the window's own box
          // untouched so the refraction stays measured against the layout. The
          // origin is past the right edge so the docked window keeps an even
          // margin from the corner.
          className="absolute inset-0"
          style={{ transformOrigin: "117% 111%" }}
          initial={reduced ? false : { opacity: 0, scale: 0.34, y: 22 }}
          animate={
            reduced || opened
              ? { opacity: 1, scale: 1, y: 0, transition: { duration: 0.85, ease } }
              : entered
                ? {
                    opacity: 1,
                    scale: 0.5,
                    y: 0,
                    transition: {
                      opacity: { duration: 0.18 },
                      default: { type: "spring", stiffness: 260, damping: 17, mass: 0.9 },
                    },
                  }
                : { opacity: 0, scale: 0.34, y: 22 }
          }
          onAnimationComplete={() => {
            if (opened) setReady(true)
          }}
        >
          <div ref={windowRef} className="absolute inset-x-0 top-[14%] mx-auto h-full w-[min(34rem,90%)]">
            <FlareWindow feature={feature} offset={offset} live={live && ready} typed={typed} sent={sent} />
          </div>
        </motion.div>
      </div>
    </div>
  )
}

export function Showcase() {
  const ref = useRef<HTMLDivElement>(null)
  const inView = useInView(ref, { amount: 0.2 })
  const reduced = useReducedMotion()
  const [active, setActive] = useState<FeatureId>("answers")
  const [paused, setPaused] = useState(false)
  const cycling = inView && !paused && !reduced

  useEffect(() => {
    if (!cycling) return
    const index = FEATURES.findIndex((f) => f.id === active)
    const t = window.setTimeout(() => {
      setActive(FEATURES[(index + 1) % FEATURES.length].id)
    }, FEATURES[index].dwell)
    return () => window.clearTimeout(t)
  }, [active, cycling])

  const current = FEATURES.find((f) => f.id === active) ?? FEATURES[0]

  return (
    <div ref={ref} onMouseEnter={() => setPaused(true)} onMouseLeave={() => setPaused(false)}>
      <div className="mb-6 flex justify-center">
        <div role="tablist" className="flex items-center gap-1 rounded-full bg-secondary p-1 ring-1 ring-black/[0.06]">
          {FEATURES.map((f) => (
            <button
              key={f.id}
              role="tab"
              type="button"
              aria-selected={f.id === active}
              onClick={() => setActive(f.id)}
              className={cn(
                "relative overflow-hidden rounded-full px-4 py-1.5 text-sm font-medium transition-colors",
                f.id === active ? "text-foreground" : "text-muted-foreground hover:text-foreground",
              )}
            >
              {f.id === active && (
                <motion.span
                  layoutId="tab-pill"
                  transition={{ type: "spring", stiffness: 500, damping: 40 }}
                  className="absolute inset-0 rounded-full bg-white shadow-[0_1px_2px_rgba(0,0,0,0.08)] ring-1 ring-black/[0.06]"
                />
              )}
              {f.id === active && cycling && <span key={active} className="tab-progress absolute inset-x-3 bottom-0.5 h-0.5 rounded-full" />}
              <span className="relative">{f.label}</span>
            </button>
          ))}
        </div>
      </div>

      <MacScreen feature={active} live={inView} />

      <div className="mt-6 h-14 text-center sm:h-8">
        <AnimatePresence mode="wait" initial={false}>
          <motion.p
            key={current.id}
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -6 }}
            transition={{ duration: 0.25 }}
            className="text-[17px] text-muted-foreground"
          >
            <span className="font-semibold text-foreground">{current.title}.</span> {current.body}
          </motion.p>
        </AnimatePresence>
      </div>
    </div>
  )
}

