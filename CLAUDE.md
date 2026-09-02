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

## Commands

```bash
tuist install                       # resolve packages (needed after Tuist/Package.swift edits)
tuist generate --no-open            # regenerate the workspace
xcodebuild build -workspace Flare.xcworkspace -scheme Flare -configuration Debug -destination 'platform=macOS'
xcodebuild test  -workspace Flare.xcworkspace -scheme FlareKit -destination 'platform=macOS'
```

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
- The license key, its activation and the trial start live in `license.json` beside `auth.json`,
  also at `0600`. They were in the Keychain, and every re-signed build asked for permission on
  launch; even a one-time read of the old items asks, so nothing is migrated.
- Two credentials, and the credential picks the endpoint. An API key wins when present because the
  user set it explicitly: it goes to `https://api.openai.com/v1/responses` and bills per token.
  Otherwise ChatGPT tokens go to `https://chatgpt.com/backend-api/codex/responses` with the headers
  Codex sends (`chatgpt-account-id`, `OpenAI-Beta: responses=experimental`, `originator: codex_cli_rs`).
  A ChatGPT subscription is rejected by the public API and an API key is rejected by the Codex
  backend, so the two are never interchangeable.
- A GUI launch inherits no shell environment, so `OPENAI_API_KEY` is only visible when Flare is run
  from a terminal. Settings reads it out of the login shell and stores a copy.
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

## Tools

The Codex backend accepts **`web_search`** and **`image_generation`**. It rejects
`code_interpreter`, `file_search` and `computer_use_preview`, and `local_shell` was removed.
Both `web_search` and the public API behave the same way here.

Web search is on by default. The guidance that makes the model search unprompted is appended to
the instructions at request time by `FlareModel.instructions(prompt:webSearch:)` rather than baked
into the editable system prompt, so a custom prompt keeps working and the toggle takes effect at
once. Measured behaviour: current facts, news, prices and new APIs search; arithmetic, writing help
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

Three things here were settled by profiling and are easy to undo by accident:

- **`sizingOptions = []` on the panel's root `NSHostingView`.** Otherwise every update re-derives
  the hosting view's minimum, maximum and intrinsic sizes, which proposes extra widths to every
  text view, and each new width resizes the container and relays out the whole document.
- **`widthTracksTextView = false` and `isVerticallyResizable = false`.** SwiftUI sizes the view
  from `height(fittingWidth:)`. Left to itself the text view resets the container on every frame
  change, which throws away every fragment's layout, and redraws everything on every resize.
- **The streaming border is a rasterised gradient rotated as a texture.** Shading a conic gradient
  through a blur on every frame took a tenth of the main thread while a reply streamed.

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
- The panel hides when it resigns key, with three exemptions: a tracking `NSMenu` (the model
  picker lives inside the panel), a key Settings window, and the "Float on top" preference.
- The panel drags from any spot nothing else claims (`WindowDragGesture` on the content) and
  autosaves its frame under `FlarePanel`. The autosave name is set after the first placement, not
  at creation: naming at creation saves the empty starting frame, and the first show restores that
  corner instead of the pointer's screen. "Restore last position" in General turns the restore off.
  Without a frame to restore, `PanelPosition` (bottom left, bottom right, center) chosen in the
  Position cards decides where it opens, 16 points in from the edges, and `PanelSize` (compact,
  half, full) how tall and how wide: 470, 540 and 620 points, with 12 points kept clear under the
  menu bar. A size change resizes the panel at once; a restored frame keeps the size it saved.
- Settings copy stays short: tool toggles are chips ("Web", "Image"), and the Account pane is two
  cards, ChatGPT and API Key. Choosing ChatGPT adopts a Codex CLI session when one exists;
  choosing API Key reveals the field. A pasted key is trimmed and must answer a "hi" through
  `verifyAPIKey` before it is kept. The old Automatic value reads as whichever is set up.
- The composer's model chip opens `ModelSlider`, after ChatGPT's picker: five stops
  (`ModelLevel`, Instant to Pro) that each pair a model with an effort. A pairing set elsewhere
  that matches no stop shows by name. Escape and a click anywhere else put it away.
- Resources under `Flare/Resources/` are globbed at `tuist generate` time. A new file such as the
  `desktop.jpg` wallpaper thumbnail, one image for both appearances, is invisible to the build
  until the project is regenerated.
- Settings sections and cards sit on `.ultraThinMaterial` so the window's glass shows through; the
  grouped form's own section fill is opaque.
- Images reach the composer by drop on the panel or by paste. The composer's field editor takes
  Command-V first and drops anything that is not text, so `AppDelegate` catches an image paste in
  a local key monitor and hands it to `FlareModel.addAttachment`. `ImageDrop` keeps PNG and JPEG
  under 1600 points as they are and re-encodes the rest as JPEG. Attachments go out as
  `input_image` data URLs and are stored on the user message as `|`-separated names in
  `imageFile`, which `MessageRow` shows as thumbnails and later turns re-send.
- `PanelScrim` sits at 30 percent black and 42 percent white: enough to read prose over a busy
  desktop, thin enough that the glass still shows.
- User messages have no bubble. The muted colour marks the turn, and both sides share one margin.
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
