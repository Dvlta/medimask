# MediMask Design Document

## 0. One-Line Summary

**MediMask** is an iPhone app that runs on-device AI to detect and redact protected health information (PHI) in healthcare-related photos before the image is shared.

The goal is to help healthcare workers, caregivers, patients, and students avoid accidentally exposing sensitive information such as faces, wristbands, names, dates of birth, medical record numbers, prescription labels, charts, screens, badges, and other identifiers.

---

## 1. Product Goal

### 1.1 Problem

Healthcare photos often contain private information in the background.

Examples:

- A patient wristband visible in a bedside photo
- A name or date of birth on a printed discharge form
- A medical record number on a chart
- A face visible through a doorway
- A medication bottle label
- A monitor, whiteboard, badge, or room label
- A caregiver sharing a prescription photo with family
- A medical student or healthcare worker taking a work-related photo without noticing PHI

Uploading these images to a cloud model just to check privacy is not ideal because the image itself may already contain sensitive information.

### 1.2 Solution

MediMask processes the image locally on the phone.

Core workflow:

1. User takes or imports a photo.
2. App runs local detection.
3. App highlights sensitive regions.
4. User taps **Scrub Photo**.
5. App redacts the sensitive regions.
6. App exports a safe-to-share copy.
7. Demo proves it works in airplane mode.

### 1.3 Hackathon Positioning

This project is designed for the ZETIC mobile AI track.

The key ZETIC angle:

> Healthcare photos are privacy-sensitive by default, so the AI should run on-device. MediMask uses on-device inference to detect and redact PHI before the image leaves the phone.

### 1.4 What We Are Not Building

We are **not** building:

- A medical diagnosis app
- A HIPAA compliance guarantee
- A legal compliance platform
- A hospital MDM system
- A cloud image scanner
- A chatbot
- A live real-time AR camera first

We are building a focused, demoable, on-device healthcare photo scrubber.

---

## 2. MVP Definition

### 2.1 Required MVP Features

The MVP must support:

1. **Photo input**
   - Import from camera roll
   - Take a new photo if time allows

2. **On-device detection**
   - Face detection using Melange if possible
   - OCR using Apple Vision
   - PHI/PII detection using local Swift rules and regex

3. **Redaction**
   - Black-box sensitive text
   - Blur, pixelate, or black-box faces
   - Produce a scrubbed output image

4. **Review UI**
   - Show original image
   - Show detected sensitive regions
   - Show scrubbed image
   - Show labels like `FACE`, `DOB`, `MRN`, `PHONE`, `EMAIL`

5. **Export**
   - Save/share scrubbed image
   - Original remains local

6. **Demo proof**
   - Works in airplane mode
   - Show local processing timing
   - Show no backend is required

### 2.2 Stretch Features

Only build these after the MVP is stable:

- Object detection with Melange YOLO
- Detect screens, monitors, charts, badges, bottles, wristbands
- Live camera preview
- Before/after slider
- Manual tap-to-remove or tap-to-keep regions
- Local compliance receipt
- Hospital Mode preset
- TextAnonymizer model via Melange
- Local audit log

### 2.3 Cut Features

Do not build unless everything else is done:

- Account system
- Backend server
- Cloud sync
- Login
- Friend enrollment
- Face identity recognition
- Gaze detection
- Full hospital-room scene understanding
- MDM integration
- Real HIPAA/legal compliance logic
- Any diagnosis or medical advice

---

## 3. Target Users

### 3.1 Primary Users

#### Healthcare Workers

People who may take work-related photos on mobile devices and need to avoid exposing PHI.

Examples:

- Nurses
- Doctors
- Therapists
- Medical assistants
- Clinic staff

#### Caregivers and Patients

People who take photos of prescriptions, forms, discharge papers, or health-related documents and share them with family or providers.

#### Medical Students and Volunteers

People who may be around clinical settings and need a simple way to avoid accidental privacy leaks.

### 3.2 Best Hackathon Demo User

For the demo, the clearest user is:

> A healthcare worker or caregiver who wants to share a medical photo but does not notice that the image contains a patient name, DOB, MRN, and face in the background.

---

## 4. Tech Stack

### 4.1 Main App

- **Platform:** iOS
- **Language:** Swift
- **UI:** SwiftUI
- **IDE:** Xcode
- **Secondary editor:** VSCode/Codex for editing Swift files, docs, regex rules, and scripts
- **Device:** Real iPhone required for final testing

### 4.2 On-Device AI

- **ZETIC Melange iOS SDK**
  - Required for track alignment
  - Use for face detection first
  - Optional YOLO/object detection if time allows

Recommended Melange priority:

1. Face detection
2. YOLO/object detection
3. TextAnonymizer, only if easy to integrate

### 4.3 Apple Frameworks

- **Apple Vision**
  - `VNRecognizeTextRequest` for OCR
  - Optional fallback face detection with `VNDetectFaceRectanglesRequest`
- **PhotosUI**
  - Import images from camera roll
- **AVFoundation or UIImagePickerController**
  - Camera capture if time allows
