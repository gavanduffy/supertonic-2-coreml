# Changelog

## Unreleased

- Fix CI: add `browser-extension/chrome/package-lock.json` so the npm cache step in `browser-extension-lint.yml` can resolve dependencies.
- Fix CI: add `browser-extension/.eslintrc.json` configuring ESLint for browser/WebExtension environments so `npm run lint` passes.
- Add `node_modules/` to root `.gitignore` to prevent build artifacts being committed.
- Remove accidentally-committed `node_modules/` from git tracking.
- Add tab-based UI: Read, URL, History, Settings tabs.
- Add `URLTextFetcher` — fetch and extract article text from any URL.
- Add `HistoryManager` — persist and replay the 50 most-recent TTS items.
- Add paste-from-clipboard button in Read and URL tabs.
- Add Chrome Manifest V3 browser extension (`browser-extension/chrome/`).
- Add shared JS article reader (`browser-extension/shared/reader.js`).
- Add GitHub Actions workflows: iOS build (`ios-build.yml`) and extension lint (`browser-extension-lint.yml`).
- Add comprehensive TTS app roadmap (`docs/tts-app-roadmap.md`).
- Full iOS 26 "liquid glass" UI overhaul: `GlassComponents.swift` design system (GlassCard, GlassPrimaryButtonStyle, GlassSecondaryButtonStyle, LiquidGlassBackground, GlassTextField, GlassTextEditor, GlassSectionHeader, GlassStatusPill, GlassDivider, GlassDestructiveButtonStyle).
- Add `NowPlayingManager.swift` — lock-screen / Control Centre NowPlaying metadata and MPRemoteCommandCenter handlers.
- Add background audio via `AVAudioSession` `.playback` category and `UIBackgroundModes = audio` in project settings.
- Add proper pause/resume: `pausePlayback()`, `resumeOrPlay()` in TTSViewModel; mini NowPlaying bar with progress indicator.
- Add `HistoryView` with replay, edit-load, and delete actions.
- Add `SettingsView` with voice/language picker, diffusion steps stepper, speed/silence sliders, compute-units picker, and model-load info card.
- Expand roadmap backlog (`docs/tts-app-roadmap.md`) with 35+ itemised improvements across Playback, UI, Networking, TTS, History, Privacy, Testing, Browser Extension, and Distribution categories.

## 0.1.0 - 2026-01-19

- Add Hugging Face bundle tooling and manifest generation.
- Add CoreML compatibility and quantization docs.
- Add HF model card and attribution notes.
