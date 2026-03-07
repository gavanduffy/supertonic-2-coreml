# Supertonic TTS — Full-Featured App Roadmap

> Last updated: 2026-03-07  
> Scope: iOS TTS app + Safari/Chrome browser extension

---

## Vision

Turn the current CoreML proof-of-concept into a **production-ready "read-aloud" app** that:

1. Accepts arbitrary text typed or pasted by the user.
2. Fetches and extracts readable text from any pasted URL.
3. Receives text/URLs shared from other apps via a **Share Extension**.
4. Pairs with a **browser extension** (Safari on iOS/macOS, Chrome on desktop) so the user can send any article to the app or hear it read aloud in-browser.
5. Maintains a **reading history** so the user can replay past items.
6. Runs all TTS inference on-device with no network round-trip using the Supertonic 2 CoreML pipeline.

Reference product for UX inspiration: [TLDRL Lightning TTS](https://chromewebstore.google.com/detail/tldrl-lightning-tts-power/mdbiaajonlkomihpcaffhkagodbcgbme).

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                       iOS / iPadOS App                   │
│  ┌──────────┐  ┌────────────┐  ┌──────────────────────┐  │
│  │ Text Tab │  │  URL Tab   │  │   History Tab        │  │
│  └──────────┘  └────────────┘  └──────────────────────┘  │
│        │              │                   │               │
│        └──────────────┴───────────────────┘               │
│                       │                                   │
│              TTSViewModel (Combine)                       │
│                       │                                   │
│          ┌────────────┴────────────┐                      │
│          │ URLTextFetcher          │  HistoryManager      │
│          │ (URLSession + parser)   │  (SwiftData / JSON)  │
│          └─────────────────────────┘                      │
│                       │                                   │
│              TTSService (CoreML pipeline)                 │
│              AudioPlayer (AVFoundation)                   │
│              NowPlayingManager (MediaPlayer)              │
└──────────────────────────────────────────────────────────┘
         ▲                              ▲
         │ Share Extension              │ App Group (shared container)
         │ (NSExtension)                │
         ▼                              │
 ┌──────────────────┐                   │
 │ Safari / Chrome  │ ──────────────────┘
 │ Browser Extension│   (universal clipboard / URL scheme)
 └──────────────────┘
```

---

## Phase 1 — Core App Features ✅

### 1.1 Tab-Based Navigation ✅

Replace the single-screen layout with a `TabView`:

| Tab | Content |
|-----|---------|
| **Read** | Text editor + Generate/Play controls (existing behaviour) |
| **URL** | URL input field → fetch → preview extracted text → speak |
| **History** | List of past TTS items with replay button |
| **Settings** | Voice, speed, steps, compute units |

### 1.2 URL Text Fetcher (`URLTextFetcher.swift`) ✅

- Takes a `URL`, fetches raw HTML with `URLSession`.
- Strips tags, scripts, and navigation boilerplate using a lightweight regex-based parser (no third-party dependencies).
- Falls back to the raw body text if parsing yields less than 100 characters.
- Exposes an `async throws` API consumed by `TTSViewModel`.

### 1.3 Clipboard Paste Button ✅

- "Paste from Clipboard" button in both the Text tab and the URL tab.
- Detects whether clipboard content is a URL or plain text and routes accordingly.

### 1.4 Reading History (`HistoryManager.swift`) ✅

- Persists `HistoryItem` records (title, source URL or text snippet, date, audio file URL) to `UserDefaults` / JSON in the app's documents directory.
- Displayed in the **History** tab with play/delete actions.
- Limited to the 50 most-recent items to cap storage.

### 1.5 iOS 26 Liquid Glass Design ✅

- `GlassComponents.swift` — design system providing `GlassCard`, `GlassPrimaryButtonStyle`, `GlassSecondaryButtonStyle`, `GlassDestructiveButtonStyle`, `GlassTextField`, `GlassTextEditor`, `GlassSectionHeader`, `GlassStatusPill`, `GlassDivider`, and `LiquidGlassBackground`.
- All views redesigned with translucent `.ultraThinMaterial` cards, frosted glass panels, aurora gradient backgrounds, and vibrant gradient accent buttons.
- Browser extension popup restyled to match the liquid glass aesthetic.

### 1.6 NowPlaying & Background Audio ✅

- `NowPlayingManager.swift` integrates with `MPNowPlayingInfoCenter` (lock screen metadata) and `MPRemoteCommandCenter` (remote play/pause/stop controls).
- `AudioPlayer.swift` uses `.playback` `AVAudioSession` category for background audio.
- `UIBackgroundModes = audio` declared in `project.pbxproj`.
- Mini NowPlaying bar floats above the tab bar showing current title, progress bar, and remaining time.

---

## Phase 2 — iOS Share Extension

### 2.1 Share Extension Target

- Bundle ID: `<AppBundleID>.ShareExtension`
- Activation: `NSExtensionActivationSupportsWebURLWithMaxCount = 1`, also `NSExtensionActivationSupportsText`.
- Shared app group (`group.<AppBundleID>`) so the extension can write a pending URL/text that the host app picks up on next launch.
- The extension UI shows a minimal "Send to Supertonic TTS" sheet with a **Speak** button.

### 2.2 URL Scheme / Universal Link Integration

- Custom scheme `supertonic-tts://speak?url=<encoded-url>` allows Safari / other apps to launch the app directly to the URL tab.
- `AppDelegate`/`SceneDelegate` handles `openURL` and routes to the URL tab.

---

## Phase 3 — Browser Extension

### 3.1 Chrome Extension (Manifest V3) ✅

Located in `browser-extension/chrome/`.

```
browser-extension/chrome/
├── manifest.json          # MV3 manifest
├── background.js          # service worker — sends message to content script
├── content.js             # extracts article text from DOM
├── popup/
│   ├── popup.html
│   ├── popup.js           # "Read this page" button, voice/speed controls
│   └── popup.css
└── icons/
    ├── icon16.png
    ├── icon48.png
    └── icon128.png
```

**User flow:**
1. User clicks the extension icon while on a news article.
2. Popup shows the page title and an estimated read time.
3. User clicks **▶ Read aloud** → the content script extracts the article body and calls the Web Speech API (`SpeechSynthesis`) using the user's selected voice parameters.
4. An optional **Send to iPhone** button copies the URL to the clipboard and shows instructions (or triggers a native messaging host on macOS).

### 3.2 Safari Web Extension (iOS + macOS)

Located in `browser-extension/safari/`.

- Built as an Xcode target (`SafariExtension`) inside the main app project.
- Uses the same JavaScript (`content.js`, `popup.*`) as the Chrome extension via a shared `browser-extension/shared/` directory.
- On iOS, the extension opens the Supertonic TTS app via the custom URL scheme.
- On macOS, the extension can communicate with the macOS app target via native messaging.

```
browser-extension/
├── shared/
│   ├── content.js         # DOM reader (shared between Chrome + Safari)
│   └── reader.js          # readability helper
├── chrome/
│   ├── manifest.json
│   ├── background.js
│   ├── popup/
│   └── icons/
└── safari/
    ├── SafariExtensionHandler.swift
    ├── SafariExtensionViewController.swift
    └── Resources/
        ├── manifest.json  # Safari-flavoured MV3
        └── (symlinks or copies of shared JS)
```

### 3.3 Extension Features

| Feature | Chrome | Safari iOS | Safari macOS |
|---------|--------|------------|--------------|
| Read current page aloud (Web Speech API) | ✅ | ✅ | ✅ |
| Extract article text (Readability-lite) | ✅ | ✅ | ✅ |
| Send URL to iOS app | via clipboard | URL scheme | URL scheme |
| Voice / speed controls in popup | ✅ | ✅ | ✅ |
| Estimated read time | ✅ | ✅ | ✅ |
| Skip navigation / ads | ✅ | ✅ | ✅ |
| Background tab reading | ✅ | — | ✅ |

---

## Phase 4 — macOS App Target

- Add a macOS (Catalyst or native SwiftUI) target that shares the same Swift source as the iOS app.
- Exposes a menu bar extra for quick "Read clipboard" / "Read URL" access.
- Pairs with the Safari macOS extension for native-quality TTS (uses CoreML instead of Web Speech API).

---

## Phase 5 — Polish & Distribution

### 5.1 Playback Controls ✅ (partial)
- Lock-screen / Control Centre `NowPlaying` metadata. ✅
- Background audio (`UIBackgroundModes: audio`). ✅
- Mini player bar with progress and remaining time. ✅
- Skip-forward 30 s / rewind 15 s. ⬜
- Sentence-level progress indicator in the UI. ⬜

### 5.2 Accessibility
- VoiceOver labels on all controls.
- Dynamic type support.
- High-contrast mode support.

### 5.3 App Store Submission
- Privacy manifest (`PrivacyInfo.xcprivacy`): microphone not used; no analytics.
- App Review notes: TTS is on-device; no external data leaving device except user-initiated URL fetches.
- `NSAppTransportSecurity` allows arbitrary URL loads for article fetching (or scoped exceptions per domain).

---

## GitHub Actions CI/CD

All macOS/iOS build steps run on `macos-latest` runners.

### Workflow: `.github/workflows/ios-build.yml`

```yaml
trigger: push to main, PR targeting main
jobs:
  build-ios:
    runs-on: macos-latest
    steps:
      - checkout
      - select Xcode (latest stable)
      - xcodebuild -scheme supertonic2-coreml-ios-test
                   -destination 'platform=iOS Simulator,name=iPhone 16'
                   clean build test
      - upload test results artifact
  build-macos:          # future
    runs-on: macos-latest
    steps:
      - build macOS target (when added)
```

### Workflow: `.github/workflows/browser-extension-lint.yml`

```yaml
trigger: push / PR
jobs:
  lint-extension:
    runs-on: ubuntu-latest
    steps:
      - checkout
      - npm ci (in browser-extension/chrome)
      - eslint + web-ext lint
```

---

## File Structure (target state)

```
supertonic-2-coreml/
├── .github/
│   └── workflows/
│       ├── ios-build.yml
│       └── browser-extension-lint.yml
├── browser-extension/
│   ├── shared/
│   │   ├── content.js
│   │   └── reader.js
│   ├── chrome/
│   │   ├── manifest.json
│   │   ├── background.js
│   │   ├── popup/
│   │   │   ├── popup.html
│   │   │   ├── popup.js
│   │   │   └── popup.css
│   │   └── icons/
│   └── safari/          # Xcode references these
├── docs/
│   ├── tts-app-roadmap.md   ← this file
│   ├── compatibility-matrix.md
│   └── quant-matrix.md
├── supertonic2-coreml-ios-test/
│   ├── ContentView.swift           # tab-based UI + mini NowPlaying bar
│   ├── TTSViewModel.swift          # URL fetch + history + NowPlaying
│   ├── TTSService.swift
│   ├── AudioPlayer.swift           # background audio + progress callbacks
│   ├── URLTextFetcher.swift
│   ├── HistoryManager.swift
│   ├── HistoryView.swift
│   ├── URLInputView.swift
│   ├── SettingsView.swift
│   ├── GlassComponents.swift       # iOS 26 liquid glass design system
│   ├── NowPlayingManager.swift     # MPNowPlayingInfoCenter integration
│   └── MemoryUsage.swift
└── supertonic2-coreml-ios-test.xcodeproj/
```

---

## Open Questions / Decisions Needed

| # | Question | Recommendation |
|---|----------|----------------|
| 1 | Use `SwiftData` (iOS 17+) or JSON for history? | JSON for iOS 15 compat |
| 2 | Article extraction: pure Swift or embed Mozilla Readability.js via WKWebView? | Pure Swift first; add JS bridge if needed |
| 3 | Chrome extension TTS: Web Speech API or proxy to device? | Web Speech API for desktop; URL-scheme handoff for iOS |
| 4 | Code-sign identity for GitHub Actions builds? | Use self-signed for simulator; distribution cert via Secrets for device builds |
| 5 | Safari extension: separate app or embedded target? | Embedded as app extension target |

---

## Milestones

| Milestone | Target | Status |
|-----------|--------|--------|
| M1: Tab UI + URL fetch + History | Phase 1 | ✅ Complete |
| M1.5: iOS 26 Liquid Glass design | Phase 1 | ✅ Complete |
| M1.6: NowPlaying + background audio | Phase 5 | ✅ Complete |
| M2: Share Extension skeleton | Phase 2 | ⬜ Planned |
| M3: Chrome extension v1 | Phase 3 | ✅ Complete |
| M4: Safari extension | Phase 3.2 | ⬜ Planned |
| M5: macOS target | Phase 4 | ⬜ Planned |
| M6: Skip-forward / rewind controls | Phase 5 | ⬜ Planned |
| M7: App Store submission | Phase 5.3 | ⬜ Planned |

---

## Detailed Improvement Backlog

The following improvements have been identified by reviewing the full codebase. They are ordered roughly by impact and complexity.

### 🎧 Playback & Audio

| ID | Improvement | Details | Priority |
|----|-------------|---------|---------|
| P1 | **Pause / resume support** | `AVAudioPlayer` already supports `pause()` and `play()` after pause. Add a dedicated `pausePlayback()` that calls `player.pause()` instead of `stop()`, preserving position. TTSViewModel's `isPlaying` should gain a tri-state: `.idle`, `.playing`, `.paused`. | High |
| P2 | **Skip-forward 30 s / rewind 15 s** | Add `player.currentTime += 30` / `player.currentTime -= 15` helpers; register `skipForwardCommand` and `skipBackwardCommand` in `NowPlayingManager`. Show forward/back buttons in the mini player bar. | High |
| P3 | **Sentence-level word highlighting** | Split synthesised text into sentences/words, align timestamps from the TTS model output, and highlight the current sentence in the `ReadView` text editor during playback. | Medium |
| P4 | **Audio volume normalisation** | Run a lightweight loudness-normalisation pass (ITU-R BS.1770 or simpler RMS clamp) on each WAV chunk before joining, to prevent sudden loud or quiet segments between sentences. | Medium |
| P5 | **Sleep timer** | Add a "stop after N minutes" option in Settings so the app can be used as a bedtime reader without draining battery. | Low |
| P6 | **Multiple-item queue** | Allow the user to queue several history items or a batch of URLs for sequential playback without manual interaction. | Low |

### 🎨 UI / Design

| ID | Improvement | Details | Priority |
|----|-------------|---------|---------|
| U1 | **Full-screen Now Playing sheet** | Tapping the mini player bar expands to a full-screen card showing waveform visualisation, cover art, skip controls, speed picker, and text transcript. | High |
| U2 | **Waveform visualiser** | Real-time waveform or spectrum bars during playback, driven by `AVAudioPlayer`'s `updateMeters()` and drawn with SwiftUI `Canvas` or `Path`. | Medium |
| U3 | **Haptic feedback** | `UIImpactFeedbackGenerator` (.medium) on Generate, Play, Stop, and swipe-to-delete. `UINotificationFeedbackGenerator` (.success/.error) on generation success/failure. | Medium |
| U4 | **Dynamic accent colour per voice** | Assign each voice a distinct gradient pair; the app background aurora blob tints shift to match the selected voice. | Low |
| U5 | **Animated generation progress** | Replace the plain `ProgressView` spinner with a custom pulsing waveform animation that cycles through the four pipeline stages (DP → TE → VE → Voc) using named progress callbacks from `TTSService`. | Medium |
| U6 | **iPad multi-column layout** | On iPad, use a `NavigationSplitView` (iOS 16+) with the sidebar for Read/URL/History and a detail pane for the current item and playback controls. | Medium |
| U7 | **Landscape layout** | Optimise `ReadView` for landscape so the text editor and controls sit side-by-side instead of stacked. | Low |
| U8 | **Widget extension** | Home Screen widget showing the last read title with a ▶ deep-link button. | Low |

### 🔗 Content & Networking

| ID | Improvement | Details | Priority |
|----|-------------|---------|---------|
| C1 | **WKWebView Readability fallback** | For paywalled or JS-rendered pages where the plain HTTP fetch returns little text, fall back to loading the URL in a headless `WKWebView` and injecting Mozilla's Readability.js. | High |
| C2 | **PDF support** | Detect `application/pdf` responses; use `PDFKit` to extract text page-by-page and pass to the TTS pipeline. | Medium |
| C3 | **RSS / podcast feed** | Parse RSS 2.0 / Atom feeds from a given URL and present episodes as speakable items in a dedicated "Feed" sub-view under the URL tab. | Low |
| C4 | **Batch URL import** | Accept a plain-text file containing one URL per line (via the Files app or Share Extension) and enqueue all articles. | Low |
| C5 | **Caching fetched articles** | Cache the extracted text (keyed by URL, TTL 24 h) in the app's Caches directory so re-reads skip the network request. | Medium |

### 🧠 TTS & Model

| ID | Improvement | Details | Priority |
|----|-------------|---------|---------|
| T1 | **Long-text chunking improvements** | Current chunking is sentence-based; add paragraph-aware chunking to avoid splitting mid-sentence and improve prosody across paragraph boundaries. | High |
| T2 | **On-the-fly speed preview** | Allow the user to scrub the speed slider and immediately hear a short re-generated preview (e.g. the first sentence) without re-processing the full text. | Medium |
| T3 | **SSML support** | Honour a small subset of SSML (`<break>`, `<emphasis>`, `<say-as>`) typed or detected in the input text to give the user expressive control over prosody. | Medium |
| T4 | **Voice download manager** | If additional voice packages ship separately, provide an in-app download screen that shows available voices, download progress, and cached sizes. | Low |
| T5 | **Offline model caching status** | Add a "Model info" badge in Settings showing which models are compiled and cached on-device vs. need recompilation. | Low |

### 📂 History & Data

| ID | Improvement | Details | Priority |
|----|-------------|---------|---------|
| H1 | **iCloud sync for history** | Mirror `HistoryItem` records to `NSUbiquitousKeyValueStore` (small payload) or CloudKit so history persists across device restores and shares across user's devices. | High |
| H2 | **Export history item as audio file** | "Share" button on each history row that triggers `UIActivityViewController` with the `.wav` audio file, allowing AirDrop/Files export. | Medium |
| H3 | **Full-text search in history** | `List` with a `searchable()` modifier filtering on `HistoryItem.title` and `HistoryItem.fullText`. | Medium |
| H4 | **Grouped history by date** | Group rows by "Today", "Yesterday", "This week", "Older" sections with section headers. | Low |
| H5 | **Playback resume position** | Store the last playback `currentTime` in `HistoryItem` so the user can resume mid-audio rather than restarting from the beginning. | Medium |

### 🔒 Privacy & Security

| ID | Improvement | Details | Priority |
|----|-------------|---------|---------|
| S1 | **Privacy Nutrition Label (`PrivacyInfo.xcprivacy`)** | Declare accessed API categories: `NSPrivacyAccessedAPICategoryUserDefaults`, `NSPrivacyAccessedAPICategoryFileTimestamp`. Required for App Store submission from Spring 2024. | High |
| S2 | **Certificate pinning for article fetches** | Optional toggle in Settings; pins a set of well-known news-site CAs using `URLSession`'s `urlSession(_:didReceive:completionHandler:)` delegate. | Low |
| S3 | **Clipboard access justification** | Add `NSPasteboardUsageDescription` (for macOS Catalyst) and audit that clipboard reads are only triggered by explicit user action (no background reads). | Medium |

### 🧪 Testing & CI

| ID | Improvement | Details | Priority |
|----|-------------|---------|---------|
| Q1 | **Unit tests for `URLTextFetcher`** | Supply a set of fixture HTML files (news article, paywalled page, blog post) and assert that `extractReadableText` returns the expected plain text. | High |
| Q2 | **Unit tests for `HistoryManager`** | Test `add`, `remove`, `clearAll`, persistence round-trip, and the 50-item cap. | High |
| Q3 | **Snapshot tests for glass components** | Use `swift-snapshot-testing` to prevent visual regressions in `GlassCard`, `GlassPrimaryButtonStyle`, and other design-system components. | Medium |
| Q4 | **UI tests for the happy path** | `XCUITest` flow: type text → tap Generate → wait for audio → tap Play → assert mini player visible. | Medium |
| Q5 | **GitHub Actions iOS simulator build** | Implement the `ios-build.yml` workflow described above to gate PRs on a clean simulator build + unit tests. | High |
| Q6 | **Browser extension lint CI** | Implement `browser-extension-lint.yml` using `web-ext lint` to catch manifest errors and ESLint violations. | Medium |

### 🌐 Browser Extension

| ID | Improvement | Details | Priority |
|----|-------------|---------|---------|
| B1 | **Safari Web Extension target** | Add the Safari extension Xcode target using the same shared JS. Generates a `.appex` embedded in the iOS app bundle. | High |
| B2 | **Reading progress sync** | When the iOS app is active on the same Wi-Fi as the Mac, broadcast playback progress back to the Chrome extension via a local WebSocket so the extension icon shows a progress ring. | Low |
| B3 | **Context menu "Read selection"** | Add a context-menu item in both Chrome and Safari that reads only the highlighted text rather than the full article. | Medium |
| B4 | **Extension icon artwork** | Replace the placeholder emoji icons with proper 16 / 48 / 128 px PNG assets matching the iOS app icon gradient. | High |
| B5 | **Dark mode theming** | Add a `prefers-color-scheme: light` variant to `popup.css` so the extension popup adapts when the browser is in light mode. | Medium |

### 📦 Distribution

| ID | Improvement | Details | Priority |
|----|-------------|---------|---------|
| D1 | **App Store Connect metadata** | Screenshots (6.7", 6.1", 12.9" iPad), app preview video, keyword research, localised descriptions (EN, ES, FR, KO, PT). | High |
| D2 | **TestFlight beta** | Set up internal testing group; automate `.ipa` upload via `xcodebuild -exportArchive` + `altool` in GitHub Actions on push to `release/*`. | High |
| D3 | **Chrome Web Store listing** | Prepare store tile, description, screenshots, and privacy policy URL for the Chrome extension submission. | Medium |


---