- **UIKit / SwiftUI**
  - UI and image display
- **UIGraphicsImageRenderer**
  - Basic redaction rendering
- **Core Image**
  - Optional blur/pixelation upgrade

### 4.4 Backend

No backend for MVP.

Everything should work locally.

Optional future backend responsibilities:

- None for hackathon MVP
- Maybe encrypted backup or enterprise policy in future work

### 4.5 Repo Layout

Recommended structure:

```text
medimask/
  README.md
  design.md
  pitch.md

  MediMask/
    MediMask.xcodeproj
    MediMask/
      App/
        MediMaskApp.swift

      Models/
        RedactionRegion.swift
        DetectionResult.swift
        ProcessingTimings.swift

      Views/
        HomeView.swift
        PhotoPickerView.swift
        ReviewView.swift
        ResultView.swift
        Components/

      Services/
        ImageProcessingPipeline.swift
        VisionOCRService.swift
        PHIDetector.swift
        MelangeFaceDetector.swift
        OptionalObjectDetector.swift

      Redaction/
        ImageRedactor.swift
        CoordinateMapper.swift

      Utilities/
        ImageOrientationFixer.swift
        Logger.swift

  demo-assets/
    fake_patient_form.png
    fake_wristband.png
    fake_prescription_label.png
    fake_room_photo.png

  docs/
    architecture.md
    demo_script.md
    judging_notes.md
```

---

## 5. System Architecture

### 5.1 High-Level Pipeline

```text
User selects/takes image
        |
        v
Normalize image orientation and size
        |
        +------------------------------+
        |                              |
        v                              v
Melange Face Detection          Apple Vision OCR
        |                              |
        v                              v
Face regions                    Text observations
        |                              |
        |                              v
        |                       PHI Detector
        |                       regex + keywords
        |                              |
        +---------------+--------------+
                        |
                        v
              Redaction Planner
                        |
                        v
              Image Redactor
                        |
                        v
              Scrubbed Image
                        |
                        v
              Review / Export UI
```

### 5.2 Device Responsibilities

The phone handles:

- Image loading
- Image normalization
- Face detection
- OCR
- PHI detection
- Redaction planning
- Rendering
- Export
- Timing measurements

### 5.3 Cloud Responsibilities

For MVP:

- None

For pitch:

- Optional future encrypted policy sync
- Optional hospital admin configuration
- Never upload original images, face crops, OCR text, or unredacted photos

### 5.4 Why On-Device Matters

On-device processing is central because:

- Healthcare images may already contain PHI.
- Uploading an image for analysis may itself increase privacy risk.
- Mobile users need fast pre-share checks.
- The app should work offline.
- The original image should never leave the device.

---

## 6. Data Models and Integration Contracts

Everyone should use the same shared data models.

### 6.1 Region Type

```swift
enum RegionType: String, Codable {
    case face
    case phiText
    case object
    case unknown
}
```

### 6.2 Redaction Style

```swift
enum RedactionStyle: String, Codable {
    case blackBox
    case blur
    case pixelate
}
```

### 6.3 Redaction Region

```swift
struct RedactionRegion: Identifiable, Codable {
    let id: UUID
    let rect: CGRect
    let type: RegionType
    let label: String
    let confidence: Float
    let source: String
    let redactionStyle: RedactionStyle
}
```

Notes:

- `rect` should be in image coordinate space, not screen coordinate space.
- `label` examples: `FACE`, `DOB`, `MRN`, `PHONE`, `EMAIL`, `PATIENT ID`
- `source` examples: `melange-face`, `vision-ocr`, `phi-regex`, `melange-yolo`

### 6.4 Processing Timings

```swift
struct ProcessingTimings: Codable {
    let faceDetectionMs: Double
    let ocrMs: Double
    let phiDetectionMs: Double
    let redactionMs: Double
    let totalMs: Double
}
```

### 6.5 Processing Result

```swift
struct DetectionResult {
    let originalImage: UIImage
    let scrubbedImage: UIImage
    let regions: [RedactionRegion]
    let timings: ProcessingTimings
}
```

### 6.6 Pipeline API

All UI should call one function:

```swift
final class ImageProcessingPipeline {
    func process(image: UIImage) async throws -> DetectionResult {
        // 1. Normalize image
        // 2. Run face detection
        // 3. Run OCR
        // 4. Run PHI detector
        // 5. Combine regions
        // 6. Redact image
        // 7. Return result
    }
}
```

This is important because it lets each teammate work independently.

---

## 7. PHI Detection Rules

### 7.1 What to Detect

Start with:

- Patient name
- Date of birth
- Medical record number
- Patient ID
- Phone number
- Email address
- Street address
- Insurance/member ID
- Prescription/Rx number
- SSN-like pattern
- Dates near PHI labels
- Long identifier-like numbers

### 7.2 Label-Based Patterns

Most demo documents should use obvious labels.

Examples:

