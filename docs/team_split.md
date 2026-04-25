# MediMask Team Split

This document is the execution plan for the 4-person MediMask team.

It is written so that each teammate can say to Codex:

`I am doing Role A/B/C/D. Please read design.md and docs/team_split.md, then implement my role in stages.`

The purpose of this document is:

- to define exactly what each role owns
- to make parallel work safe
- to reduce overlap between teammates
- to give Codex enough context to work with minimal extra explanation

This document should be read together with:

- [design.md](/Users/leosun/personalProjects/medimask/design.md:1)

---

## 1. Product Reminder

MediMask is an iPhone app that detects and redacts protected health information in healthcare-related photos before the image is shared.

The MVP flow is:

1. user imports a photo
2. app processes the image locally
3. app detects faces and PHI-like text
4. app shows detected regions
5. user scrubs the photo
6. app exports a safe-to-share copy
7. demo proves it works offline

The app is:

- on-device
- offline-first
- focused on healthcare privacy
- a photo scrubber, not a diagnosis app

Do not expand scope into backend, login, cloud sync, or legal compliance logic.

---

## 2. Shared Team Rules

All 4 teammates must follow these rules.

### 2.1 Core technical rules

- The UI should call `ImageProcessingPipeline.process(image:)`
- Detection results should be returned as `RedactionRegion`
- All rectangles must be in **image coordinate space**
- The original image should remain local
- The app should remain usable even if some detection components are still mocked

### 2.2 Coordination rules

- Do not casually change shared model contracts without telling the team
- Do not refactor another role’s area unless integration requires it
- If a feature is risky, ship the simpler version early
- Optimize for a stable demo, not architectural perfection

### 2.3 Shared contract files

These files are the core shared interfaces:

- [RedactionRegion.swift](/Users/leosun/personalProjects/medimask/medimask/Models/RedactionRegion.swift:1)
- [ProcessingTimings.swift](/Users/leosun/personalProjects/medimask/medimask/Models/ProcessingTimings.swift:1)
- [DetectionResult.swift](/Users/leosun/personalProjects/medimask/medimask/Models/DetectionResult.swift:1)
- [OCRTextObservation.swift](/Users/leosun/personalProjects/medimask/medimask/Models/OCRTextObservation.swift:1)
- [ImageProcessingPipeline.swift](/Users/leosun/personalProjects/medimask/medimask/Services/ImageProcessingPipeline.swift:1)

If these change, everyone may be affected.

---

## 3. How To Use This Doc With Codex

Each teammate should prompt Codex with something close to:

`I am responsible for Role A in docs/team_split.md. Please read design.md and docs/team_split.md, inspect the current codebase, and implement my role in stages. Keep the project buildable after each stage, and stop only after the role has a solid MVP implementation.`

Or for another role:

`I am doing Role C. Please read design.md and docs/team_split.md, then implement the OCR + PHI Detection role in stages. Preserve the shared contracts and keep all rectangles in image coordinate space.`

Important:

- teammates should tell Codex which role they own
- Codex should inspect the repo before editing
- each teammate should stay mostly inside their owned files

---

## 4. Role Overview

The team split is:

1. **Role A: App Shell + Flow Integration**
2. **Role B: Face Detection + On-Device Model Integration**
3. **Role C: OCR + PHI Detection**
4. **Role D: Redaction + Overlay + Export + Demo Support**

Assignments:

1. **Role A:** RITCHIE
2. **Role B:** LEO
3. **Role C:** RICHARD
4. **Role D:** CONNOR

All 4 roles are real development roles.

Each role below is intentionally written with:

- mission
- files owned
- exact responsibilities
- staged tasks
- acceptance criteria
- fallback plan
- dependencies on other roles

That is the information Codex will need.

---

## 5. Role A: App Shell + Flow Integration

### 5.1 Mission

Own the user-facing app flow from photo import through review and result display.

Role A is responsible for making the app feel like a complete product shell even before all detection logic is fully finished.

If Role A is successful:

- the app launches into a coherent home screen
- the user can import a photo
- the user can trigger scanning
- the user can view detections
- the user can view the scrubbed output
- the app feels understandable and demoable

