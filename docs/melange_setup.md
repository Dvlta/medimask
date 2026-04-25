# Melange Setup for MediMask

This repo is prepared for Melange face detection, but the SDK and dashboard keys must be added in Xcode before the Melange path will run.

## What is already implemented in the repo

- `MelangeFaceDetector` prefers Melange when it is fully configured and available.
- If Melange is missing or fails to initialize, the app falls back to Apple Vision face detection.
- The app expects all detector outputs to end up in image coordinate space before reaching the UI.

## Required manual setup

### 1. Add the Melange iOS package

In Xcode:

1. Open `medimask.xcodeproj`
2. Go to `File` -> `Add Package Dependencies...`
3. Add `https://github.com/zetic-ai/ZeticMLangeiOS`
4. Link the `ZeticMLange` product to the `medimask` app target

ZETIC's iOS setup doc says Melange requires Xcode 14+, iOS 15+, and a physical device for meaningful testing because the simulator does not have Neural Engine hardware.

### 2. Get your Melange credentials

From the Melange dashboard:

- copy your `Personal Key`
- use the prebuilt face model key `google/MediaPipe-Face-Detection`, or your own uploaded model key
- optionally note a model version if your dashboard flow gives you one

### 3. Add the values to the app target's Info settings

The app reads these bundle keys at runtime:

- `MelangePersonalKey`
- `MelangeFaceModelName`
- `MelangeFaceModelVersion`

The simplest approach is:

1. Select the `medimask` target
2. Open the `Info` tab
3. Add those keys manually
4. Set:
   - `MelangePersonalKey` = your dashboard personal key
   - `MelangeFaceModelName` = `google/MediaPipe-Face-Detection`
   - `MelangeFaceModelVersion` = optional, leave blank if unused

If `MelangePersonalKey` is missing, the app will intentionally skip Melange and use Vision.

### 4. Add the Face Detection wrapper module

ZETIC's face detection tutorial shows iOS code importing:

- `ZeticMLange`
- `ext`

and then using `FaceDetectionWrapper()` for preprocessing and postprocessing.

This repo is already wired to use that API shape if the wrapper is present. You still need to bring the wrapper code into the project from ZETIC's sample app or any official wrapper package they provide.

Without the wrapper module, the app will keep falling back to Vision.

### 5. Build and test on a real iPhone

The first Melange model initialization downloads the model binary and caches it locally. Do one connected run first, then test the app again offline if you want the airplane-mode demo.

## Where the repo expects Melange

- Runtime config lookup: `medimask/Services/MelangeConfiguration.swift`
- Backend selection and Melange/Vision fallback: `medimask/Services/MelangeFaceDetector.swift`
- Timing and backend logging: `medimask/Services/ImageProcessingPipeline.swift`

## Relevant ZETIC docs

- iOS setup: https://docs.zetic.ai/platform-integration/ios/setup
- iOS basic inference: https://docs.zetic.ai/platform-integration/ios/basic-inference
- Face detection tutorial: https://docs.zetic.ai/tutorials/face-detection
- Melange overview: https://docs.zetic.ai/
