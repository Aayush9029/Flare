# Flare

A macOS floating quick-chat driven by your ChatGPT subscription. `⌘⇧Space` opens a
non-activating glass panel over whatever you are doing; `⌘K` searches every message
you have ever sent or received. Menu-bar only (`LSUIElement`), unsandboxed, Tuist-generated.

## Layout

| Unit | What |
|------|------|
| `Flare/` | App target — entry point, `AppDelegate`, status item, single-instance lock, `AppIcon.icon`, GIF resources |
| `FlareKit/` | Static framework — auth, chat streaming, SQLite store, search, `FlareModel`, window client |
| `FlareUI/` | Static framework — panel, composer, command palette, settings, design system |
| `FlareKitTests/` | Swift Testing suites, including gated live and benchmark suites |
| `web/` | Landing page source (Vite, React, Tailwind) |
| `docs/` | Built landing page, served by GitHub Pages at `https://aayush9029.github.io/Flare/` |

## Commands

```bash
tuist install                       # resolve packages (needed after Tuist/Package.swift edits)
tuist generate --no-open            # regenerate the workspace
xcodebuild build -workspace Flare.xcworkspace -scheme Flare -configuration Debug -destination 'platform=macOS'
xcodebuild test  -workspace Flare.xcworkspace -scheme FlareKit -destination 'platform=macOS'
cd web && bun install && bun run build   # rebuild the landing page into docs/
```

Flare is free and MIT licensed: no trial, no license key, no payment. Pages serves `docs/` from
`main` as committed, so rebuild and commit `docs/` with every `web/` change. The global
`~/.gitignore` ignores a root `/site`, which is why the source lives in `web/`.

Tests live on the **`FlareKit`** scheme, not `Flare` — Tuist attaches a unit-test target
to the scheme of the target it tests, and there is no `FlareKitTests` scheme.

Two suites are gated so a normal run neither spends quota nor takes seconds. `xcodebuild`
does not forward the parent environment to the test process; the `TEST_RUNNER_` prefix does:

```bash
TEST_RUNNER_FLARE_LIVE_TESTS=1 xcodebuild test ...   # hits the real Codex backend
TEST_RUNNER_FLARE_BENCH=1 xcodebuild test ... -only-testing:FlareKitTests/SearchBenchmarks
```

## Authentication

Flare signs in as the **Codex CLI's own public OAuth client**, so a ChatGPT subscription
drives the chat with no API key and no metered billing.

- Client `app_EMoamEEZ73f0CkXaXp7hrann` against `https://auth.openai.com`, PKCE S256.
- Redirect is fixed at `http://localhost:1455/auth/callback`. The port is not a choice —
  it is the only URI the authorization server accepts for this client, so `LoopbackServer`
  binds 1455 and a running `codex login` will block sign-in.
- Credentials live in `~/Library/Application Support/Flare/` at mode `0600`: `auth.json` for the
  ChatGPT tokens, `api-key` for an API key. **Not the Keychain** — a Keychain ACL is bound to the
  signing identity, so every re-signed debug build lost the token.
- `importFromCodexCLI` adopts `~/.codex/auth.json` directly, skipping the browser.
- Two credentials, and the credential picks the endpoint. An API key wins when present because the
  user set it explicitly: it goes to `https://api.openai.com/v1/responses` and bills per token.
  Otherwise ChatGPT tokens go to `https://chatgpt.com/backend-api/codex/responses` with the headers
  Codex sends (`chatgpt-account-id`, `OpenAI-Beta: responses=experimental`, `originator: codex_cli_rs`).
  A ChatGPT subscription is rejected by the public API and an API key is rejected by the Codex
  backend, so the two are never interchangeable.
- A GUI launch inherits no shell environment, so `OPENAI_API_KEY` is only visible when Flare is run
  from a terminal. Settings reads it out of the login shell and stores a copy.

## Providers