### 5.2 Primary owned files

- [MediMaskApp.swift](/Users/leosun/personalProjects/medimask/medimask/App/MediMaskApp.swift:1)
- [HomeView.swift](/Users/leosun/personalProjects/medimask/medimask/Views/HomeView.swift:1)
- [PhotoPickerView.swift](/Users/leosun/personalProjects/medimask/medimask/Views/PhotoPickerView.swift:1)
- [ReviewView.swift](/Users/leosun/personalProjects/medimask/medimask/Views/ReviewView.swift:1)
- [ResultView.swift](/Users/leosun/personalProjects/medimask/medimask/Views/ResultView.swift:1)
- [ProcessingStatusView.swift](/Users/leosun/personalProjects/medimask/medimask/Views/Components/ProcessingStatusView.swift:1)

### 5.3 Secondary collaboration files

- [ImageProcessingPipeline.swift](/Users/leosun/personalProjects/medimask/medimask/Services/ImageProcessingPipeline.swift:1)
- [DetectionOverlayView.swift](/Users/leosun/personalProjects/medimask/medimask/Views/Components/DetectionOverlayView.swift:1)

Role A may touch these for integration, but should avoid taking over another person’s logic.

### 5.4 Responsibilities

- Build the primary SwiftUI screens
- Own navigation and screen transitions
- Own photo import flow
- Own loading state and error state
- Call the pipeline from the UI
- Display detected regions and labels
- Display processing summary and timing
- Present the scrubbed result cleanly
- Keep the app stable while detection services evolve

### 5.5 Stage plan for Role A

#### Stage A1: App shell stability

Goal:

- app launches cleanly
- home screen is coherent
- imported photo can be shown

Tasks:

- clean up home screen copy
- ensure photo import is reliable
- make sure selected image state is handled correctly
- keep UI readable on mobile screen sizes

Acceptance criteria:

- user can open app
- user can import a photo
- imported image displays correctly

#### Stage A2: Scan flow and states

Goal:

- scanning action feels real even while services are still evolving

Tasks:

- wire scan button to the pipeline
- show `Scanning locally...` state
- show error state if processing fails
- prevent duplicate scan taps during active processing

Acceptance criteria:

- user taps `Scan Photo`
- app shows progress state
- app transitions into result or error cleanly

#### Stage A3: Review flow

Goal:

- user can review detected regions before scrubbing or while viewing output

Tasks:

- ensure review screen displays the image clearly
- integrate overlay rendering
- show labels and detection summary
- show counts by type if useful

Acceptance criteria:

- regions appear visually aligned enough for demo
- screen is understandable without explanation

#### Stage A4: Result flow

Goal:

- result screen feels like a complete output step

Tasks:

- present scrubbed image clearly
- show list or summary of what was detected
- show timing data if available
- make room for export/share action from Role D

Acceptance criteria:

- scrubbed output is obvious
- result screen can be used in a demo

### 5.6 What Role A should not overbuild

- do not spend too much time on fancy animations
- do not build a complex navigation architecture
- do not add camera capture unless MVP is already stable

### 5.7 Role A dependencies

Role A depends on:

- stable `DetectionResult`
- pipeline returning usable output
- overlay rectangles being in image coordinate space

### 5.8 Role A fallback plan

- if camera capture is hard, skip it
- if advanced comparison UI is hard, use simple original/review/result screens
- if visual polish takes too long, keep the layout simple and readable

---

## 6. Role B: Face Detection + On-Device Model Integration

### 6.1 Mission

Own the on-device model story, especially Melange integration and face detection.

This role is responsible for making the team’s “on-device AI” claim real.

If Role B is successful:

- face detection runs locally
- face regions are returned as `RedactionRegion`
- face boxes show up in the UI
- the team can explain what part uses Melange

### 6.2 Primary owned files

