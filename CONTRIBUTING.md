# Contributing

This repo is being developed in parallel by a 4-person hackathon team. The main goal is to reduce merge conflicts and keep the app demoable at all times.

## Source of Truth

Read these first:

- [design.md](./design.md)
- [docs/team_split.md](./docs/team_split.md)

## Branching

Use small role-based branches:

- `role-a-ui`
- `role-b-face-detection`
- `role-c-ocr-phi`
- `role-d-redaction-output`

If you create a temporary branch for a specific task, keep it narrow, for example:

- `role-a-export-flow`
- `role-c-ocr-box-mapping`

## Ownership Boundaries

Default ownership:

- Role A: `medimask/App`, `medimask/Views`
- Role B: `medimask/Services/MelangeFaceDetector.swift`, model-related integration in `medimask/Services`
- Role C: `medimask/Services/VisionOCRService.swift`, `medimask/Services/PHIDetector.swift`, OCR-related models
- Role D: `medimask/Redaction`, `medimask/Views/Components/DetectionOverlayView.swift`, result/export support

Shared files:

- `medimask/Services/ImageProcessingPipeline.swift`
- `medimask/Models/*`
- `design.md`
- `docs/team_split.md`

Do not change shared files casually. If a shared contract needs to move, tell the team first.

## Merge Conflict Reduction Rules

1. Prefer adding new files under your owned folder instead of editing someone else’s files.
2. Do not reorder unrelated code or run broad formatting-only edits across the repo.
3. Keep commits narrow and role-specific.
4. Merge frequently instead of holding large long-lived branches.
5. If two roles need the same file, coordinate before editing it.

## Xcode Notes

This project uses filesystem-synced groups. In practice, this means:

- adding files under `medimask/` usually does not require manual project file edits
- fewer `.xcodeproj/project.pbxproj` conflicts than older Xcode projects

Still avoid unnecessary edits to:

- `medimask.xcodeproj/project.pbxproj`

## Codex Workflow

Suggested prompt format:

`I am responsible for Role A in docs/team_split.md. Please read design.md and docs/team_split.md, inspect the codebase, and implement my role in stages while keeping the app buildable.`

Ask Codex to:

- inspect first
- stay in owned files
- preserve shared contracts
- verify the app still builds after changes

## Definition of Done

A task is in good shape when:

- it matches the assigned role
- it keeps the app building
- it does not break shared contracts
- it includes only relevant file changes
- another teammate can merge it without guessing what changed
