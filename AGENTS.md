# Agent Notes

## Repositories

- **GitHub (code/docs):** https://github.com/Nooder/supertonic-2-coreml — remote `origin`
- **Hugging Face (artifacts):** https://huggingface.co/Nooder/supertonic-2-coreml

## Key directories

| Path | What lives there |
|------|-----------------|
| `supertonic2-coreml-ios-test/` | Swift iOS app; CoreML TTS pipeline is `TTSService.swift` |
| `browser-extension/chrome/` | Chrome MV3 extension; Node/npm package |
| `models/supertonic-2/` | Source ONNX + CoreML artifacts + resources |
| `scripts/` | Python: conversion, smoke tests, HF packaging |
| `hf/` | Default staging output for `build_hf_bundle.py` (generated) |
| `hf_publish/` | **Git-ignored local HF repo checkout** used for pushing to HF |
| `SupertonicResources/` | Voice styles, embeddings, indexers bundled in the iOS app |
| `docs/` | `release-checklist.md`, `compatibility-matrix.md`, `quant-matrix.md` |

## Git LFS

`.gitattributes` tracks `*.mlpackage/**`, `*.mlmodel`, `*.mlmodelc/**`, `*.onnx`, `*.bin`, `*.wav`.  
Run `git lfs install` before any checkout that pulls model binaries.  
LFS is required on both GitHub and HF remotes.

## Critical rule: no 4-bit variants

`int4` / `linear4` models are **intentionally excluded** everywhere — from the HF bundle build script and from docs. Do not add them.

## Python smoke tests (requires Python 3.12 + coremltools + onnx)

```bash
uv venv --python 3.12 .venv
uv pip install -p .venv coremltools onnx numpy
.venv/bin/python scripts/test_coreml_models.py                  # repo layout
.venv/bin/python scripts/test_coreml_models.py --bundle-dir hf  # HF bundle layout
```

The script auto-detects repo vs. HF bundle layout. Uses `CPU_ONLY` compute units for portability.  
CoreML writes temp compilation files to `.coremltmp/` (created automatically).

## Browser extension (lint / validate)

```bash
cd browser-extension/chrome
npm ci
npm run lint                          # ESLint
npx web-ext lint --source-dir .       # validate manifest
```

## iOS Xcode build (macOS only)

```bash
# Build for simulator (matches CI)
xcodebuild \
  -project supertonic2-coreml-ios-test.xcodeproj \
  -scheme "supertonic2-coreml-ios-test" \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
  -configuration Debug \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  clean build

# Unit tests
xcodebuild test \
  -project supertonic2-coreml-ios-test.xcodeproj \
  -scheme "supertonic2-coreml-ios-testTests" \
  -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
  -configuration Debug \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

CI uses `xcpretty` for output formatting and uploads xcodebuild logs on failure.

## HF publishing workflow

1. Build bundle into the local HF repo checkout:
   ```bash
   python3 scripts/build_hf_bundle.py --clean --output hf_publish
   ```
   *(default `--output hf` stages into `hf/`; `hf_publish/` is the separate HF-origin repo)*

2. Push from `hf_publish/`:
   ```bash
   cd hf_publish
   git lfs install
   git add -A
   git commit -m "Update CoreML bundle"
   git push
   ```

   Alternative: `python3 scripts/sync_hf_repo.py --source hf_publish --target /path/to/hf-repo --clean`

3. Auth check: `hf auth whoami` (login via `hf auth login` if needed)

## GitHub release workflow

```bash
git add -A
git commit -m "Release vX.Y.Z"
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin main
git push origin vX.Y.Z
```

Update `CHANGELOG.md` and `UPSTREAM.md` before tagging.

## Release checklist

Follow `docs/release-checklist.md` — covers content sanity, artifact checks, smoke test, GitHub tag, and HF sync.

## Model card + docs

- HF model card source: `hf/README.md` (copied into HF bundle root)
- `docs/compatibility-matrix.md` — OS/runtime expectations per variant
- `docs/quant-matrix.md` — quantization tradeoffs

## Conversion scripts

`scripts/convert_onnx_mlprogram.py` converts ONNX → CoreML mlprogram (requires `coremltools`, `onnx2torch`, `torch`).  
`scripts/compress_coreml.py` applies post-conversion quantization.  
`scripts/benchmark_coreml.py` benchmarks loaded models.