- [MelangeFaceDetector.swift](/Users/leosun/personalProjects/medimask/medimask/Services/MelangeFaceDetector.swift:1)
- [OptionalObjectDetector.swift](/Users/leosun/personalProjects/medimask/medimask/Services/OptionalObjectDetector.swift:1)
- [ImageProcessingPipeline.swift](/Users/leosun/personalProjects/medimask/medimask/Services/ImageProcessingPipeline.swift:1)

### 6.3 Secondary collaboration files

- [CoordinateMapper.swift](/Users/leosun/personalProjects/medimask/medimask/Redaction/CoordinateMapper.swift:1)
- [ReviewView.swift](/Users/leosun/personalProjects/medimask/medimask/Views/ReviewView.swift:1)

### 6.4 Responsibilities

- Integrate Melange if feasible for the MVP
- Build a face detection wrapper with a clean API
- Convert detector output into image-space rectangles
- Return `RedactionRegion` objects for faces
- Measure timing for face detection
- Add a fallback if Melange integration slips

### 6.5 Stage plan for Role B

#### Stage B1: Setup and validation

Goal:

- validate whether Melange can be integrated in the hackathon timeframe

Tasks:

- inspect SDK setup requirements
- get any sample or starter integration running
- document initial setup notes
- decide quickly whether fallback support is needed

Acceptance criteria:

- there is a clear path forward for Melange, or a quick fallback plan is in place

#### Stage B2: Detector wrapper

Goal:

- `detectFaces(in:)` returns face detections through a stable app-facing API

Tasks:

- implement `MelangeFaceDetector`
- define clean face detection output
- convert output into `RedactionRegion`

Acceptance criteria:

- one method returns face regions for a test image

#### Stage B3: Coordinate mapping correctness

Goal:

- face boxes align with the displayed image

Tasks:

- confirm detector coordinate format
- convert all outputs to image coordinate space
- test on obvious sample images

Acceptance criteria:

- face boxes appear in the right area in the review UI

#### Stage B4: Integration into pipeline

Goal:

- face detections are part of the main processing flow

Tasks:

- wire face detection into `ImageProcessingPipeline`
- provide timing data
- keep the pipeline stable

Acceptance criteria:

- app scan flow includes face detections

### 6.6 Critical rule for Role B

Role B must define this explicitly:

`What coordinate system does the detector output use, and how is it converted into image coordinate space?`

This should be written down clearly for the team.

### 6.7 Role B fallback plan

- if Melange blocks too long, use Apple Vision face detection
- if object detection is unstable, cut it
- prioritize one reliable face detector over multiple incomplete model paths

---

## 7. Role C: OCR + PHI Detection

### 7.1 Mission

Own the healthcare-specific text detection logic so the app redacts PHI, not just faces.

This role makes MediMask feel like a healthcare privacy tool instead of a generic photo masker.

If Role C is successful:

- OCR extracts text from demo images
- PHI detection flags obvious identifiers
- text detections are returned as `RedactionRegion`
- the app can detect labels like `DOB`, `MRN`, `PHONE`, and `EMAIL`

### 7.2 Primary owned files

- [VisionOCRService.swift](/Users/leosun/personalProjects/medimask/medimask/Services/VisionOCRService.swift:1)
- [PHIDetector.swift](/Users/leosun/personalProjects/medimask/medimask/Services/PHIDetector.swift:1)
- [OCRTextObservation.swift](/Users/leosun/personalProjects/medimask/medimask/Models/OCRTextObservation.swift:1)
- [ImageProcessingPipeline.swift](/Users/leosun/personalProjects/medimask/medimask/Services/ImageProcessingPipeline.swift:1)

### 7.3 Responsibilities

- integrate Apple Vision OCR
- return recognized text plus boxes
- detect PHI-like content from OCR output
- label detections meaningfully
- tune the logic against fake medical demo images
- provide stable text-based regions to the redaction pipeline

### 7.4 Stage plan for Role C

#### Stage C1: OCR baseline

Goal:

- OCR reads text from a test healthcare image

Tasks:

- replace placeholder OCR with Vision OCR
- log recognized text from a sample image
- return `OCRTextObservation` values

Acceptance criteria:

- OCR returns readable text and rectangles

#### Stage C2: OCR rectangle conversion

