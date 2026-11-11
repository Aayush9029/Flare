# Flare

A macOS floating quick chat that uses a ChatGPT subscription. `⌘⇧Space` opens a non-activating glass panel over the current app. `⌘K` searches every message. The app is menu-bar only (`LSUIElement`), unsandboxed, and generated with Tuist. It is free and MIT licensed: no trial, no license key, no payment.

## Layout

| Unit | Role |
|------|------|
| `Flare/` | App target: entry point, `AppDelegate`, status item, single-instance lock, resources |
| `FlareKit/` | Static framework: auth, chat streaming, providers, SQLite store, search, `FlareModel`, window client |
| `FlareUI/` | Static framework: panel, composer, command palette, settings, Markdown, design system |
| `FlareKitTests/` | Swift Testing suites, with gated live and benchmark suites |
| `web/` | Landing page source (Vite, React, Tailwind) |
| `docs/` | Built landing page, served by GitHub Pages at `https://aayush9029.github.io/Flare/` |

## Commands

| Task | Command |
|------|---------|
| Resolve packages | `tuist install` (after a `Tuist/Package.swift` edit) |
| Generate project | `tuist generate --no-open` |
| Build | `xcodebuild build -workspace Flare.xcworkspace -scheme Flare -configuration Debug -destination 'platform=macOS'` |
| Test | `xcodebuild test -workspace Flare.xcworkspace -scheme FlareKit -destination 'platform=macOS'` |
| Live tests | `TEST_RUNNER_FLARE_LIVE_TESTS=1 xcodebuild test ...` (spends real quota) |
| Search benchmarks | `TEST_RUNNER_FLARE_BENCH=1 xcodebuild test ... -only-testing:FlareKitTests/SearchBenchmarks` |
| Landing page | `cd web && bun install && bun run build` (writes `docs/`) |
| Landing lint | `cd web && bun run lint` |

- Tests live on the **`FlareKit`** scheme. There is no `FlareKitTests` scheme.
- `xcodebuild` does not forward the parent environment to tests. Use the `TEST_RUNNER_` prefix.
- `LiveProviderTests` runs each vendor that has a `TEST_RUNNER_<VENDOR>_API_KEY`.
- Resources under `Flare/Resources/` are globbed at `tuist generate` time. After you add a file, regenerate the project.
- Pages serves `docs/` from `main` as committed. Rebuild and commit `docs/` with every `web/` change. The source is in `web/` because the global `~/.gitignore` ignores a root `/site`.

## Release

Every push to `main` that changes the app runs `.github/workflows/release.yml`: build, test, sign, notarize, DMG, GitHub release. Changes to `docs/`, `web/`, `assets/`, and Markdown files do not start a release. `RELEASING.md` has the signing identity and the secret names.

## Authentication

Flare signs in as the **Codex CLI public OAuth client**, so a ChatGPT subscription drives the chat with no API key.

- Client `app_EMoamEEZ73f0CkXaXp7hrann` against `https://auth.openai.com`, PKCE S256.
- The redirect is fixed at `http://localhost:1455/auth/callback`. The server accepts no other URI, so `LoopbackServer` binds 1455, and a running `codex login` blocks sign-in.
- Credentials live in `~/Library/Application Support/Flare/` at mode `0600`: `auth.json` (ChatGPT tokens) and `api-key`. **Do not move them to the Keychain.** A Keychain ACL binds to the signing identity, so each re-signed debug build lost the token.
- `importFromCodexCLI` adopts `~/.codex/auth.json` and skips the browser.
- The credential picks the endpoint. An API key wins when present and goes to `https://api.openai.com/v1/responses`. ChatGPT tokens go to `https://chatgpt.com/backend-api/codex/responses` with the Codex headers (`chatgpt-account-id`, `OpenAI-Beta: responses=experimental`, `originator: codex_cli_rs`). The two credentials are never interchangeable.
- Refresh omits `scope`. A narrower scope set silently downgrades the access token.
- Mint `session_id` per request. A reused id across a cancelled stream breaks every later turn in that session.
- A GUI launch inherits no shell environment. Settings reads `OPENAI_API_KEY` from the login shell and stores a copy.

## Providers

`ProviderCatalog` owns every provider, the active one, and the last model and effort of each (`providerSelections`). Built-ins: ChatGPT, OpenAI, Anthropic, Groq, Gemini, OpenRouter, then custom Chat Completions endpoints. Keys and listed models (except ChatGPT and OpenAI) live in `providers.json` (0600).

- `ChatClient` routes on `ChatEndpoint`: Responses, `AnthropicAPI`, or `ChatCompletionsAPI`. All three decode into `StreamEvent`s through `StreamingHTTP`. A stream that ends without a done event counts as completed; only a cancellation counts as stopped.
- Reasoning: Responses `reasoning.effort`; Chat Completions `reasoning_effort`; OpenRouter `reasoning: {effort}`. Off sends nothing.
- Anthropic reads the model id (`ClaudeModel`). Haiku and models before 4.6 take `thinking.budget_tokens`. Later models reject a budget and take adaptive thinking with `output_config.effort` and `display: "summarized"`. Fable, Opus 5+, and Sonnet 5.5+ cannot turn thinking off, and send `fallbacks: "default"`.
- `ThinkTagSplitter` honours `<think>` tags only before any answer text.
- Listings come from `/models`. `ProviderHints` covers vendors that do not report reasoning support. Vision turns send `image_url` parts; plain turns stay strings, because a server without vision fails on parts.
- Keep a key only after the vendor lists models. Prove a typed model with "What is 2+2?".
- Info.plist has `NSAllowsArbitraryLoads` and a local-network usage string for `http://` and LAN servers.

## Storage and search

