import { motion } from "motion/react"

import { cn } from "@/lib/utils"

export function Wordmark({ className, delay = 0, entrance = true }: { className?: string; delay?: number; entrance?: boolean }) {
  return (
    <span className={cn("inline-flex font-rounded font-semibold", className)} aria-label="flare">
      {"flare".split("").map((letter, i) => (
        <motion.span
          key={i}
          aria-hidden
          initial={entrance ? { y: "0.35em", opacity: 0 } : false}
          animate={{ y: 0, opacity: 1 }}
          whileHover={{ y: "-0.08em", transition: { type: "spring", stiffness: 600, damping: 12 } }}
          transition={{ type: "spring", stiffness: 380, damping: 18, delay: delay + i * 0.06 }}
          className="inline-block cursor-default"
        >
          {letter}
        </motion.span>
      ))}
    </span>
  )
}