Goal:

- OCR boxes align with the image shown in the UI

Tasks:

- convert Vision normalized boxes to image coordinate space
- test against a document-style image
- validate orientation assumptions

Acceptance criteria:

- OCR boxes display roughly where the text appears

#### Stage C3: PHI rules

Goal:

- obvious demo PHI gets detected reliably

Tasks:

- implement regex rules
- implement label-based rules
- map text hits to region labels
- redact whole line boxes for MVP

Acceptance criteria:

- obvious identifiers like `DOB`, `MRN`, `Phone`, `Email`, `Patient`, `Rx`, and `Insurance ID` are detected in demo assets

#### Stage C4: Pipeline integration and tuning

Goal:

- OCR and PHI detection are stable enough for the demo

Tasks:

- wire OCR and PHI results into the pipeline
- tune detection behavior against fake demo images
- prefer reliability over precision

Acceptance criteria:

- text-based redaction works consistently on the main demo images

### 7.5 Role C fallback plan

- redact whole OCR lines instead of exact value substrings
- bias toward over-redaction for demo reliability
- use strong label-based matching if advanced heuristics are unstable

---

## 8. Role D: Redaction + Overlay + Export + Demo Support

### 8.1 Mission

Own the output stage of the product:

- how detections are visualized
- how the final redacted image is rendered
- how the result is exported

This role also helps ensure the final demo looks understandable and intentional.

If Role D is successful:

- overlay boxes and labels are readable
- scrubbed output clearly hides sensitive regions
- redaction style is visually convincing
- result export works

### 8.2 Primary owned files

- [ImageRedactor.swift](/Users/leosun/personalProjects/medimask/medimask/Redaction/ImageRedactor.swift:1)
- [CoordinateMapper.swift](/Users/leosun/personalProjects/medimask/medimask/Redaction/CoordinateMapper.swift:1)
- [DetectionOverlayView.swift](/Users/leosun/personalProjects/medimask/medimask/Views/Components/DetectionOverlayView.swift:1)
- [ResultView.swift](/Users/leosun/personalProjects/medimask/medimask/Views/ResultView.swift:1)

### 8.3 Secondary collaboration files

- [HomeView.swift](/Users/leosun/personalProjects/medimask/medimask/Views/HomeView.swift:1)
- [ReviewView.swift](/Users/leosun/personalProjects/medimask/medimask/Views/ReviewView.swift:1)
- [docs/demo_script.md](/Users/leosun/personalProjects/medimask/docs/demo_script.md:1)
- [docs/architecture.md](/Users/leosun/personalProjects/medimask/docs/architecture.md:1)
- [docs/judging_notes.md](/Users/leosun/personalProjects/medimask/docs/judging_notes.md:1)
- [demo-assets/README.md](/Users/leosun/personalProjects/medimask/demo-assets/README.md:1)

### 8.4 Responsibilities

- implement image redaction rendering
- tune black-box, blur, or pixelation behavior
- improve overlay box visuals and labels
- collaborate with Role A on export/share
- make the result screen feel clear and demoable
- support demo assets, screenshots, and slide-ready visuals

### 8.5 Stage plan for Role D

#### Stage D1: Redaction renderer baseline

Goal:

- the app can produce a visibly scrubbed output image from regions

Tasks:

- implement rectangle-based redaction
- handle text regions first
- make sure result image output is stable

Acceptance criteria:

- given a list of regions, the image comes back with those areas covered

#### Stage D2: Face/object redaction improvements

Goal:

- face redaction looks deliberate, not broken

Tasks:

- support blur or pixelation if feasible
- otherwise use strong black-box fallback
- differentiate styles by region type if helpful

Acceptance criteria:

- face redaction is visually understandable in the demo

#### Stage D3: Overlay quality

Goal:

- users can easily see what was detected before scrubbing

Tasks:

- improve label visibility
- improve box colors and spacing
- tune mapping behavior with review screen

Acceptance criteria:

- overlay looks readable on demo images

#### Stage D4: Export and demo output support

Goal:

- scrubbed image can leave the app cleanly

Tasks:

