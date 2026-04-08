# Supertonic TTS — Full-Featured App Roadmap

> Last updated: 2026-04-08  
> Scope: iOS TTS app + Safari/Chrome browser extension

---

## Vision

Turn the current CoreML proof-of-concept into a **production-ready "read-aloud" app** that:

1. Accepts arbitrary text typed or pasted by the user.
2. Fetches and extracts readable text from any pasted URL.
3. Receives text/URLs shared from other apps via a **Share Extension**.
4. Pairs with a **browser extension** (Safari on iOS/macOS, Chrome on desktop) so the user can send any article to the app or hear it read aloud in-browser.
5. Maintains a **reading history** so the user can replay past items and export audio.
6. Runs all TTS inference on-device with no network round-trip using the Supertonic 2 CoreML pipeline.

Reference product for UX inspiration: [TLDRL Lightning TTS](https://chromewebstore.google.com/detail/tldrl-lightning-tts-power/mdbiaajonlkomihpcaffhkagodbcgbme).

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                        iOS App                           │
│  ┌──────────┐  ┌────────────┐  ┌──────────────────────┐  │
│  │ Read Tab │  │  URL Tab   │  │   History Tab        │  │
│  └──────────┘  └────────────┘  └──────────────────────┘  │
│        │              │                   │               │
│        └──────────────┴───────────────────┘               │
│                       │                                   │
│              TTSViewModel (Combine)                       │
│                       │                                   │
│          ┌────────────┴────────────┐                      │
│          │ URLTextFetcher          │  HistoryManager      │
│          │ (URLSession + WKWebView)│  (JSON / Documents)  │
│          └─────────────────────────┘                      │
│                       │                                   │
│              TTSService (CoreML pipeline)                 │
│              AudioPlayer (AVFoundation)                   │
│              NowPlayingManager (MediaPlayer)              │
│              AudioExporter (AVAssetWriter)                │
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

| Tab | Content |
|-----|---------|
| **Read** | Text editor + Generate/Play controls |
| **URL** | URL input field → fetch → preview extracted text → speak |
| **History** | List of past TTS items with replay, export, and delete |
| **Settings** | Voice, speed, steps, compute units |

### 1.2 URL Text Fetcher (`URLTextFetcher.swift`) ✅

- Takes a `URL`, fetches raw HTML with `URLSession`.
- Strips tags, scripts, and navigation boilerplate using a lightweight regex-based parser.
- **WKWebView Readability fallback** — if the plain fetch returns less than ~300 characters, falls back to loading the URL in a headless `WKWebView` with a JS-based extraction pass.
- Exposes an `async throws` API consumed by `TTSViewModel`.

### 1.3 Clipboard Paste Button ✅

- "Paste from Clipboard" button in the Text tab and the URL tab.
- Detects whether clipboard content is a URL or plain text and routes accordingly.

### 1.4 Reading History (`HistoryManager.swift`) ✅

- Persists `HistoryItem` records (title, source URL or text snippet, date, audio file path) to JSON in the app's Documents directory.
- Displayed in the **History** tab with play/delete actions.
- Limited to the 50 most-recent items to cap storage.

### 1.5 iOS 26 Liquid Glass Design ✅

- `GlassComponents.swift` — design system: `GlassCard`, `GlassPrimaryButtonStyle`, `GlassSecondaryButtonStyle`, `GlassDestructiveButtonStyle`, `GlassTextField`, `GlassTextEditor`, `GlassSectionHeader`, `GlassStatusPill`, `GlassDivider`, `LiquidGlassBackground`.
- Warm white + burnt orange theme: cream background gradient (`#F9F6F0 → #F2ECE0`), burnt orange primary (`#CC5914`), warm amber secondary (`#F29919`).
- Browser extension popup restyled to match.

### 1.6 NowPlaying & Background Audio ✅

- `NowPlayingManager.swift` integrates with `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`.
- `AudioPlayer.swift` uses `.playback` `AVAudioSession` category for background audio.
- `UIBackgroundModes = audio` declared in the project.
- Mini NowPlaying bar floats above the tab bar with current title, progress, and remaining time.

### 1.7 NowPlaying Full-Screen Sheet ✅

- `NowPlayingSheet.swift` expands from the mini player bar to a full-screen card.
- Contains playback controls, animated waveform visualiser, and speed controls.

### 1.8 Waveform Visualiser ✅

- Animated bar-chart visualiser implemented in `GlassComponents.swift`.
- Driven by `AVAudioPlayer.updateMeters()` sampled on a 60 Hz timer.

### 1.9 Chrome Extension (Manifest V3) ✅

Located in `browser-extension/chrome/`.

**User flow:**
1. User clicks the extension icon while on an article.
2. Popup shows the page title and an estimated read time.
3. **▶ Read aloud** → content script extracts the article body and calls the Web Speech API.
4. **Send to iPhone** button copies the URL to clipboard or triggers a URL scheme.

### 1.10 GitHub Actions CI ✅

- `.github/workflows/ios-build.yml` — builds and unit-tests the iOS app on every push/PR targeting `main`.
- `.github/workflows/browser-extension-lint.yml` — ESLint + `web-ext lint` on every push/PR.

---

## Phase 2 — iOS Share Extension

### 2.1 Share Extension Target

- Bundle ID: `<AppBundleID>.ShareExtension`
- Activation: `NSExtensionActivationSupportsWebURLWithMaxCount = 1`, also `NSExtensionActivationSupportsText`.
- Shared app group (`group.<AppBundleID>`) so the extension writes a pending URL/text the host app picks up on next launch.
- Minimal "Send to Supertonic TTS" sheet UI with **Speak** and **Add to Queue** buttons.

### 2.2 URL Scheme Integration

- Custom scheme `supertonic-tts://speak?url=<encoded-url>` allows Safari and other apps to launch directly into the URL tab.
- `SceneDelegate` handles `openURL` and routes to the appropriate tab.

---

## Phase 3 — Browser Extension

### 3.1 Chrome Extension ✅

See §1.9 above. Complete and ready.

### 3.2 Safari Web Extension (iOS + macOS)

Located in `browser-extension/safari/` (Xcode target, not yet added).

- Built as an Xcode target (`SafariExtension`) inside the main app project.
- Shares `content.js` / `popup.*` from `browser-extension/shared/`.
- On iOS, tapping **Send** opens the Supertonic TTS app via the custom URL scheme.
- Bundled with the iOS app for App Store distribution.

```
browser-extension/
├── shared/
│   ├── content.js         # DOM reader (shared)
│   └── reader.js          # readability helper
├── chrome/                # complete ✅
└── safari/                # planned ⬜
    ├── SafariExtensionHandler.swift
    ├── SafariExtensionViewController.swift
    └── Resources/
        └── manifest.json
```

### 3.3 Extension Feature Matrix

| Feature | Chrome | Safari iOS | Safari macOS |
|---------|--------|------------|--------------|
| Read current page aloud (Web Speech API) | ✅ | ✅ | ✅ |
| Extract article text | ✅ | ✅ | ✅ |
| Send URL to iOS app | via clipboard | URL scheme | URL scheme |
| Voice / speed controls in popup | ✅ | ✅ | ✅ |
| Estimated read time | ✅ | ✅ | ✅ |
| Context menu "Read selection" | ⬜ | ⬜ | ⬜ |
| Extension icon artwork (proper PNG) | ⬜ | ⬜ | ⬜ |
| Dark mode popup theming | ⬜ | ⬜ | ⬜ |

---

## Detailed Improvement Backlog

> Items are ordered roughly by impact and complexity within each category.

### 🎧 Playback & Audio

| ID | Improvement | Details | Priority |
|----|-------------|---------|---------|
| P1 | **Pause / resume support** | `AVAudioPlayer` supports `pause()` + `play()` after pause, preserving position. Add `pausePlayback()`. Give `TTSViewModel` a tri-state: `.idle`, `.playing`, `.paused`. Update mini player UI. | High |
| P2 | **Skip ±15 s controls** | `player.currentTime += 15` / `-= 15`. Register `skipForwardCommand` / `skipBackwardCommand` in `NowPlayingManager`. Show ±buttons in the mini player bar and full-screen sheet. | High |
| P3 | **Sentence-level highlighting** | Split synthesised text into sentences, align TTS chunk boundaries, highlight the current sentence in the transcript view during playback. | Medium |
| P4 | **Audio volume normalisation** | Lightweight ITU-R BS.1770 or RMS-clamp pass on each WAV chunk before joining, to prevent sudden loud/quiet segments between sentences. | Medium |
| P5 | **Sleep timer** | "Stop after N minutes" option in Settings for bedtime reading. | Low |
| P6 | **Multiple-item queue** | Queue several history items or URLs for sequential playback. | Low |

### 🎨 UI / Design

| ID | Improvement | Details | Priority |
|----|-------------|---------|---------|
| U3 | **Haptic feedback** | `UIImpactFeedbackGenerator(.medium)` on Generate, Play, Stop, swipe-to-delete. `UINotificationFeedbackGenerator(.success/.error)` on generation complete/fail. | Medium |
| U4 | **Dynamic accent colour per voice** | Each voice gets a distinct gradient pair; the background aurora tints shift to match. | Low |
| U5 | **Animated generation progress** | Replace the plain `ProgressView` with a pulsing waveform that cycles through pipeline stages (DP → TE → VE → Voc) using named callbacks from `TTSService`. | Medium |
| U7 | **Landscape layout** | Optimise `ReadView` so the text editor and controls sit side-by-side in landscape instead of stacked. | Low |
| U8 | **Widget extension** | Home Screen widget showing the last-read title with a ▶ deep-link button. | Low |

### 🔗 Content & Networking

| ID | Improvement | Details | Priority |
|----|-------------|---------|---------|
| C2 | **PDF support** | Detect `application/pdf`; use `PDFKit` to extract text page-by-page. Feed concatenated text to the TTS pipeline. Show a PDF badge in the URL tab. | Medium |
| C3 | **RSS / podcast feed** | Parse RSS 2.0 / Atom feeds, present episodes as speakable items in a "Feed" sub-view under the URL tab. | Low |
| C4 | **Batch URL import** | Accept a plain-text file (one URL per line) via Files app or Share Extension; enqueue all articles. | Low |
| C5 | **Article caching** | Cache extracted text keyed by URL (TTL 24 h) in the Caches directory so re-reads skip the network. | Medium |

### 🧠 TTS & Model

| ID | Improvement | Details | Priority |
|----|-------------|---------|---------|
| T1 | **Long-text chunking improvements** | Use `NLTokenizer(.sentence)` instead of naïve splitting; merge short sentences (< 20 chars); add 400 ms silence on paragraph boundaries. | High |
| T2 | **On-the-fly speed preview** | Scrub the speed slider → immediately re-generate and play the first sentence as a preview. | Medium |
| T3 | **SSML support** | Honour `<break>`, `<emphasis>`, `<say-as>` tags in input text for expressive prosody control. | Medium |
| T4 | **Voice download manager** | In-app screen for downloading additional voice packages with progress and cached-size display. | Low |
| T5 | **Model cache status** | "Model info" badge in Settings showing which models are compiled and cached on-device. | Low |

### 📂 History & Data

| ID | Improvement | Details | Priority |
|----|-------------|---------|---------|
| H1 | **iCloud sync for history** | Mirror `HistoryItem` records to CloudKit private database so history persists across restores and syncs across devices. Audio files stored as `CKAsset`. | High |
| H2 | **Export audio as MP3 / M4B** | Export button per history row and in the NowPlaying sheet. Format picker: **MP3** (standard compatibility) or **M4B** (MPEG-4 audiobook with chapter markers, cover art, and metadata — ideal for long-form content). Implementation: `AVAssetWriter` with `AVFileTypeAppleM4A` (renamed `.m4b`) for M4B; `AVAudioConverter` with `kAudioFormatMPEGLayer3` (iOS 17+) for MP3. Hand off via `ShareLink` / `UIActivityViewController`. | High |
| H3 | **Full-text search in history** | `List` with `.searchable()` modifier filtering on `HistoryItem.title` and full text. | Medium |
| H4 | **Grouped history by date** | Section headers: "Today", "Yesterday", "This week", "Older". | Low |
| H5 | **Playback resume position** | Store last `player.currentTime` in `HistoryItem`; resume mid-audio on replay. | Medium |
| H6 | **Delete confirmation dialog** | `.confirmationDialog` before permanently deleting a history item and its audio file. | Low |

### 🔒 Privacy & Security

| ID | Improvement | Details | Priority |
|----|-------------|---------|---------|
| S1 | **Privacy Nutrition Label (`PrivacyInfo.xcprivacy`)** | Declare `NSPrivacyAccessedAPICategoryUserDefaults` and `NSPrivacyAccessedAPICategoryFileTimestamp`. Required for App Store submission. | High |
| S2 | **Certificate pinning for article fetches** | Optional toggle in Settings; pins known news-site CAs via `URLSession` delegate. | Low |
| S3 | **Clipboard access justification** | Add `NSPasteboardUsageDescription` and audit that all clipboard reads are user-triggered. | Medium |

### 🧪 Testing & CI

| ID | Improvement | Details | Priority |
|----|-------------|---------|---------|
| Q1 | **Unit tests for `URLTextFetcher`** | Fixture HTML files (news article, paywalled page, blog post, minimal content). Assert `extractReadableText` returns expected plain text. | High |
| Q2 | **Unit tests for `HistoryManager`** | Test `add`, `remove`, `clearAll`, persistence round-trip, 50-item cap. | High |
| Q3 | **Snapshot tests for glass components** | Use `swift-snapshot-testing` to prevent visual regressions in the design system. | Medium |
| Q4 | **UI tests (happy path)** | `XCUITest` flow: type text → Generate → wait → Play → assert mini player visible. | Medium |

### 🌐 Browser Extension

| ID | Improvement | Details | Priority |
|----|-------------|---------|---------|
| B1 | **Safari Web Extension target** | Add Xcode target using `safari-web-extension-converter` scaffold + shared JS. Generates `.appex` embedded in the iOS app bundle. | High |
| B3 | **Context menu "Read selection"** | Context-menu item in Chrome and Safari that reads only the highlighted text. | Medium |
| B4 | **Extension icon artwork** | Replace placeholder emoji icons with 16 / 48 / 128 px PNG assets matching the iOS app icon gradient. | High |
| B5 | **Dark mode popup theming** | `prefers-color-scheme: dark` variant in `popup.css` so the popup adapts to the browser's theme. | Medium |

---

## Comprehensive Improvement Plan

> Structured execution plan with phased targets, success criteria, and implementation strategy.

---

### Phase A — Playback & Stability Foundation
**Target: 6–8 weeks | Goal: App feels solid enough for daily personal use**

#### A1 — True Pause/Resume (P1)
**Why:** Stopping and losing position is a deal-breaker for long articles.  
**How:** Tri-state `TTSViewModel` enum (`.idle`, `.playing`, `.paused`). Replace `player.stop()` with `player.pause()` in `pausePlayback()`. Register `MPRemoteCommandCenter` pause/play commands correctly.

#### A2 — Skip Controls (P2)
**Why:** 15 s rewind / skip-forward is the standard for read-aloud apps.  
**How:** `skipBackwardCommand` + `skipForwardCommand` in `NowPlayingManager`. ±buttons in mini player and full-screen sheet.

#### A3 — Sentence-Aware Text Chunking (T1)
**Why:** Current chunking can clip mid-sentence, creating jarring audio joins.  
**How:** `NLTokenizer(.sentence)` pass in `TTSService`. Merge short sentences (< 20 chars). Extra 400 ms silence on double-newline paragraph boundaries.

#### A4 — Privacy Nutrition Label (S1)
**Why:** Required for App Store submission.  
**How:** Add `PrivacyInfo.xcprivacy`. Audit clipboard reads.

**Phase A exit criteria:** Pause/resume preserves position; skip controls on lock screen; no audible mid-sentence breaks; `PrivacyInfo.xcprivacy` passes App Store validation.

---

### Phase B — Content & Export
**Target: 4–6 weeks | Goal: The app handles any content and lets users keep what they hear**

#### B1 — PDF Support (C2)
**Why:** Many shared links point to PDFs (papers, reports, ebooks).  
**How:** Detect `Content-Type: application/pdf`; `PDFKit.PDFDocument` extracts text page-by-page. Add PDF badge to URL tab.

#### B2 — Audio Export: MP3 & M4B (H2)
**Why:** Users want to keep generated audio for offline listening in podcast apps, car stereos, or as audiobooks.  
**How:**
- **MP3:** `AVAudioConverter` with `kAudioFormatMPEGLayer3` (iOS 17+). Fallback: `AVAssetExportSession` to AAC/M4A for older OS.
- **M4B:** `AVAssetWriter` with `AVFileTypeAppleM4A`; add `AVMetadataItem` for title/artist; insert chapter markers at sentence-chunk boundaries; rename file to `.m4b`. Optionally embed cover art from the article's `og:image`.
- **UI:** "Export" button (share icon) on each `HistoryView` row and in `NowPlayingSheet`. Format picker (MP3 / M4B) presented as a confirmation sheet. File handed off via `ShareLink` (iOS 16+) or `UIActivityViewController`.

#### B3 — Article Caching (C5)
**Why:** Re-reading the same URL should be instant.  
**How:** Cache extracted text in Caches directory keyed by URL SHA-256, TTL 24 h.

#### B4 — Full-Text History Search (H3)
**Why:** History grows quickly; finding a past item by title is essential.  
**How:** `.searchable()` modifier on the History `List`.

**Phase B exit criteria:** PDF URLs speak cleanly; History rows have a working Export button; MP3 and M4B files open correctly in Files and third-party players; cached articles skip the network on re-read.

---

### Phase C — Platform Breadth
**Target: 6–8 weeks | Goal: The app reaches Safari and a Share Extension**

#### C1 — Safari Web Extension (B1)
**Why:** Safari is the default browser for iOS/macOS users.  
**How:** New Xcode target via `safari-web-extension-converter`. Reuses shared JS. Bundled in the iOS app for App Store distribution.

#### C2 — Share Extension (Phase 2)
**Why:** Users share articles from Safari directly into the app.  
**How:** `NSExtension` target matching `kUTTypeURL` + `kUTTypeText`. Minimal card UI; on "Read Now" opens app via URL scheme.

#### C3 — iCloud History Sync (H1)
**Why:** History should survive device restores.  
**How:** `CloudKit` private database for `HistoryItem` records. Audio files as `CKAsset`. `CKQuerySubscription` for push-driven sync.

#### C4 — Playback Resume Position (H5)
**Why:** Users should be able to pause, put the phone down, and resume exactly where they were.  
**How:** Write `player.currentTime` to `HistoryItem` on pause/stop. Seek to stored position on history replay.

**Phase C exit criteria:** Safari extension installable and functional on iOS; Share Extension opens from Safari; history syncs across two devices within 30 s; replay resumes at last position.

---

### Phase D — Quality & Polish
**Target: 4 weeks | Goal: Stable, well-tested, polished app**

#### D1 — Test Suite (Q1–Q4)
- `URLTextFetcherTests` with 6+ fixture HTML files.
- `HistoryManagerTests` covering add/remove/clear/persist/cap.
- `GlassComponentSnapshotTests` using `swift-snapshot-testing`.
- `XCUITest` happy-path flow.

#### D2 — Haptic Feedback (U3)
Generate/Play/Stop/delete all provide `UIImpactFeedbackGenerator` feedback; success/error use `UINotificationFeedbackGenerator`.

#### D3 — Animated Generation Progress (U5)
Replace plain `ProgressView` with a pulsing waveform that cycles through pipeline stages using named callbacks from `TTSService`.

#### D4 — Extension Icon Artwork (B4)
Replace placeholder emoji icons with proper 16 / 48 / 128 px PNG assets.

**Phase D exit criteria:** All tests pass in CI; haptics present throughout the app; generation progress is visually clear; extension has proper branding.

---

### Priority Matrix Summary

| Phase | Timeline | Key Deliverables | Risk |
|-------|----------|-----------------|------|
| A — Playback & Stability | 6–8 wks | Pause/resume, skip ±15s, chunking, PrivacyInfo | Low |
| B — Content & Export | 4–6 wks | PDF, MP3/M4B export, article caching, history search | Medium |
| C — Platform Breadth | 6–8 wks | Safari extension, Share extension, iCloud sync, resume position | High |
| D — Quality & Polish | 4 wks | Tests, haptics, animated progress, extension icons | Low |

---

## Milestones

| Milestone | Phase | Status |
|-----------|-------|--------|
| M1: Tab UI + URL fetch + History | 1 | ✅ Complete |
| M1.5: iOS 26 Liquid Glass design | 1 | ✅ Complete |
| M1.6: NowPlaying + background audio | 1 | ✅ Complete |
| M1.7: Full-screen NowPlaying sheet | 1 | ✅ Complete |
| M1.8: Waveform visualiser | 1 | ✅ Complete |
| M1.9: Chrome extension v1 | 1 | ✅ Complete |
| M1.10: GitHub Actions CI (iOS + extension) | 1 | ✅ Complete |
| M2: True pause/resume + skip controls | A | ✅ Complete |
| M3: Audio export (MP3 + M4B) | B | ✅ Complete |
| M4: Safari extension | C | ⬜ Planned |
| M5: Share Extension | C | ⬜ Planned |
| M6: iCloud history sync | C | ⬜ Planned |

---

## File Structure (target state)

```
supertonic-2-coreml/
├── .github/
│   └── workflows/
│       ├── ios-build.yml              ✅
│       └── browser-extension-lint.yml ✅
├── browser-extension/
│   ├── shared/
│   │   ├── content.js
│   │   └── reader.js
│   ├── chrome/                        ✅
│   │   ├── manifest.json
│   │   ├── background.js
│   │   ├── popup/
│   │   └── icons/
│   └── safari/                        ⬜ planned
├── docs/
│   ├── tts-app-roadmap.md   ← this file
│   ├── release-checklist.md
│   ├── compatibility-matrix.md
│   └── quant-matrix.md
├── supertonic2-coreml-ios-test/
│   ├── ContentView.swift              # tab UI + mini NowPlaying bar
│   ├── TTSViewModel.swift             # URL fetch + history + NowPlaying
│   ├── TTSService.swift
│   ├── AudioPlayer.swift              # background audio + progress callbacks
│   ├── AudioExporter.swift            # ⬜ planned — MP3 / M4B export
│   ├── URLTextFetcher.swift           # URLSession + WKWebView fallback
│   ├── HistoryManager.swift
│   ├── HistoryView.swift
│   ├── URLInputView.swift
│   ├── NowPlayingSheet.swift          # full-screen NowPlaying
│   ├── SettingsView.swift
│   ├── GlassComponents.swift          # iOS 26 liquid glass design system
│   ├── NowPlayingManager.swift        # MPNowPlayingInfoCenter
│   └── MemoryUsage.swift
└── supertonic2-coreml-ios-test.xcodeproj/
```

---

## Open Questions / Decisions Needed

| # | Question | Recommendation |
|---|----------|----------------|
| 1 | MP3 export: `AVAudioConverter` (iOS 17+) or always output M4A/AAC? | Default M4B; offer MP3 only on iOS 17+; show "Requires iOS 17" note otherwise |
| 2 | M4B chapter markers: per article chunk or per paragraph? | Per article chunk (each TTS segment = one chapter) |
| 3 | iCloud sync: `NSUbiquitousKeyValueStore` (simple) or `CloudKit` (full)? | `CloudKit` — supports large audio `CKAsset`; KV store has 1 MB total limit |
| 4 | Safari extension: scaffold with `safari-web-extension-converter` or write from scratch? | Use converter on existing Chrome extension as the starting point |
| 5 | Article extraction: current WKWebView fallback sufficient or add Readability.js? | Add minified Readability.js injection to WKWebView path for better article parsing |