`ProviderCatalog` owns every provider, which one answers, and the model and effort each one last
used (`providerSelections`, JSON in app storage). Built-ins in Compose's order: ChatGPT (OAuth,
Responses at the Codex backend), OpenAI (Responses at api.openai.com), Anthropic (native Messages
API), Groq, Gemini and OpenRouter (Chat Completions at fixed base URLs), then custom endpoints,
any Chat Completions server. Keys and listed models for everything but ChatGPT and OpenAI live in
`providers.json` (0600) keyed by provider id; custom endpoints by UUID. An endpoint added at a
built-in vendor's URL folds into that vendor's card on load.

- `ChatClient` routes on `ChatEndpoint`: Responses, `AnthropicAPI`, or `ChatCompletionsAPI`. All
  three decode into the same `StreamEvent`s through `StreamingHTTP`; a stream that ends without
  saying so still counts as completed, only a cancellation counts as stopped.
- Reasoning per dialect: Responses `reasoning.effort`; Chat Completions `reasoning_effort`,
  except OpenRouter, which takes `reasoning: {effort}`. Off sends nothing. Anthropic reads the
  model id (`ClaudeModel`): Haiku and models before 4.6 take `thinking.budget_tokens` (low 2048,
  medium 8192, high 32768, plus 16384 `max_tokens`); later ones 400 on a budget and take adaptive
  thinking with `output_config.effort`, 64000 `max_tokens` and `display: "summarized"`, since 4.7
  onward stream empty thoughts otherwise. Off sends `thinking: disabled`. Fable and Opus or Sonnet
  5.5 onward cannot stop thinking, so they offer no Off. Fable, Opus 5+ and Sonnet 5.5+ also send
  `fallbacks: "default"` (beta `server-side-fallback-2026-07-01`) so Anthropic retries a safeguard
  decline on another model; a `refusal` stop reason that survives fails the turn. Thoughts arrive as
  `reasoning` (OpenRouter, Groq) or `reasoning_content` (vLLM, llama.cpp) deltas, or as `<think>`
  tags, which `ThinkTagSplitter` only honours before any answer text.
- Listings come from `/models` in every dialect. OpenRouter says which models reason
  (`supported_parameters`) and what they take (`architecture` modalities); `ProviderHints` covers
  vendors that say nothing (Groq gpt-oss, Gemini 2.5 and 3, xAI mini); a word list drops speech,
  embedding, guard, image and video models. Gemini accepts its `models/...` ids as listed. Vision
  turns go as `image_url` parts; plain turns stay strings, since a server without vision chokes
  on parts.
- A key is kept only after the vendor lists models (OpenAI answers a "hi" instead). A model typed
  by hand is proven with "What is 2+2?", as Compose does.
- `NSAllowsArbitraryLoads` and a local-network usage string are in Info.plist for servers on
  `http://` and on the LAN.
- Live tests: `LiveProviderTests` runs every vendor it finds a `TEST_RUNNER_<VENDOR>_API_KEY` for.
  Groq's CDN blocks Python's user agent, not URLSession's.
- `session_id` is minted per request. Reusing one across a cancelled stream leaves the server-side
  session unreconciled and every later turn in it fails.
- Refresh omits `scope`; sending a narrower set silently downgrades the access token.

## Storage and search

SQLite via SQLiteData. `chatThreads` and `chatMessages` use `Tagged` IDs; the conformances
come from sqlite-data's **`Tagged` package trait**, which Tuist does not forward on its own —
`Tuist/Package.swift` sets `SWIFT_ACTIVE_COMPILATION_CONDITIONS` on `StructuredQueriesCore`
and `SQLiteData` by hand. Drop that and every `@Table` fails to compile.

Search is FTS5 (`messageSearch`) kept in sync by triggers on `chatMessages`. Three choices
in `MessageSearch.hits` are load-bearing and were each settled by measurement:

- **`MATERIALIZED`** on the match CTE. Without it SQLite flattens the match into the join and
  rejects `snippet()` with "unable to use function snippet in the requested context".
- **`ORDER BY rank LIMIT` inside the CTE.** Ranking every hit before narrowing costs 59 ms on a
  common word over 20k messages; ranking only the top 300 costs 13 ms.
- **No porter stemmer.** Porter indexes stems, so the prefix query `notariz*` misses the stem
  `notar` it came from, breaking search-as-you-type.

`SearchTuning` backs off debounce and limits under Low Power Mode.

