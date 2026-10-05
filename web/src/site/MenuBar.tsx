import { BatteryMedium, Search, Wifi } from "lucide-react"
import { useEffect, useState } from "react"

import { AppleLogo } from "@/components/AppleLogo"
import { asset, DOWNLOAD, RELEASES } from "./data"

function useClock() {
  const [now, setNow] = useState(() => new Date())
  useEffect(() => {
    const id = window.setInterval(() => setNow(new Date()), 15_000)
    return () => window.clearInterval(id)
  }, [])
  return now
}

const day = new Intl.DateTimeFormat("en-US", { weekday: "short", month: "short", day: "numeric" })
const time = new Intl.DateTimeFormat("en-US", { hour: "numeric", minute: "2-digit" })

export function MenuBar() {
  const now = useClock()
  return (
    <header className="fixed inset-x-0 top-0 z-50 border-b border-black/[0.07] bg-desk/75 backdrop-blur-xl backdrop-saturate-150">
      <div className="relative flex h-11 items-center justify-between px-4 text-[14px] sm:px-6">
        <nav className="flex items-center gap-5">
          <a href="#top" className="font-semibold">flare</a>
          <a href="#features" className="hidden text-black/60 transition-colors hover:text-ink md:inline">Features</a>
          <a href="#shortcuts" className="hidden text-black/60 transition-colors hover:text-ink md:inline">Shortcuts</a>
          <a href="#open-source" className="hidden text-black/60 transition-colors hover:text-ink md:inline">Open source</a>
          <a href={RELEASES} className="hidden text-black/60 transition-colors hover:text-ink lg:inline">Changelog</a>
        </nav>

        <a href="#top" aria-label="Flare" className="absolute left-1/2 -translate-x-1/2">
          <img src={asset("icon.png")} alt="" className="size-6 rounded-[6px]" />
        </a>

        <div className="flex items-center gap-4 text-black/60">
          <Wifi className="hidden size-[15px] lg:block" aria-hidden />
          <BatteryMedium className="hidden size-[18px] lg:block" aria-hidden />
          <Search className="hidden size-[14px] lg:block" aria-hidden />
          <span className="hidden tabular-nums lg:inline">
            {day.format(now)} {time.format(now).split(":")[0]}
            <span className="clock-colon">:</span>
            {time.format(now).split(":")[1]}
          </span>
          <a href={DOWNLOAD} className="flex items-center gap-1.5 font-medium text-violet">
            <AppleLogo className="size-3.5 -translate-y-px" />
            Get Flare
          </a>
        </div>
      </div>
    </header>
  )
}
