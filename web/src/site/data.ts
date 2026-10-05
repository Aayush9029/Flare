const base = import.meta.env.BASE_URL

export const asset = (path: string) => `${base}assets/${path}`
export const media = (path: string) => `${base}media/${path}`

export const SOURCE = "https://github.com/Aayush9029/Flare"
export const DOWNLOAD = `${SOURCE}/releases/latest`
export const RELEASES = `${SOURCE}/releases`
export const BREW = "brew install --cask aayush9029/tap/flare"

export type Cue = { t: number; keys: string[] }

export type Clip = { src: string; poster: string; title: string }

const clip = (folder: string, name: string, title = `${name}.mov`): Clip => ({
  src: media(`${folder}/${name}.mp4`),
  poster: media(`${folder}/${name}.jpg`),
  title,
})

export const CLIPS = {
  hello: clip("clips", "hello"),
  kitchen: clip("clips", "kitchen", "risotto-night.mov"),
  cafe: clip("clips", "cafe", "iced-coffee.mov"),
  night: clip("clips", "night", "2am.mov"),
}

const open: Cue = { t: 1.15, keys: ["⌘", "⇧", "Space"] }
const fresh: Cue = { t: 2.08, keys: ["⌘", "N"] }

export const APP = {
  summon: {
    ...clip("app", "summon", "summon.mov"),
    cues: [open, { t: 4.06, keys: ["esc"] }, { t: 5.93, keys: ["⌘", "⇧", "Space"] }, { t: 8.62, keys: ["esc"] }],
  },
  websearch: { ...clip("app", "websearch", "usd-to-cad.mov"), cues: [open, fresh, { t: 5.8, keys: ["↩"] }] },
  risotto: { ...clip("app", "risotto", "risotto.mov"), cues: [open, fresh, { t: 6.52, keys: ["↩"] }] },
  image: { ...clip("app", "image", "tiny-desk.mov"), cues: [open, fresh, { t: 8.75, keys: ["↩"] }] },
  queue: { ...clip("app", "queue", "queue.mov"), cues: [open, fresh, { t: 6.34, keys: ["↩"] }, { t: 11.08, keys: ["↩"] }] },
  search: { ...clip("app", "search", "command-k.mov"), cues: [open, { t: 2.26, keys: ["⌘", "K"] }, { t: 6.24, keys: ["↩"] }] },
} satisfies Record<string, Clip & { cues: Cue[] }>

export const PROVIDERS = [
  { id: "openai", name: "OpenAI" },
  { id: "anthropic", name: "Anthropic" },
  { id: "gemini", name: "Gemini" },
  { id: "groq", name: "Groq" },
  { id: "openrouter", name: "OpenRouter" },
  { id: "ollama", name: "Ollama" },
  { id: "lmstudio", name: "LM Studio" },
  { id: "mistral", name: "Mistral" },
  { id: "xai", name: "xAI" },
  { id: "deepseek", name: "DeepSeek" },
]

export const SHORTCUTS = [
  { keys: ["⌘", "⇧", "Space"], codes: ["Meta", "Shift", "Space"], action: "Open or hide Flare from any app" },
  { keys: ["⌘", "K"], codes: ["Meta", "KeyK"], action: "Search every chat" },
  { keys: ["⌘", "N"], codes: ["Meta", "KeyN"], action: "Start a new chat" },
  { keys: ["⌘", "."], codes: ["Meta", "Period"], action: "Stop the answer" },
  { keys: ["⌘", ","], codes: ["Meta", "Comma"], action: "Open Settings" },
  { keys: ["esc"], codes: ["Escape"], action: "Hide Flare" },
]