```text
Patient: Jane Smith
Name: Jane Smith
DOB: 03/14/1982
Date of Birth: 03/14/1982
MRN: A9283910
Medical Record Number: 19382910
Patient ID: PT-884219
Phone: (555) 293-1129
Email: jane.smith@example.com
Insurance ID: ZTX-88291
Rx #: RX-441928
Address: 123 Main Street
```

### 7.3 Regex Pattern Starter Set

```swift
let phiPatterns: [(label: String, regex: String)] = [
    ("EMAIL", #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#),
    ("PHONE", #"\b(\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b"#),
    ("DOB", #"\b(DOB|Date of Birth|Birth Date)\b[:\s]*\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#),
    ("MRN", #"\b(MRN|Medical Record|Medical Record Number)\b[:\s#-]*[A-Z0-9-]{4,}\b"#),
    ("PATIENT ID", #"\b(Patient ID|Patient #|Patient Number)\b[:\s#-]*[A-Z0-9-]{4,}\b"#),
    ("INSURANCE ID", #"\b(Insurance ID|Policy #|Policy Number|Member ID)\b[:\s#-]*[A-Z0-9-]{4,}\b"#),
    ("RX", #"\b(Rx|Prescription|Prescription #|Rx #)\b[:\s#-]*[A-Z0-9-]{4,}\b"#),
    ("SSN", #"\b\d{3}-\d{2}-\d{4}\b"#),
    ("DATE", #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#)
]
```

### 7.4 Keyword-Based Rules

If OCR sees any of these nearby, increase sensitivity:

```text
patient
dob
date of birth
mrn
medical record
insurance
policy
member id
rx
prescription
address
phone
email
ssn
chart
clinic
hospital
```

### 7.5 Demo Reliability Tip

For hackathon demo assets, make sure sensitive information is large, high contrast, and label-based.

Bad demo text:

```text
Jane 3/14 A9283
```

Good demo text:

```text
Patient: Jane Smith
DOB: 03/14/1982
MRN: A9283910
Phone: (555) 293-1129
```

The second one makes the OCR and regex pipeline much more reliable.

---

## 8. Redaction Strategy

### 8.1 Redaction Types

Use different redaction styles by region type.

| Region Type | Default Style | Reason |
|---|---|---|
| Face | Blur or pixelate | Looks natural and privacy-preserving |
| PHI text | Black box | Feels like formal redaction |
| Object | Blur or black box | Depends on object type |
| Unknown | Black box | Conservative fallback |

### 8.2 MVP Renderer

Use `UIGraphicsImageRenderer`.

Basic approach:

1. Draw original image.
2. For each PHI region, draw black rectangle.
3. For each face region, either:
   - draw black rectangle, or
   - apply blur if time allows
4. Return final image.

### 8.3 Optional Blur

If time allows, implement face blur using Core Image:

- Crop face region
- Apply Gaussian blur or pixellate filter
- Composite back onto image

### 8.4 Overlay Rendering

The review screen should show detection boxes before redaction.

Suggested colors:

- Red outline: PHI text
- Yellow outline: face
- Blue outline: object

Do not spend too much time on design. Basic labeled boxes are enough.

---

## 9. Coordinate Mapping

Coordinate mapping is one of the highest-risk bugs.

### 9.1 Rule

All detection services should return rectangles in **image coordinate space**.

Image coordinate space means:

```text
origin: top-left of actual image
width: image pixel width
height: image pixel height
```

### 9.2 Why This Matters

SwiftUI display coordinate space may differ from image coordinate space due to:

- Aspect fit scaling
- Image orientation
- Device rotation
- Pixel vs point units
- Vision normalized bounding boxes
- Camera orientation metadata

### 9.3 Vision OCR Coordinates

Apple Vision returns normalized bounding boxes with origin at bottom-left.

Need to convert to image coordinates:

```text
x = boundingBox.minX * imageWidth
y = (1 - boundingBox.maxY) * imageHeight
width = boundingBox.width * imageWidth
height = boundingBox.height * imageHeight
```

### 9.4 Melange Coordinates

Confirm what the Melange face detector returns.

Possible formats:

- Pixel coordinates
- Normalized coordinates
- Center x/y + width/height
- Model input coordinates

Role B must document the actual format.

### 9.5 Fallback

If coordinate mapping is wrong, make the demo simpler:

- Process images with fixed orientation
- Use portrait-only test assets
- Use obvious documents centered in frame
- Avoid rotated photos
- Normalize all images to upright orientation before detection

---

## 10. Per-Team-Member Responsibilities

Assuming a 4-person team where all 4 people own real development work and each person can use Codex to implement their track in stages.

---

# Role A: App Shell and Flow Integration Lead

## Mission

Own the app experience from input to result.

The app must feel like a real product, even if the underlying detector is simple.

## Responsibilities

### Core Responsibilities

- Create Xcode project
- Configure SwiftUI app
- Build app navigation
- Implement photo picker
- Implement camera capture if time allows
- Build review screen
- Build result screen
- Wire the UI to `ImageProcessingPipeline`
- Implement export/share flow
- Add loading states
- Add error states
- Add airplane-mode/local-processing messaging

### Files Owned

