# Supertonic TTS — Browser Extension

Read any article or webpage aloud using high-quality on-device TTS.  
Pairs with the Supertonic iOS app for seamless phone handoff.

---

## Chrome Extension

### Install (developer mode)

1. Open `chrome://extensions/`
2. Enable **Developer mode** (top right).
3. Click **Load unpacked** and select the `browser-extension/chrome/` folder.

### Features

| Feature | Notes |
|---------|-------|
| ▶ Read current page | Extracts article text, reads via Web Speech API |
| Voice / Speed / Pitch | Persisted across sessions |
| Estimated read time | Words ÷ 200 wpm |
| 📱 Send to iPhone | Opens `supertonic-tts://` URL scheme (requires iOS app) |
| Skip navigation/ads | Heuristic DOM scoring |

### Publish to Chrome Web Store

1. Zip the `chrome/` directory (not the parent).
2. Upload at <https://chrome.google.com/webstore/devconsole>.
3. Fill in the store listing and submit for review.

---

## Safari Extension (iOS + macOS)

The Safari extension reuses the shared JS from `shared/` and is built as an
Xcode app extension target inside the main iOS project.

### Build

Open `supertonic2-coreml-ios-test.xcodeproj` in Xcode and select the
`SafariExtension` scheme (to be added in a future milestone — see
`docs/tts-app-roadmap.md`).

---

## Shared JS

| File | Purpose |
|------|---------|
| `shared/reader.js` | Lightweight article extractor (no dependencies) |
| `shared/content.js` | Content script — message listener + Web Speech API wrapper |

---

## Roadmap

See [`docs/tts-app-roadmap.md`](../docs/tts-app-roadmap.md) for the full plan.