- SQLite via SQLiteData. `chatThreads` and `chatMessages` use `Tagged` IDs. Tuist does not forward the sqlite-data `Tagged` package trait, so `Tuist/Package.swift` sets `SWIFT_ACTIVE_COMPILATION_CONDITIONS` on `StructuredQueriesCore` and `SQLiteData`. Keep it; without it every `@Table` fails to compile.
- Search is FTS5 (`messageSearch`), kept in sync by triggers on `chatMessages`. These choices in `MessageSearch.hits` came from benchmarks; keep them:
  - **`MATERIALIZED`** on the match CTE. Without it SQLite rejects `snippet()`.
  - **`ORDER BY rank LIMIT` inside the CTE.** It ranks only the top hits.
  - **No porter stemmer.** It breaks prefix queries for search-as-you-type.
  - A standalone FTS table, not external content, because `VACUUM` can renumber rowids.
- `MessageListView` declares `@FetchAll(ChatMessage.none)` before `init` sets the query. A bare `@FetchAll` fetches every message on the main thread on each body run.
- `SearchTuning` backs off debounce and limits under Low Power Mode.

## Tools

- The Codex backend accepts only **`web_search`** and **`image_generation`**.
- Web search is on by default for ChatGPT, OpenAI, and Anthropic. Chat Completions vendors get no tools.
- `FlareModel.instructions(prompt:webSearch:)` appends the search guidance at request time. Do not bake it into the editable system prompt.
- Citations (`url_citation`) show under the streaming answer only; they are not stored.
- Generated images arrive base64 in `response.output_item.done`. `ImageStore` writes them to `Application Support/Flare/images/` and the message stores the file name.

## Markdown rendering

`FlareUI/Sources/Markdown/` renders answers without a Markdown view package. `MarkdownDocumentBuilder` parses with swift-markdown off the main thread. `MarkdownTextView` is one TextKit 2 `NSTextView` per run of blocks; tables are separate `MarkdownTable` values because TextKit 2 cannot lay them out. `CodeHighlighter` uses HighlightSwift after a fence closes.

Profiling settled these. Do not undo them:

- **`sizingOptions = []`** on the panel root `NSHostingView`.
- **`widthTracksTextView = false` and `isVerticallyResizable = false`** on the text views. SwiftUI sizes them from `height(fittingWidth:)`.
- **Core Animation layers** for the streaming border and the shimmer, not `TimelineView`.
- **At most one build every 33 ms** (`MarkdownDocumentModel.buildInterval`).
- `MarkdownRelay` sends growing snapshots, not deltas, and replays to late subscribers.
- Every assistant row renders through `StreamedMarkdownView` fed by `FlareModel.responseRelay(for:)`, stored rows too. The live placeholder shares the stored message id, so the row keeps its identity when the stream ends.
- The transcript is a plain `VStack` in a `ScrollView`, not a `LazyVStack`. Lazy rows jitter under a bottom anchor. It follows new content only while the reader is at the bottom.

## Panel and UI rules

- The panel has no toolbar and no sidebar by design. Navigation is `⌘K`. Escape goes through `FlarePanel.cancelOperation` and the `setCancelHandler` set in `AppDelegate`, not a SwiftUI `keyboardShortcut`, because a focused `TextField` takes the key first. Escape order: close the palette, close the thoughts, hide the panel.
- The composer takes focus each time the panel becomes key.
- The panel hides when it resigns key, except during a tracking `NSMenu`, while a Settings window is key, or with "Float on top".
- The panel drags through `WindowDragGesture` on the content, not `isMovableByWindowBackground`, which rebuilt drag regions on every layout.
- Set the `FlarePanel` frame autosave name after the first placement, not at creation. At creation it saves the empty start frame.
- `windowDidBecomeKey` arrives before AppKit sets the key flag, so the position ghost guard tests visibility.
- After a hand resize, `windowDidEndLiveResize` snaps Width and Size to the nearest stops. `PanelHost` adopts the values first, so the frame does not snap.
- Liquid Glass alone is unreadable over a busy desktop. `PanelScrim` sits under panel content.
- The composer field editor takes Command-V first and drops non-text. `AppDelegate` catches an image paste in a local key monitor and calls `FlareModel.addAttachment`. `ImageDrop` re-encodes images as JPEG.
- A send during a stream joins `FlareModel.queue`. A reply that finishes sends the next queued message; a stopped reply waits behind "Send Next". ⌘. always stops.
- `AnimatedImageView` plays the Settings GIFs off the main thread. Read `NSWindow.colorSpace`, not `NSScreen.colorSpace`, which blocks the main thread.
- Thinking time is stored in `chatMessages.reasoningSeconds`; zero means unknown.

## Conventions

- Settings uses one type per file in `FlareUI/Sources/Settings/`.
- Settings chrome (`SettingsCard`, `ToggleCard`, `SelectableCard`, `SettingsForm`, `cardBand`, `settingFootnote`) is copied from Breeze. `AccountPane` mirrors the Breeze license pane. Keep them aligned when Breeze changes.
- The Providers pane follows the provider page of a private sibling app. Keep it aligned when the owner asks. `ReasoningCard` is Flare's own.
- The model and the provider are chosen in Settings. The composer chip changes only the effort.
- Keep Settings copy short. A pasted API key is trimmed and must pass `verifyAPIKey` before it is kept.
- Provider marks are LobeHub static SVGs in `Flare/Resources/ProviderIcons.xcassets`. To add one, fetch `https://unpkg.com/@lobehub/icons-static-svg@latest/icons/<name>.svg` and space out the arc flags, because CoreSVG rejects the compact form (`0 01-4.45`). `ProviderIcon` maps hosts and ports to names.