```text
MediMaskApp.swift
HomeView.swift
PhotoPickerView.swift
ReviewView.swift
ResultView.swift
ProcessingStatusView.swift
ShareSheet.swift
```

### Stage 1 Tasks: Project Setup

- Create Xcode project
- Set app name: `MediMask`
- Use SwiftUI
- Set iOS deployment target
- Add required permissions in `Info.plist`
  - Photo library access
  - Camera access if camera capture is implemented
- Create repo structure
- Add placeholder screens

Deliverable:

- App opens to home screen
- User can navigate to image picker
- User can select a photo and display it

### Stage 2 Tasks: Review Flow

Build:

- Selected image preview
- Button: `Scan Photo`
- Loading state: `Scanning locally...`
- Placeholder detection boxes from mock data
- Button: `Scrub Photo`

Deliverable:

- With mock regions, app displays boxes over image
- With mock scrubbed image, app shows result screen

### Stage 3 Tasks: Pipeline Integration

Wire:

```swift
let result = try await ImageProcessingPipeline().process(image: selectedImage)
```

Display:

- Regions
- Labels
- Timings
- Scrubbed image

Deliverable:

- Real pipeline result appears in UI

### Stage 4 Tasks: Export

Implement:

- Save/share scrubbed image
- `ShareLink` or `UIActivityViewController`
- Optional save-to-photos

Deliverable:

- User can export scrubbed image

### Stage 5 Tasks: Polish

Add:

- Before/after toggle
- Local processing badge
- Detection summary
- Error messages
- Basic product styling

Example summary:

```text
Detected:
- 1 face
- 1 DOB
- 1 MRN
- 1 phone number
```

### Success Criteria

Role A succeeds if:

- App can import photo
- App can display detection result
- App can show scrubbed image
- App can export image
- Demo flow is smooth

### Fallback Plan

If camera capture is buggy:

- Drop camera capture
- Use photo picker only

If before/after view takes too long:

- Use two tabs or two screens
- `Original` and `Scrubbed`

---

# Role B: Face Detection and On-Device Model Lead

## Mission

Make the project clearly satisfy the ZETIC track by integrating Melange for core on-device inference.

## Responsibilities

### Core Responsibilities

- Add ZETIC Melange iOS SDK
- Run a Melange sample on real iPhone
- Integrate face detection model
- Return face bounding boxes
- Measure inference latency
- Optional: integrate YOLO object detection
- Document exactly what runs through Melange

### Files Owned

```text
MelangeFaceDetector.swift
OptionalObjectDetector.swift
ModelPreprocessor.swift
ModelPostprocessor.swift
MelangeConfig.swift
```

### Stage 1 Tasks: Melange Setup

- Create Melange account if needed
- Get model key/API key if needed
- Add Melange package through Xcode Swift Package Manager
- Run official sample app on device
- Confirm real iPhone inference works

Deliverable:

- Screenshot/video of Melange sample running on phone
- Notes on setup steps

### Stage 2 Tasks: Face Detection Wrapper

Create API:

```swift
final class MelangeFaceDetector {
    func detectFaces(in image: UIImage) async throws -> [RedactionRegion] {
        // returns face regions
    }
}
```

Each returned region should be:

```swift
RedactionRegion(
    id: UUID(),
    rect: faceRect,
    type: .face,
    label: "FACE",
    confidence: confidence,
    source: "melange-face",
    redactionStyle: .blur
)
```

Deliverable:

- Given a test image, returns face boxes

### Stage 3 Tasks: Coordinate Mapping

- Confirm model input size
- Confirm coordinate system
- Convert model output to image coordinates
- Test with 3 images:
  - one centered face
  - multiple faces
  - face near edge

Deliverable:

- Boxes line up with faces in review UI

### Stage 4 Tasks: Latency Measurement

Measure:

- Preprocessing time
- Model inference time
- Postprocessing time
- Total face detection time

Return timing to pipeline.

Deliverable:

- Face detection timing appears in UI or console

### Stage 5 Tasks: Optional YOLO/Object Detection

If face detection is stable, add object detection.

Target objects:

- screen
- laptop
- monitor
- phone
- book/document
- bottle
- person
- badge-like object if possible

Return object regions as:

```swift
RedactionRegion(
    id: UUID(),
    rect: objectRect,
    type: .object,
    label: objectLabel.uppercased(),
    confidence: confidence,
    source: "melange-yolo",
    redactionStyle: .blackBox
)
```

Only redact objects that are obviously sensitive or useful for demo.

### Success Criteria

Role B succeeds if:

- Melange runs on device
- Main app uses Melange output
- Face regions are returned
- Latency is measured
- Demo slide can truthfully say Melange runs core detection locally

### Fallback Plan

If Melange face detection integration fails:

- Use Apple Vision face detection as temporary fallback
- Keep working on Melange sample separately
- Demo must still mention the actual Melange part that runs
- Do not fake Melange integration

If YOLO takes too long:

- Drop YOLO
- Face detection alone is enough for Melange if it works

---

# Role C: OCR and PHI Detection Lead

## Mission

