<p align="center">
  <img src="assets/readme/flare-icon.png" alt="Flare app icon" width="120" height="120">
  <h1 align="center">Flare for macOS</h1>
</p>

<p align="center">
  A floating AI chat for your Mac. Press ⌘⇧Space in any app, ask, and keep going. Every chat stays on your Mac.
</p>

<p align="center">
  <a aria-label="Download Latest Version" href="https://github.com/Aayush9029/Flare/releases/latest">
    <img alt="Download Latest Version" src="https://img.shields.io/badge/Download%20Mac%20Version-black.svg?style=for-the-badge&logo=apple">
  </a>
  <a aria-label="Website" href="https://aayush9029.github.io/Flare/">
    <img alt="Website" src="https://img.shields.io/badge/Website-white.svg?style=for-the-badge&logo=safari&logoColor=black">
  </a>
</p>

<p align="center">
  <img src="assets/readme/flare-demo.gif" alt="Flare: a floating quick chat for macOS" width="720">
</p>

## Install

```bash
brew install --cask aayush9029/tap/flare
```

Or download the DMG from [Releases](https://github.com/Aayush9029/Flare/releases/latest). Flare needs macOS 26 or later. Every build is signed and notarized.

## Providers

Sign in with ChatGPT and your subscription drives the chat, with no API key and no metered billing. Flare uses the same sign-in as the Codex CLI. You can also use your own key for OpenAI, Anthropic, Groq, Gemini, or OpenRouter, or any Chat Completions server such as Ollama or LM Studio.

## Build from source

You need Xcode 26 and [Tuist](https://tuist.dev).

```bash
git clone https://github.com/Aayush9029/Flare.git
cd Flare
tuist install
tuist generate
```

Run the `Flare` scheme. To sign with your own team, change `DEVELOPMENT_TEAM` in `Project.swift`.

## License

[MIT](LICENSE)