Benchmarks (`SearchBenchmarks`, 20k messages, Zipfian corpus) also rejected `LIKE` (cannot do
multi-term or ranking, 15 ms on rare terms) and trigram (2.9x the index for worse mid-range
latency). External-content FTS is 39% smaller at equal speed but ties the index to rowids that
`VACUUM` may renumber, so the standalone table stays.

`MessageListView` declares `@FetchAll(ChatMessage.none)` before its `init` sets the thread's
query. A bare `@FetchAll` default-initialises to every message in the database and fetches it on
the main thread each time the panel's body runs: 44 ms per run on 20k messages, which made ⌘K
cost 51 ms per keystroke (5.5 ms without it) and the first show 148 ms (28 ms).

## Tools

The Codex backend accepts **`web_search`** and **`image_generation`**. It rejects
`code_interpreter`, `file_search` and `computer_use_preview`, and `local_shell` was removed.
Both `web_search` and the public API behave the same way here.

Web search is on by default for ChatGPT, OpenAI and Anthropic (`web_search_20250305`); Chat
Completions vendors get no tools. The guidance that makes the model search unprompted is appended
to the instructions at request time by `FlareModel.instructions(prompt:webSearch:)` rather than
baked into the editable system prompt, so a custom prompt keeps working and the toggle takes
effect at once. Measured behaviour: current facts, news, prices and new APIs search; arithmetic, writing help
and stable concepts answer directly.

Citations arrive as `response.output_text.annotation.added` with a `url_citation`. They are shown
under the streaming answer only — they are not persisted, so reopening a chat shows whatever
inline Markdown links the model wrote.

Generated images arrive base64-encoded in `response.output_item.done` where the item type is
`image_generation_call` (a ~950 KB `data:` line, which the SSE parser handles). `ImageStore` writes
the PNG to `Application Support/Flare/images/` and the file name is persisted on the message, so
images survive a relaunch. Markdown images (`![](https://…)`) render too, via `ImageConfig`.

## Markdown rendering

`FlareUI/Sources/Markdown/` renders answers without a Markdown view package. `MarkdownDocumentBuilder`
parses with swift-markdown off the main thread and emits one attributed string per run of blocks,
with a `MarkdownTable` value wherever a table sits, because TextKit 2 cannot lay out tables.
`MarkdownTextView` is one TextKit 2 `NSTextView` per run; `setAttributedText` replaces only the
paragraphs from the first one that changed, so a streaming answer lays out a few lines per update.
`MarkdownLayoutFragment` draws the box behind code, the bar beside a quote and the rule, keyed by
the `.markdownBlock` attribute. `CodeHighlighter` colours a fenced block once its fence is closed,
through HighlightSwift, and caches per appearance.

These were settled by profiling and are easy to undo by accident:

- **`sizingOptions = []` on the panel's root `NSHostingView`.** Otherwise every update re-derives
  the hosting view's minimum, maximum and intrinsic sizes, which proposes extra widths to every
  text view, and each new width resizes the container and relays out the whole document.
- **`widthTracksTextView = false` and `isVerticallyResizable = false`.** SwiftUI sizes the view
  from `height(fittingWidth:)`. Left to itself the text view resets the container on every frame
  change, which throws away every fragment's layout, and redraws everything on every resize.
- **The streaming border and the shimmer are Core Animation layers.** The border is a conic
  gradient turned as a texture: shading it through a blur on every frame took a tenth of the main
  thread. Driven by a `TimelineView`, either one re-rendered the whole panel on every display
  frame: 2.4 s of main thread over a 14.6 s answer, 1.8 s with both in Core Animation.
- **A build lands at most every 33 ms (`MarkdownDocumentModel.buildInterval`).** One build per
  snapshot cost 4.5 s of main thread over a 14.6 s, 6 KB answer; capped, 2.7 s.

Measured on a 400-word reply: the old per-paragraph renderer held one core at 45 to 65 percent
for the whole stream and climbed with length; this one sits near 20 percent and stays flat.

## Conventions

- One type per file, Breeze-style, in `FlareUI/Sources/Settings/`.
- Settings chrome (`SettingsCard`, `ToggleCard`, `SelectableCard`, `SettingsForm`, `cardBand`,
  `settingFootnote`) is copied from Breeze; `AccountPane` mirrors Breeze's `LicensePane` band
  layout. Keep them aligned when Breeze changes.