Own the healthcare-specific intelligence: detecting sensitive text in photos.

This is the part that makes the app feel like a PHI scrubber instead of a generic face blur app.

## Responsibilities

### Core Responsibilities

- Run Apple Vision OCR on image
- Extract recognized text and bounding boxes
- Convert Vision bounding boxes to image coordinates
- Detect PHI using local rules
- Return PHI regions
- Tune demo documents for reliability

### Files Owned

```text
VisionOCRService.swift
PHIDetector.swift
OCRTextObservation.swift
PHIPatterns.swift
```

### Stage 1 Tasks: OCR Service

Create:

```swift
struct OCRTextObservation {
    let text: String
    let rect: CGRect
    let confidence: Float
}
```

Create service:

```swift
final class VisionOCRService {
    func recognizeText(in image: UIImage) async throws -> [OCRTextObservation] {
        // Apple Vision OCR
    }
}
```

Deliverable:

- Given fake patient form, console prints recognized text

### Stage 2 Tasks: OCR Box Mapping

- Convert Vision normalized boxes to image coordinates
- Return each text line with bounding box
- Verify boxes visually

Deliverable:

- Review UI can draw boxes around OCR text

### Stage 3 Tasks: PHI Detector

Create:

```swift
final class PHIDetector {
    func detectPHI(in observations: [OCRTextObservation]) -> [RedactionRegion] {
        // regex and keyword matching
    }
}
```

Rules:

- If a line contains obvious PHI pattern, redact whole line
- If line contains label like `Patient:` or `DOB:`, redact whole line
- If line is near a label, optionally redact nearby value
- For MVP, whole-line redaction is fine

Deliverable:

- Fake medical form redacts DOB, MRN, phone, email, etc.

### Stage 4 Tasks: Pattern Tuning

Create test text cases:

```text
Patient: Jane Smith
DOB: 03/14/1982
MRN: A9283910
Phone: (555) 293-1129
Email: jane.smith@example.com
Insurance ID: ZTX-88291
Rx #: RX-441928
Address: 123 Main Street
```

Make sure every line gets detected.

### Stage 5 Tasks: Detection Summary

Return labels so UI can show:

```text
Detected:
- DOB
- MRN
- PHONE
- EMAIL
```

Deliverable:

- `RedactionRegion.label` is meaningful

### Success Criteria

Role C succeeds if:

- OCR works on fake medical images
- PHI rules detect obvious identifiers
- Boxes align with text
- Main pipeline receives PHI regions

### Fallback Plan

If OCR boxes are hard to map:

- Redact entire OCR line bounding boxes
- Use larger padded rectangles
- Use fake demo image with large text
- If necessary, redact all OCR text in Hospital Mode

If PHI matching is imperfect:

- Use more label-based fake documents
- Conservative strategy: redact all text in medical document mode

---

# Role D: Redaction, Overlay, Export, and Demo Support Lead

## Mission

Own the output stage of the product:

- how detections are visualized
- how the scrubbed image is rendered
- how the result is exported

This role also supports demo clarity through good before/after output, screenshots, and reliable demo assets.

## Responsibilities

### Core Responsibilities

- Implement image redaction renderer
- Draw black boxes / blur / pixelation
- Build overlay rendering helpers
- Add export/share support with the app shell
- Create demo assets
- Create architecture slide
- Create pitch script
- Track integration status
- Run final rehearsals
- Maintain fallback demo plan

### Files Owned

```text
ImageRedactor.swift
CoordinateMapper.swift
DetectionOverlayView.swift
ResultView.swift
demo_script.md
pitch.md
architecture.md
demo-assets/*
```

### Stage 1 Tasks: Redaction Renderer

Create:

```swift
final class ImageRedactor {
    func redact(image: UIImage, regions: [RedactionRegion]) -> UIImage {
        // draw redactions
    }
}
```

MVP behavior:

- `phiText` → black rectangle
- `face` → black rectangle or blur
- `object` → black rectangle

Deliverable:

- Given mock regions, creates scrubbed image

### Stage 2 Tasks: Overlay View

Create a SwiftUI overlay component that draws boxes over the original image.

Labels:

- `FACE`
- `DOB`
- `MRN`
- `PHONE`
- `EMAIL`

Deliverable:

- User can see what was detected before scrubbing

### Stage 3 Tasks: Demo Assets

Create fake healthcare images:

1. Fake patient form
2. Fake prescription label
3. Fake wristband
4. Face/background photo
5. Optional hospital-room style scene

Rules:

- Do not use real PHI
- Use fake names, fake dates, fake IDs
- Use large, high-contrast text
- Keep images on-device

Example fake form:

```text
UCLA Demo Clinic
Patient: Jane Smith
DOB: 03/14/1982
MRN: A9283910
Phone: (555) 293-1129
Insurance ID: ZTX-88291
Diagnosis: Demo Condition
```

### Stage 4 Tasks: Architecture Slide

Create simple diagram:

```text
Photo
  |
  +--> Melange Face Detection
  |
  +--> Apple Vision OCR
          |
          v
      Local PHI Rules
  |
  v
Redaction Planner
  |
  v
Safe-to-share Image
```

