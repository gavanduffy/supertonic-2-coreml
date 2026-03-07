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

## Phase 1 — Core App Features (this PR)

### 1.1 Tab-Based Navigation

Replace the single-screen layout with a `TabView`:

| Tab | Content |
|-----|---------|
| **Read** | Text editor + Generate/Play controls (existing behaviour) |
| **URL** | URL input field → fetch → preview extracted text → speak |
| **History** | List of past TTS items with replay button |
| **Settings** | Voice, speed, steps, compute units |

### 1.2 URL Text Fetcher (`URLTextFetcher.swift`)

- Takes a `URL`, fetches raw HTML with `URLSession`.
- Strips tags, scripts, and navigation boilerplate using a lightweight regex-based parser (no third-party dependencies).
- Falls back to the raw body text if parsing yields less than 100 characters.
- Exposes an `async throws` API consumed by `TTSViewModel`.

### 1.3 Clipboard Paste Button

- "Paste from Clipboard" button in both the Text tab and the URL tab.
- Detects whether clipboard content is a URL or plain text and routes accordingly.

### 1.4 Reading History (`HistoryManager.swift`)

- Persists `HistoryItem` records (title, source URL or text snippet, date, audio file URL) to `UserDefaults` / JSON in the app's documents directory.
- Displayed in the **History** tab with play/delete actions.
- Limited to the 50 most-recent items to cap storage.

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

### 3.1 Chrome Extension (Manifest V3)

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

### 5.1 Playback Controls
- Lock-screen / Control Centre `NowPlaying` metadata.
- Background audio (`UIBackgroundModes: audio`).
- Skip-forward 30 s / rewind 15 s.
- Sentence-level progress indicator in the UI.

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
│   ├── ContentView.swift           # tab-based UI
│   ├── TTSViewModel.swift          # URL fetch + history
│   ├── TTSService.swift
│   ├── AudioPlayer.swift
│   ├── URLTextFetcher.swift        # NEW
│   ├── HistoryManager.swift        # NEW
│   ├── HistoryView.swift           # NEW
│   ├── URLInputView.swift          # NEW
│   ├── SettingsView.swift          # NEW
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
| M1: Tab UI + URL fetch + History | Phase 1 | ✅ In progress |
| M2: Share Extension skeleton | Phase 2 | ⬜ Planned |
| M3: Chrome extension v1 | Phase 3 | ✅ In progress |
| M4: Safari extension | Phase 3.2 | ⬜ Planned |
| M5: macOS target | Phase 4 | ⬜ Planned |
| M6: NowPlaying + background audio | Phase 5 | ⬜ Planned |
| M7: App Store submission | Phase 5.3 | ⬜ Planned |