- collaborate on export/share flow
- verify result screen supports the final output
- prepare before/after screenshots for pitch and demo backup

Acceptance criteria:

- user can share or save a scrubbed image

### 8.6 Role D fallback plan

- if blur is hard, use black boxes everywhere
- if overlay becomes too complicated, keep it simple but readable
- if export is messy, use a minimal but working share flow

---

## 9. Cross-Role Dependencies

### 9.1 Role A depends on

- stable pipeline API
- detection regions that can be shown in the review UI
- enough output metadata to render results cleanly

### 9.2 Role B depends on

- normalized image input
- clear agreement about coordinate space

### 9.3 Role C depends on

- clear image coordinate rules
- demo assets with readable, high-contrast text

### 9.4 Role D depends on

- usable regions from face and OCR/PHI detection
- stable image coordinate mapping

### 9.5 Most important shared dependency

Everyone must preserve this assumption:

`all detection rectangles are in image coordinate space`

If this assumption breaks, UI overlays and redaction rendering will break across multiple roles.

---

## 10. Recommended Stage Sequence For The Whole Team

### Team Stage 1: End-to-end shell

Goal:

- import image
- run mock or partial detection
- show overlay
- show scrubbed result

Main roles:

- Role A
- Role D

Role B and Role C can continue working on real detection in parallel.

### Team Stage 2: OCR and PHI detection

Goal:

- text detection works on fake healthcare demo images

Main roles:

- Role C
- Role A for UI integration
- Role D for redaction quality

### Team Stage 3: Face detection

Goal:

- face detection works locally and is visible in app output

Main roles:

- Role B
- Role A for display
- Role D for rendering

### Team Stage 4: Demo lock

Goal:

- stop adding risky features
- stabilize the full user flow
- make screenshots and pitch support materials

Main roles:

- all roles, but mostly integration and bug-fixing

---

## 11. What To Cut First If Time Runs Out

Cut in this order:

1. live camera capture
2. object detection
3. blur/pixelation polish
4. before/after slider
5. manual keep/remove controls
6. visual polish extras

Do not cut these MVP essentials:

- photo import
- review flow
- OCR-based PHI redaction
- face redaction
- scrubbed output
- offline/on-device story

---

## 12. Role-Specific Codex Prompt Templates

These are suggested prompts teammates can paste into Codex.

### Role A prompt

`I am responsible for Role A in docs/team_split.md. Please read design.md and docs/team_split.md, inspect the current codebase, and implement Role A in stages. Focus on the app shell, photo import, scan flow, review flow, result flow, and integration with ImageProcessingPipeline. Keep the app buildable after each stage and preserve shared contracts.`

### Role B prompt

`I am responsible for Role B in docs/team_split.md. Please read design.md and docs/team_split.md, inspect the current codebase, and implement Role B in stages. Focus on Melange integration or fallback face detection, returning face RedactionRegion values in image coordinate space, and wiring face detection into ImageProcessingPipeline. Keep the app buildable after each stage and document coordinate assumptions.`

### Role C prompt

`I am responsible for Role C in docs/team_split.md. Please read design.md and docs/team_split.md, inspect the current codebase, and implement Role C in stages. Focus on Apple Vision OCR, OCRTextObservation output, PHI regex and label-based rules, and pipeline integration. Keep all rectangles in image coordinate space and prioritize reliable whole-line redaction for the MVP.`

### Role D prompt

`I am responsible for Role D in docs/team_split.md. Please read design.md and docs/team_split.md, inspect the current codebase, and implement Role D in stages. Focus on ImageRedactor, DetectionOverlayView, result rendering, coordinate mapping support, and export/share support. Keep the app buildable after each stage and prioritize clear, demo-friendly output.`

---

## 13. Final Notes

This split is intended to let each teammate work mostly independently while still contributing to the same product.

The project will go best if:

- each person stays within their role unless integration requires overlap
- the team preserves the shared contracts
- the team ships a reliable MVP before chasing stretch features

If everyone uses `design.md` plus this file as the source of truth, that should be enough context for each teammate to direct Codex effectively.