Make the cloud/device separation explicit:

```text
On-device:
- Face detection
- OCR
- PHI detection
- Redaction
- Export

Cloud:
- None for MVP
```

### Stage 5 Tasks: Demo Script

Write 90-second pitch.

Required beats:

1. Show original photo with fake PHI
2. Run local scan
3. Show detected regions
4. Scrub photo
5. Show safe output
6. Turn on airplane mode
7. Repeat or explain offline operation
8. Show architecture

### Success Criteria

Role D succeeds if:

- Redacted image looks good
- Demo assets are reliable
- Pitch is clear
- Architecture slide is ready
- Final demo can survive model failures through fallback plan

### Fallback Plan

If blur is hard:

- Use black rectangles everywhere

If overlay boxes are hard:

- Skip overlay and show before/after only

If live demo fails:

- Use preloaded demo assets and screen recording

---

## 11. Staged Timeline

This timeline assumes a 36-48 hour hackathon. Adjust based on remaining time.

---

# Stage 0: Alignment and Repo Setup

## Goal

Everyone understands the product, stack, and interfaces.

## Timebox

30-60 minutes

## Tasks

### Everyone

- Agree on product name
- Agree on exact MVP
- Agree on no diagnosis features
- Agree on no backend
- Agree on shared data structures
- Join ZETIC Discord/support channel
- Confirm who has real iPhone available
- Confirm Xcode works

### Role A

- Create Xcode project
- Push repo

### Role B

- Start Melange SDK setup

### Role C

- Create fake PHI text examples

### Role D

- Start redaction renderer and overlay planning
- Start demo script and assets

## Exit Criteria

- Repo exists
- Xcode project builds empty app
- Everyone has assigned files
- Shared data models are defined

---

# Stage 1: Boring End-to-End Skeleton

## Goal

Photo goes in, mock redacted image comes out.

## Timebox

2-4 hours

## Tasks

### Role A

- Build home screen
- Add photo picker
- Display selected image
- Add `Scan Photo` button

### Role B

- Run Melange sample app separately
- Do not block main app

### Role C

- Create placeholder `VisionOCRService`
- Return mock PHI regions if OCR not ready

### Role D

- Implement `ImageRedactor`
- Build initial overlay component
- Use mock regions to black-box part of image

## Exit Criteria

- User can select image
- App shows selected image
- App can generate scrubbed image with mock boxes
- Main flow is visible

This stage matters because it gives the team a working product shell immediately.

---

# Stage 2: OCR and PHI Detection

## Goal

The app redacts real text from fake medical images.

## Timebox

4-8 hours

## Tasks

### Role A

- Add loading state
- Show detection summary
- Build result screen

### Role B

- Continue Melange integration

### Role C

- Implement Vision OCR
- Convert bounding boxes
- Implement PHI regex rules
- Return `RedactionRegion` objects

### Role D

- Tune redaction padding
- Create fake medical forms for testing
- Add overlay labels
- Start export/share implementation with Role A

## Exit Criteria

- App detects text from fake patient form
- App redacts DOB, MRN, phone, email, patient name
- Result image is understandable

At this point, the app is already a useful healthcare photo scrubber, even before Melange is integrated.

---

# Stage 3: Melange Face Detection

## Goal

The app uses Melange for core on-device inference.

## Timebox

6-12 hours

## Tasks

### Role A

- Add region source labels in UI
- Show timings

### Role B

- Integrate Melange face detector into main app
- Convert face boxes to image coordinates
- Return face redaction regions
- Measure latency

### Role C

- Keep improving PHI patterns
- Add conservative Hospital Mode option:
  - redact all text
  - redact all faces

### Role D

- Improve face redaction style
- Finalize export/share UX
- Add architecture slide showing Melange

## Exit Criteria

- Main app uses Melange for face detection
- Faces are redacted
- PHI text is redacted
- Demo can truthfully claim on-device Melange usage

---

# Stage 4: Product Polish

## Goal

Make it feel like a real product.

## Timebox

6-10 hours

## Tasks

### Role A

- Before/after toggle
- Share/export scrubbed image
- Better UI copy
- Error handling

### Role B

- Optimize Melange call
- Add latency printouts
- Optional object detection

### Role C

- Add more PHI patterns
- Improve false positives/false negatives
- Add detection summary labels

### Role D

- Polish redaction visuals
- Create final demo assets
- Create screen recording fallback
- Finish pitch script

## Exit Criteria

- Demo flow is smooth
- App does not crash on demo assets
- Output looks polished
- Export works

---

# Stage 5: ZETIC-Specific Optimization

## Goal

Make judges clearly see why this belongs in the ZETIC track.

## Timebox

2-4 hours

## Tasks

### Everyone

- Test in airplane mode
- Measure timing
- Document local vs cloud responsibilities
- Practice explaining Melange usage

### Role A

- Add UI badge:
  - `Processed on-device`
  - `No upload required`

### Role B

