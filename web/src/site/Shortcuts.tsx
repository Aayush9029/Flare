import { motion } from "motion/react"
import { useEffect, useState } from "react"

import { cn } from "@/lib/utils"
import { SHORTCUTS } from "./data"

type Key = { code: string; label: string; width?: number; sub?: string }

const ROWS: Key[][] = [
  [
    { code: "Tab", label: "tab", width: 1.5 },
    ..."QWERTYUIOP".split("").map((c) => ({ code: `Key${c}`, label: c })),
    { code: "BracketLeft", label: "[" },
    { code: "BracketRight", label: "]" },
    { code: "Backslash", label: "\\", width: 1.5 },
  ],
  [
    { code: "CapsLock", label: "caps lock", width: 1.8 },
    ..."ASDFGHJKL".split("").map((c) => ({ code: `Key${c}`, label: c })),
    { code: "Semicolon", label: ";" },
    { code: "Quote", label: "'" },
    { code: "Enter", label: "return", width: 2.2 },
  ],
  [
    { code: "ShiftLeft", label: "⇧", sub: "shift", width: 2.4 },
    ..."ZXCVBNM".split("").map((c) => ({ code: `Key${c}`, label: c })),
    { code: "Comma", label: "," },
    { code: "Period", label: "." },
    { code: "Slash", label: "/" },
    { code: "ShiftRight", label: "⇧", sub: "shift", width: 2.6 },
  ],
  [
    { code: "Fn", label: "fn" },
    { code: "ControlLeft", label: "⌃", sub: "control" },
    { code: "AltLeft", label: "⌥", sub: "option" },
    { code: "MetaLeft", label: "⌘", sub: "command", width: 1.35 },
    { code: "Space", label: "", width: 5.3 },
    { code: "MetaRight", label: "⌘", sub: "command", width: 1.35 },
    { code: "AltRight", label: "⌥", sub: "option" },
    { code: "Escape", label: "esc", width: 2 },
  ],
]

const alias = (code: string) => code.replace(/(Left|Right)$/, "")

function useKeysDown() {
  const [down, setDown] = useState<Set<string>>(new Set())
  useEffect(() => {
    const press = (event: KeyboardEvent) => setDown((current) => new Set(current).add(event.code))
    const release = (event: KeyboardEvent) => {
      if (event.key === "Meta") return setDown(new Set())
      setDown((current) => {
        const next = new Set(current)
        next.delete(event.code)
        return next
      })
    }
    const clear = () => setDown(new Set())
    window.addEventListener("keydown", press)
    window.addEventListener("keyup", release)
    window.addEventListener("blur", clear)
    return () => {
      window.removeEventListener("keydown", press)
      window.removeEventListener("keyup", release)
      window.removeEventListener("blur", clear)
    }
  }, [])
  return down
}

export function Shortcuts() {
  const down = useKeysDown()
  const [demo, setDemo] = useState<number | null>(null)

  const pressed = new Set([...down].map(alias))
  const demoCodes = demo === null ? [] : SHORTCUTS[demo].codes.map((code) => (code === "Meta" || code === "Shift" ? `${code}Left` : code))
  const isDown = (code: string) => down.has(code) || demoCodes.includes(code)

  const matched = SHORTCUTS.findIndex(
    (s) => s.codes.length === pressed.size && s.codes.every((code) => pressed.has(code)),
  )
  const active = demo ?? (matched >= 0 ? matched : null)


  return (
    <section id="shortcuts" className="night-dots relative overflow-hidden bg-night px-6 py-28 text-white">
      <div className="mx-auto max-w-6xl">
        <h2 className="max-w-xl text-balance text-[40px] leading-[1.05] font-semibold tracking-[-0.03em] sm:text-[52px]">
          Your hands stay on the keyboard
        </h2>
        <p className="mt-4 max-w-md text-[18px] leading-relaxed text-white/60">
          Every move in Flare has a shortcut. Press one on your keyboard, or point at one in the list.
        </p>

        <div className="mt-14 grid items-start gap-12 lg:grid-cols-[1fr_20rem]">
          <div className="overflow-x-auto no-scrollbar">
            <div
              className="flex min-w-[640px] flex-col gap-[6px] rounded-[22px] bg-[#15102a] p-3 shadow-[inset_0_1px_0_rgba(255,255,255,0.06),0_30px_60px_-30px_rgba(0,0,0,0.8)] ring-1 ring-white/10"
              aria-hidden
            >
              {ROWS.map((row, r) => (
                <div key={r} className="flex gap-[6px]">
                  {row.map((key) => (
                    <div
                      key={key.code}
                      data-down={isDown(key.code)}
                      style={{ flexGrow: key.width ?? 1, flexBasis: 0 }}
                      className={cn(
                        "keycap-dark flex h-14 min-w-0 flex-col justify-between rounded-[8px] px-2 py-1.5 text-white/80 transition-[background,box-shadow,translate] duration-75",
                        "data-[down=true]:translate-y-px data-[down=true]:text-white",
                        !key.sub && "items-center justify-center",
                      )}
                    >
                      <span className={cn("text-[15px] leading-none", key.label.length > 2 && "text-[11px]")}>{key.label}</span>
                      {key.sub && <span className="text-[10px] leading-none text-white/50">{key.sub}</span>}
                    </div>
                  ))}
                </div>
              ))}
            </div>
          </div>

          <ul className="flex flex-col gap-1">
            {SHORTCUTS.map((shortcut, i) => (
              <li key={shortcut.action}>
                <button
                  type="button"
                  onMouseEnter={() => setDemo(i)}
                  onMouseLeave={() => setDemo(null)}
                  onFocus={() => setDemo(i)}
                  onBlur={() => setDemo(null)}
                  className={cn(
                    "relative flex w-full items-center justify-between gap-4 rounded-[12px] px-4 py-3 text-left text-[15px] transition-colors",
                    active === i ? "text-white" : "text-white/65 hover:bg-white/5 hover:text-white",
                  )}
                >
                  {active === i && (
                    <motion.span
                      layoutId="shortcut-active"
                      transition={{ type: "spring", stiffness: 500, damping: 36 }}
                      className="absolute inset-0 rounded-[12px] bg-white/10 ring-1 ring-white/15"
                    />
                  )}
                  <span className="relative">{shortcut.action}</span>
                  <span className="relative flex shrink-0 gap-1">
                    {shortcut.keys.map((key) => (
                      <kbd key={key} className={cn("keycap-dark rounded-[6px] px-2 py-0.5 font-sans text-[13px] text-white/85 transition-transform duration-100", active === i && "translate-y-px")}>
                        {key}
                      </kbd>
                    ))}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  )
}