- The panel has no toolbar and no sidebar by design. Navigation is `⌘K`; dismissal is the
  hotkey again or Escape. Escape is handled in `FlarePanel.cancelOperation`, not a SwiftUI
  `keyboardShortcut`: a focused `TextField` swallows the key first.
- The composer takes focus whenever the panel becomes key, whatever held it before, so the hotkey
  or a click on the panel is enough to start typing.
- "Show in Menu Bar" hides the status item (`NSStatusItem.isVisible`). Off, the hotkey is the way
  in and ⌘, in the panel is the way to Settings; the card says so.
- The panel hides when it resigns key, with three exemptions: a tracking `NSMenu` (the model
  picker lives inside the panel), a key Settings window, and the "Float on top" preference.
- The panel drags from any spot nothing else claims (`WindowDragGesture` on the content), not
  `isMovableByWindowBackground`: with that on, AppKit rebuilt the drag region over every text
  view on each layout, a third of the main thread while scrolling a long chat (2.0 s to 1.4 s per
  150 wheel events, 32 frames over 16 ms to none). It autosaves its frame under `FlarePanel`.
  The autosave name is set after the first placement, not at creation: naming at creation saves
  the empty starting frame, and the first show restores that
  corner instead of the pointer's screen. "Restore last position" in General turns the restore off.
  Without a frame to restore, `PanelPosition` (bottom left, bottom right, center) chosen in the
  Position cards decides where it opens, 16 points in from the edges, `PanelSize` (compact, half,
  full) how tall, with 12 points kept clear under the menu bar, and the Width slider how wide
  (`panelWidth`, 420 to 720 in five stops). A change resizes the panel at once. While Settings has
  the keyboard the panel itself hides. A ghost of it floats above every window where it would
  open, translucent, bordered and mouse-transparent, but only once a position, size or width
  control is touched (the pointer over the width slider counts); it follows every change, tracks
  the width knob while it is in hand, wears the slider's blue under the pointer, and fades three
  seconds after the last touch or with Settings. `windowDidBecomeKey` arrives before AppKit raises the window's key
  flag, so the ghost's guard tests visibility, not key status.
- A hand resize keeps its frame; `windowDidEndLiveResize` moves Width and Size to the nearest
  stops so Settings tells the truth. `PanelHost` adopts the values before the preferences change,
  so the change that follows finds nothing to apply and the frame is not snapped.
- The ⌘K palette fills the panel inside a 12-point margin, no width cap; the empty state shows the
  bolt, not a symbol. A restored frame keeps the size it saved.
- Settings copy stays short: tool toggles are chips ("Web", "Image"), and the Account pane is two
  cards, ChatGPT and API Key. Choosing ChatGPT adopts a Codex CLI session when one exists;
  choosing API Key reveals the field. A pasted key is trimmed and must answer a "hi" through
  `verifyAPIKey` before it is kept. The old Automatic value reads as whichever is set up.
- The composer's chip names the model and effort ("6.1 Sol · High") and opens a card over the
  composer with only the reasoning slider (`EffortSlider` on `StopSlider`, shared with the Width
  slider) and a link to Settings. The model and the provider are chosen in Settings, not here.
  Behind the card a material under a gradient mask frosts the chat from the bottom up. Escape, a
  click anywhere else, or three seconds after letting go put it away.
- The Providers pane is Compose's AI Provider page (`~/Developer/ldt/compose/compose-macos`,
  `ModelsSettingsView`) one to one: the credentials card for the chosen provider on top, a
  two-column grid of `ProviderCard`s, then `ModelCard`s with speed and intelligence bars from
  `ModelMetadata`, or `GroupedModelPicker` (typed id with VERIFY, search, vendors behind chevrons)
  once a listing passes twelve. Choosing a provider there makes it answer. `ReasoningCard` under
  the models is Flare's own. Card tones come from `CardBands`. Keep it aligned when Compose changes.