- Prepare exact statement:
  - which Melange model runs
  - what input it takes
  - what output it returns
  - latency on demo phone

### Role C

- Prepare exact statement:
  - OCR runs locally
  - PHI detection is local
  - no OCR text sent to server

### Role D

- Finalize architecture slide
- Finalize demo script
- Add fallback screenshots

## Exit Criteria

- Team can answer:
  - What runs on device?
  - What runs in cloud?
  - Where is Melange used?
  - Why is on-device necessary?
  - What is the latency?
  - What happens in airplane mode?

---

# Stage 6: Final Rehearsal

## Goal

Stop building. Rehearse and stabilize.

## Timebox

Last 2-4 hours

## Tasks

### Everyone

- Run demo 5+ times
- Use same phone
- Use same photos
- Use same lighting
- Turn off notifications
- Charge phone
- Close unnecessary apps
- Prepare backup screen recording
- Prepare static before/after images
- Prepare fallback explanation

## Exit Criteria

- Demo works repeatedly
- Everyone knows their speaking role
- Backup plan exists

---

## 12. Main Processing Pipeline Pseudocode

```swift
final class ImageProcessingPipeline {
    private let faceDetector = MelangeFaceDetector()
    private let ocrService = VisionOCRService()
    private let phiDetector = PHIDetector()
    private let redactor = ImageRedactor()

    func process(image: UIImage) async throws -> DetectionResult {
        let start = Date()

        let normalizedImage = ImageOrientationFixer.normalize(image)

        async let faceRegionsTask = faceDetector.detectFaces(in: normalizedImage)
        async let ocrObservationsTask = ocrService.recognizeText(in: normalizedImage)

        let faceRegions = try await faceRegionsTask
        let ocrObservations = try await ocrObservationsTask

        let phiRegions = phiDetector.detectPHI(in: ocrObservations)

        let allRegions = faceRegions + phiRegions

        let scrubbed = redactor.redact(
            image: normalizedImage,
            regions: allRegions
        )

        let totalMs = Date().timeIntervalSince(start) * 1000

        let timings = ProcessingTimings(
            faceDetectionMs: 0, // fill in later
            ocrMs: 0,
            phiDetectionMs: 0,
            redactionMs: 0,
            totalMs: totalMs
        )

        return DetectionResult(
            originalImage: normalizedImage,
            scrubbedImage: scrubbed,
            regions: allRegions,
            timings: timings
        )
    }
}
```

---

## 13. UI Flow

### 13.1 Home Screen

Content:

```text
MediMask

On-device PHI redaction for healthcare photos.

[Take Photo]
[Choose Photo]

Processed locally. No upload required.
```

### 13.2 Review Screen

Before scan:

```text
Selected Photo

[Scan On Device]
```

During scan:

```text
Scanning locally...
Running face detection, OCR, and PHI rules on this iPhone.
```

After scan:

```text
Detected 5 sensitive regions:
- 1 face
- 1 DOB
- 1 MRN
- 1 phone number
- 1 email

[Scrub Photo]
```

### 13.3 Result Screen

Content:

```text
Safe-to-share copy created

[Original] [Scrubbed]

Processing:
Face detection: 34 ms
OCR: 220 ms
PHI rules: 3 ms
Redaction: 18 ms
Total: 275 ms

[Share Scrubbed Image]
```

---

## 14. Demo Plan

### 14.1 Demo Props

Prepare:

1. Fake patient form
2. Fake prescription label
3. Photo with face in background
4. Optional fake wristband
5. Optional fake whiteboard/chart

### 14.2 Demo Script

Approximate script:

```text
Healthcare photos can accidentally expose private information: patient names, dates of birth, MRNs, faces, wristbands, charts, and prescription details.

We built MediMask, an on-device PHI scrubber for iPhone.

Here is a medical photo with a fake patient name, DOB, MRN, phone number, and face in the background.

I tap Scan. The app runs face detection through Melange and runs OCR plus PHI detection locally on the phone. Nothing is uploaded.

It found these sensitive regions. Now I tap Scrub Photo.

The output is a safe-to-share copy with the identifiers redacted.

Now we turn on airplane mode. The same workflow still works because the core AI pipeline runs on-device.
```

### 14.3 Demo Flow

1. Open MediMask
2. Choose fake patient form photo
3. Tap scan
4. Show detection boxes
5. Tap scrub
6. Show before/after
7. Share/export result
8. Turn on airplane mode
9. Repeat or show app still works
10. Show architecture slide

### 14.4 Failure Backup

If live app fails:

- Show pre-recorded screen recording
- Show before/after images
- Explain architecture
- Show Melange sample running if integrated separately

---

## 15. Risks and Mitigations

### Risk 1: Melange SDK Setup Takes Too Long

Likelihood: Medium

Mitigation:

- Role B starts immediately.
- Main app proceeds with mock face regions and OCR.
- Use Apple Vision face detection as fallback.
- Keep a working Melange sample as proof if full integration fails.

### Risk 2: OCR Misreads Demo Text

Likelihood: Medium

Mitigation:

