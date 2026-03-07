# Supertonic-2 CoreML

CoreML‑optimized exports of **Supertonic 2** for iOS and macOS, plus a
fully-featured TTS app, a Chrome browser extension, CI workflows, and
packaging scripts for Hugging Face distribution.

## Repository structure

- `supertonic2-coreml-ios-test/`: Swift iOS app (CoreML TTS pipeline + tab UI).
- `browser-extension/`: Chrome Manifest V3 extension + shared JS reader.
- `models/supertonic-2/`: source models, CoreML artifacts, and resources.
- `scripts/`: conversion, benchmarking, smoke tests, and HF packaging.
- `docs/`: compatibility, quantization guidance, and [TTS app roadmap](docs/tts-app-roadmap.md).
- `hf/`: staging bundle for Hugging Face publishing.
- `.github/workflows/`: CI — iOS build + browser extension lint.

## iOS App — Features

The iOS app now includes four tabs:

| Tab | Description |
|-----|-------------|
| **Read** | Type or paste text → Generate → Play |
| **URL** | Paste any article URL → fetch text → speak |
| **History** | Replay past readings (saved to disk) |
| **Settings** | Voice, speed, steps, compute units |

### Paste from clipboard

Both the **Read** and **URL** tabs include a **Paste** button.  If the
clipboard contains a URL it is placed in the URL field; plain text goes
directly into the editor.

## Quickstart (iOS/macOS demo app)

1. Open `supertonic2-coreml-ios-test.xcodeproj`.
2. Ensure `SupertonicResources/` (or `models/supertonic-2/` resources) are
   bundled in the app target.
3. Build and run on device or simulator.

The CoreML pipeline lives in `supertonic2-coreml-ios-test/TTSService.swift`.

## Browser Extension (Chrome)

See [`browser-extension/README.md`](browser-extension/README.md) for full
details.  Quick start:

1. Open `chrome://extensions/` → enable **Developer mode**.
2. **Load unpacked** → select `browser-extension/chrome/`.
3. Click the 🔊 icon on any news article → **▶ Read aloud**.

The extension also has a **📱 Send to iPhone** button that opens the
`supertonic-tts://` URL scheme to hand the article off to the iOS app.

## CI / GitHub Actions

| Workflow | Trigger | Runner |
|----------|---------|--------|
| `ios-build.yml` | push/PR to `main` | `macos-latest` |
| `browser-extension-lint.yml` | changes to `browser-extension/` | `ubuntu-latest` |

## Required files (checklist)

Bundle the following into your app:

- CoreML packages for your chosen variant:
  - `duration_predictor_mlprogram.mlpackage`
  - `text_encoder_mlprogram.mlpackage`
  - `vector_estimator_mlprogram.mlpackage`
  - `vocoder_mlprogram.mlpackage`
- `SupertonicResources/voice_styles/` (or `models/supertonic-2/voice_styles/`)
- `SupertonicResources/embeddings/` (or `models/supertonic-2/embeddings/`)
- `SupertonicResources/onnx/unicode_indexer.json`
- `SupertonicResources/onnx/tts.json`

## Minimal iOS integration

```swift
// Example usage (see demo app for full UI + playback)
let service = try TTSService(computeUnits: .all)
let result = try service.synthesize(
    text: "Hello from CoreML!",
    language: .en,
    voiceName: "F1",
    steps: 20,
    speed: 1.0,
    silenceSeconds: 0.3
)
print("WAV file:", result.url)
```

To select a specific variant, update the CoreML folder name in
`TTSService` (the demo defaults to `coreml_int8`).

## Steps vs. quality (quick guide)

| Steps | Speed | Quality |
| --- | --- | --- |
| 10 | fastest | lowest |
| 20 | balanced | good |
| 30 | slowest | best |

## Troubleshooting

- **Missing resource error:** Ensure resources are bundled and named exactly.
- **Model not found:** Confirm the CoreML folder name (e.g., `coreml_ios18_int8_both`).
- **Fails to load on device:** Check iOS deployment target matches your variant.

## Model variants and quantization

See:
- `docs/compatibility-matrix.md` for OS/runtime expectations.
- `docs/quant-matrix.md` for quantization tradeoffs.

4‑bit variants are intentionally excluded due to quality.

## Hugging Face bundle

Build a HF‑ready bundle (>=8‑bit only):

```
python3 scripts/build_hf_bundle.py --clean
```

Outputs land in `hf/` with:
- `models/` (CoreML packages)
- `resources/` (voice styles, embeddings, indexers)
- `manifest.json` + `SHA256SUMS`
- `tests/` (CoreML smoke test)

## Developer notes (GitHub-specific)

- `hf_publish/` is ignored; it is a local HF bundle repo used for publishing.
- Use `scripts/build_hf_bundle.py` to regenerate artifacts.
- CoreML smoke tests require Python 3.12 + coremltools (see `AGENTS.md`).

## Smoke tests

Run a quick CoreML load/predict test:

```
python3 scripts/test_coreml_models.py
```

To point at a HF bundle layout:

```
python3 scripts/test_coreml_models.py --bundle-dir hf
```

## Attribution

This repository is derived from:
- Hugging Face: `Supertone/supertonic-2`
- GitHub: `supertone-inc/supertonic`

See `UPSTREAM.md` for provenance details.

## License

- Model weights: OpenRAIL‑M (see `models/supertonic-2/LICENSE`).
- Sample code: MIT (see `LICENSE`).