- Provider marks are LobeHub's static SVGs in `Flare/Resources/ProviderIcons.xcassets`, template
  rendered and tinted like text. Their path data was rewritten with the arc flags spaced out:
  CoreSVG rejects the compact `0 01-4.45` form and drew Gemini as a dot. Add a mark by fetching
  `https://unpkg.com/@lobehub/icons-static-svg@latest/icons/<name>.svg` and running it through the
  same normalisation; `ProviderIcon` maps hosts and local ports to names.
- Resources under `Flare/Resources/` are globbed at `tuist generate` time. A new file such as the
  `desktop.jpg` wallpaper thumbnail, one image for both appearances, is invisible to the build
  until the project is regenerated.
- Settings sections and cards sit on `.ultraThinMaterial` so the window's glass shows through; the
  grouped form's own section fill is opaque.
- The General pane's GIFs play through `AnimatedImageView`: frames decode on a queue of its own
  into the screen's colour space, and playback pauses while the window is hidden. An animating
  `NSImageView` decoded every frame in the main thread's commit (ImageIO's own animator too):
  the first Settings open took 317 ms of main thread, now 144 ms.
- Images reach the composer by drop on the panel, by paste, or by ⌘⇧C (`captureToChat`), which
  hides the panel, runs `screencapture -i`, attaches the shot and opens the panel again. The
  composer's field editor takes Command-V first and drops anything that is not text, so
  `AppDelegate` catches an image paste in a local key monitor and hands it to
  `FlareModel.addAttachment`. `ImageDrop` re-encodes everything as JPEG at 80 percent within 1024
  pixels, on white, so a Retina shot does not go out at full weight. Attachments go out as image
  parts and are stored on the user message as `|`-separated names in `imageFile`, which
  `MessageRow` shows as thumbnails and later turns re-send.
- `PanelScrim` sits at 30 percent black and 42 percent white: enough to read prose over a busy
  desktop, thin enough that the glass still shows.
- User messages have no bubble. The muted colour marks the turn, and both sides share one margin.
- A send while a reply streams joins `FlareModel.queue` (`QueuedMessage`, per thread) and shows in
  `QueueView` above the composer, numbered, each removable. When a reply finishes on its own the
  next queued message for the thread goes out; a stopped reply leaves the queue waiting behind a
  "Send Next" button. While streaming, the send button queues when text is typed and stops when
  the field is empty; ⌘. always stops.
- Every message offers **Copy** (Markdown stripped by `MarkdownPlainText`) and **Copy as
  Markdown** (the stored source, verbatim).
- `MarkdownRelay` feeds `StreamedMarkdownView` growing snapshots, not deltas, and replays the
  current text to late subscribers so a SwiftUI rebuild does not restart the render.
- Every assistant row renders through `StreamedMarkdownView` fed by `FlareModel.responseRelay(for:)`,
  stored messages included. The relay that streamed an answer stays in service after the row is
  stored, and the live placeholder shares the stored message's id, so the row keeps its identity
  and its parsed document across the handover. `MarkdownView` starts empty and re-parses on every
  text change, which made a long answer blink out the moment it finished.
- Reasoning renders in `ReasoningView` as a card after Grok's: a header with the elapsed time
  over a short window that follows the newest lines while summaries stream, then only the header,
  "Thought for Ns", once answer text starts. A click unfolds thoughts of up to 80 words under
  the card; longer ones, and thoughts still arriving, fill the panel with `ThoughtsView`. Escape
  or its close button returns to the chat, which stays alive underneath at zero opacity. The
  summaries title their sections with a bold line of their own, which the reasoning theme sets as
  a heading.
- Escape resolves in order: close the palette, close the thoughts, hide the panel
  (`setCancelHandler` in `AppDelegate`). Thinking runs from the first reasoning delta to the first answer delta and is stored
  in `chatMessages.reasoningSeconds`; zero means unknown and the header falls back to "Reasoning".
- The transcript is a plain `VStack` in a `ScrollView`, not a `LazyVStack`: lazy rows estimate the
  height of the text views underneath and jitter under a bottom anchor. It follows new content only
  while the reader is at the bottom, so scrolling up to read during a stream is never yanked back.
- Liquid Glass alone is unreadable over an arbitrary desktop; `PanelScrim` sits under panel content.