- Use large, high-contrast printed text.
- Use simple fonts.
- Avoid glare.
- Use fake forms designed for OCR.
- Redact all text in Hospital Mode if needed.

### Risk 3: Bounding Boxes Do Not Align

Likelihood: High

Mitigation:

- Normalize image orientation first.
- Use portrait-only demo images.
- Add padding around boxes.
- Test coordinate conversion early.
- Redact whole lines rather than exact spans.

### Risk 4: Face Blur Takes Too Long

Likelihood: Low/Medium

Mitigation:

- Use black boxes over faces.
- Pixelation optional.
- Blur only if easy.

### Risk 5: App Crashes During Demo

Likelihood: Medium

Mitigation:

- Use exact same demo assets.
- Rehearse multiple times.
- Have screen recording backup.
- Avoid adding new features near the end.

### Risk 6: Judges Ask About HIPAA

Likelihood: Medium

Mitigation:

Say:

```text
This prototype does not claim HIPAA compliance. It is an on-device de-identification assistant that reduces accidental PHI exposure by keeping analysis local and creating a redacted copy before sharing.
```

Do not say:

```text
This guarantees HIPAA compliance.
```

---

## 16. Judging Talking Points

### 16.1 Why This Needs Mobile AI

- Photos are taken and shared from phones.
- Healthcare images are sensitive.
- Users need instant pre-share checks.
- Offline operation matters.
- Original images should not be uploaded for analysis.

### 16.2 Why This Needs On-Device AI

- Uploading PHI-containing photos creates privacy risk.
- Face and text detection can happen locally.
- Airplane mode demo proves independence from cloud.
- Latency is better for pre-share workflows.

### 16.3 Where Melange Is Used

Fill this in after implementation:

```text
We use Melange for:
- Face detection model: ________
- Optional object detection model: ________
- Device tested: ________
- Average latency: ________ ms
```

### 16.4 Device vs Cloud Responsibilities

```text
On device:
- Image input
- Face detection
- OCR
- PHI detection
- Redaction
- Export

Cloud:
- None in MVP
```

### 16.5 What Makes This Healthcare-Specific

- Aggressively redacts faces and identifiers
- Looks for DOB, MRN, patient IDs, insurance IDs, Rx numbers
- Designed for healthcare photos, forms, wristbands, and labels
- Does not provide diagnosis or clinical recommendations

---

## 17. Exact Priority List

Build in this order:

1. Xcode project
2. Photo picker
3. Display selected image
4. Mock redaction
5. Real redaction renderer
6. Apple Vision OCR
7. PHI regex detection
8. Display boxes
9. Generate scrubbed image
10. Export/share scrubbed image
11. Melange face detection
12. Timing measurements
13. Airplane mode demo
14. Pitch slide
15. Optional object detection
16. Optional camera capture
17. Optional blur/pixelation
18. Optional before/after slider

Do not skip ahead to optional features before steps 1-13 work.

---

## 18. Definition of Done

The project is done when:

- User can import or take a photo.
- App detects sensitive text.
- App detects faces with Melange or a documented fallback.
- App redacts sensitive regions.
- App displays the scrubbed image.
- App can export/share the scrubbed image.
- Demo works in airplane mode.
- Pitch clearly explains on-device processing.
- Team can explain Melange usage.
- No real PHI is used in demo assets.

---

## 19. Final Submission Checklist

### App

- [ ] Builds on real iPhone
- [ ] Photo import works
- [ ] Scan button works
- [ ] OCR works
- [ ] PHI detection works
- [ ] Face detection works
- [ ] Redaction works
- [ ] Export works
- [ ] Airplane mode tested
- [ ] No crash on demo assets

### ZETIC

- [ ] Melange SDK used
- [ ] Melange role is clear
- [ ] On-device vs cloud split is clear
- [ ] Latency measured
- [ ] Performance explained
- [ ] No cloud-heavy workflow

### Demo

- [ ] Fake patient form ready
- [ ] Fake wristband/photo ready
- [ ] Screen recording backup ready
- [ ] Architecture slide ready
- [ ] Pitch script ready
- [ ] Phone charged
- [ ] Notifications disabled
- [ ] Rehearsed multiple times

### Messaging

- [ ] Do not claim legal HIPAA compliance
- [ ] Do not use real patient data
- [ ] Do not mention diagnosis
- [ ] Emphasize de-identification
- [ ] Emphasize local processing
- [ ] Emphasize safe-to-share copy

---

## 20. Final Pitch

```text
Healthcare photos often contain private information that people do not notice: faces, wristbands, charts, patient names, dates of birth, medical record numbers, and prescription details.

MediMask is an on-device PHI scrubber for iPhone. Before a healthcare photo is shared, it uses local AI to detect sensitive regions, redacts them, and exports a safe-to-share copy.

The original image never leaves the phone. The OCR text never leaves the phone. The face detections never leave the phone. We can run the full workflow in airplane mode.

For the ZETIC track, our core detection pipeline uses Melange for on-device inference, with local OCR, local PHI rules, and local rendering for final redaction.
```
