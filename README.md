# MediMask

MediMask is an iPhone app that detects and redacts protected health information (PHI) in healthcare-related photos before the image is shared.

## Docs

- [design.md](./design.md)
- [docs/team_split.md](./docs/team_split.md)
- [docs/architecture.md](./docs/architecture.md)
- [docs/demo_script.md](./docs/demo_script.md)

## Project Structure

```text
medimask/
  App/
  Models/
  Views/
  Services/
  Redaction/
  Utilities/
```

The Xcode project uses filesystem-synced groups, so new files added under `medimask/` should appear in Xcode automatically. This reduces `.pbxproj` conflicts compared with older Xcode project layouts.

## Getting Started

1. Open `medimask.xcodeproj` in Xcode.
2. Select the `medimask` scheme.
3. Run on an iOS Simulator or iPhone.
4. Use [design.md](./design.md) and [docs/team_split.md](./docs/team_split.md) as the source of truth for implementation.

## Team Workflow

1. Pick your assigned role from [docs/team_split.md](./docs/team_split.md).
2. Work on a branch named like `role-a-ui`, `role-b-melange`, `role-c-ocr`, or `role-d-redaction`.
3. Stay mostly within the files owned by your role.
4. If you need to change shared contracts, announce it first.
5. Keep the app buildable after each meaningful change.

For more detail, see [CONTRIBUTING.md](./CONTRIBUTING.md).
