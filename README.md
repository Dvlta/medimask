# MediMask

**Protect patient privacy before you hit share.**

MediMask is an iPhone app that automatically detects and redacts protected health information (PHI) in healthcare-related photos — names, dates of birth, MRNs, faces, and more — so clinicians, patients, and caregivers can share images without leaking sensitive data. All processing runs **on-device**.

## Features

- **On-device PHI detection** — Apple Vision OCR + local rule-based PHI classifier. No photos leave the phone.
- **Face detection** — Melange-powered face detector for redacting identifying faces.
- **Interactive review** — Inspect every detected region before redaction; accept, reject, or adjust.
- **One-tap redaction** — Produces a safe-to-share image with redactions burned in.
- **Privacy by default** — No network calls required for the core pipeline.

## Pipeline

```text
Photo
  │
  ├──▶ Melange Face Detection
  │
  ├──▶ Apple Vision OCR
  │         │
  │         ▼
  │    Local PHI Rules
  │
  ▼
Redaction Planner
  │
  ▼
Safe-to-share Image
```

See [`docs/architecture.md`](./docs/architecture.md) for more.

## Requirements

- macOS with **Xcode 15+**
- iOS 17+ device or simulator
- Swift 5.9+
- (Optional) Melange model assets — see [`docs/melange_setup.md`](./docs/melange_setup.md)

## Getting Started

```bash
git clone https://github.com/Dvlta/medimask.git
cd medimask
open medimask.xcodeproj
```

Then in Xcode:

1. Select the `medimask` scheme.
2. Choose an iOS 17+ simulator or a connected iPhone.
3. Press **⌘R** to build and run.

## Project Structure

```text
medimask/
  App/          # App entry point (MediMaskApp.swift)
  Models/       # Domain models (PHI regions, detections, redaction plan)
  Views/        # SwiftUI screens (Home, PhotoPicker, Review, Result)
  Services/     # OCR, face detection, PHI rules, image pipeline
  Redaction/    # Redaction planner & renderer
  Utilities/    # Shared helpers
docs/           # Architecture, demo script, team split, Melange setup
demo-assets/    # Sample images for demos
```

The Xcode project uses filesystem-synced groups, so files added under `medimask/` appear in Xcode automatically, minimizing `.pbxproj` merge conflicts.

## Documentation

- [`design.md`](./design.md) — full product & technical design
- [`docs/architecture.md`](./docs/architecture.md) — pipeline overview
- [`docs/melange_setup.md`](./docs/melange_setup.md) — Melange model setup
- [`docs/team_split.md`](./docs/team_split.md) — role ownership
- [`docs/demo_script.md`](./docs/demo_script.md) — demo walkthrough
- [`docs/judging_notes.md`](./docs/judging_notes.md) — judging notes

## Privacy

MediMask is designed so that photos never leave the device during the core detection and redaction pipeline. Always verify the redacted output before sharing — no automated system is perfect.

## License

TBD.
