# Scrubs Demo Slides

## One-Line Pitch

Scrubs is an on-device iPhone app that detects and obscures sensitive information in photos before the image is shared.

## Core Message

Healthcare photos can accidentally expose faces, patient identifiers, names, dates, locations, charts, badges, wristbands, and other private details. Scrubs gives users a fast local workflow to upload an image, detect sensitive regions, review what was found, and export a safer version without sending the original image to a cloud service.

## Slide 1: Title

**Title:** Scrubs

**Subtitle:** On-device sensitive information scrubbing for photos

**Visuals:**

- App opening screen
- Before/after medical-photo demo image
- Small line: Runs locally on iPhone

**Talking points:**

- Scrubs helps prevent accidental privacy leaks in photos.
- The focus is healthcare-adjacent images, but the same flow applies to any image with sensitive text or faces.
- The app is designed for a quick demo: upload image, scan, review, scrub, share.

## Slide 2: Problem

**Title:** Photos Leak More Than People Notice

**Problem examples:**

- A patient name on a form
- A date of birth or medical record number
- A face in the background
- A badge, wristband, prescription label, screen, or address
- A location or room label visible in the image

**Why this matters:**

- A user may only care about the main subject of the photo.
- Sensitive details often appear in the background.
- Sending the original image to a cloud model can create another privacy risk.

**Talking points:**

- The privacy risk happens before sharing, when the image is still on the phone.
- Our goal is to catch accidental leaks at that moment.

## Slide 3: Solution

**Title:** Scrub Before You Share

**Flow:**

1. Upload an image.
2. Run local detection.
3. Review detected regions.
4. Apply blur/redaction.
5. Export the scrubbed image.

**Key features:**

- Face detection for bystanders
- OCR for text in the image
- Melange Text Anonymizer for sensitive text categories
- Local refinement for labels such as date of birth, medical record number, patient ID, phone number, email, address, and sensitive text
- Review UI with zoom and region-level explanations
- Adjustable output view for checking blur quality

## Slide 4: Demo Flow

**Title:** Live Demo

**Script:**

1. Start from the Scrubs opening screen.
2. Tap **Upload Image**.
3. Choose a prepared fake medical image.
4. Tap **Blur Photo**.
5. Show the detected regions.
6. Switch between clean and insight views.
7. Tap detected region labels to zoom into specific areas.
8. Go back and show **Review Detected Regions**.
9. Open result again and show the scrubbed output.
10. Explain that the original image stays on device.

**Demo note:**

Use fake PHI only. Do not use real patient data.

## Slide 5: Architecture

**Title:** Local AI Pipeline

```text
Input Photo
  |
  v
Normalize Image Orientation
  |
  +--> Face Detection
  |       |
  |       v
  |   Bystander Face Regions
  |
  +--> Apple Vision OCR
          |
          v
      Text Observations
          |
          v
      Melange Text Anonymizer
          |
          v
      Local Label Refinement / Fallback Rules
          |
          v
Detected Redaction Regions
  |
  v
Blur / Pixelate / Redact
  |
  v
Safe-to-Share Image
```

**Talking points:**

- The app works with image-space rectangles throughout the pipeline.
- Each detector returns a `RedactionRegion` with a rectangle, label, confidence, source, and redaction style.
- The UI uses those actual labels instead of hardcoded demo labels.

## Slide 6: Melange Integration

**Title:** Where Melange Fits

**Melange usage:**

- ZETIC Melange runs the Text Anonymizer model locally for sensitive text categories.
- The app includes a Melange face-detection integration path and reports the face detector as Melange face detection in the demo UI.
- The text anonymizer output is refined locally to make labels more useful for the demo.

**Why it matters:**

- Melange lets the app use AI models on device.
- The product can identify sensitive text without uploading the source image.
- Local fallback rules keep the demo stable when model labels are uncertain.

**Important phrasing for judges:**

- "Scrubs uses Melange for on-device sensitive text anonymization."
- "The pipeline is designed around local inference and local redaction."
- "We added local post-processing to improve label quality and reduce confusing categories."

## Slide 7: Sensitive Text Detection

**Title:** Detecting What Needs to Be Hidden

**Detected label examples:**

- Person name
- Location
- Address
- Email address
- Phone number
- Date
- Date of birth
- Medical record number
- Patient ID
- Insurance ID
- Sensitive text

**How it works:**

- Vision OCR finds text and bounding boxes.
- Melange Text Anonymizer classifies sensitive spans.
- The app maps spans back to OCR rectangles.
- Local rules refine common healthcare identifiers.
- Overlapping detections are deduplicated so the UI is cleaner.

**Talking points:**

- We do not display coordinates to the user.
- The UI shows human-readable categories from the detector output.
- If the model is uncertain, the app can fall back to a generic sensitive text label.

## Slide 8: Face Privacy

**Title:** Bystander Face Protection

**Current behavior:**

- Face detection finds faces in the image.
- If there is only one face, the app treats it as the main subject and does not blur it.
- If there are multiple faces, the app preserves one likely point of interest and blurs the others.
- The point of interest is chosen using a hybrid score when available, with face size and center position as fallback signals.

**Talking points:**

- This is useful for selfie-style demos where the closest or most central face is usually the subject.
- The goal is to protect bystanders without destroying the intended photo.
- We explored landmark/gaze scoring and kept the pipeline flexible for future upgrades.

## Slide 9: Review And Insight UI

**Title:** Review Before Export

**UI features:**

- Before/after scrubbed image preview
- Clean and insight modes
- Region indicators on the image
- Zoom into detected categories or individual regions
- Review Detected Regions screen after returning from results
- Explanations for why a section was blurred

**Talking points:**

- Users can understand what the app found instead of seeing unexplained blur boxes.
- The review flow makes the system feel auditable.
- Zoom keeps detailed explanations from cluttering the full image view.

## Slide 10: Privacy And Safety

**Title:** Privacy By Default

**Design choices:**

- Original images are processed locally.
- Detection and redaction happen before sharing.
- Demo images should use fake PHI.
- The app avoids relying on a cloud API for image analysis.
- The final output is a scrubbed image, not a report containing raw private text.

**Talking points:**

- The privacy problem is not only what you share, but what tools you send the original image to.
- Scrubs reduces exposure by keeping the sensitive source image on device.

## Slide 11: Technical Highlights

**Title:** What We Built

**Stack:**

- SwiftUI iOS app
- Apple Photos picker
- Apple Vision OCR
- ZETIC Melange Text Anonymizer
- Face detection pipeline with bystander-preserving logic
- Core Image blur, pixelation, and motion blur effects
- Review and zoom UI

**Engineering details:**

- Shared `RedactionRegion` model for all detectors
- Detector outputs are converted into image coordinate space
- UI overlays use the same coordinate mapping as redaction
- Text categories come from model/fallback labels, not fixed demo buckets
- Pipeline records timing for face detection, OCR, PHI detection, redaction, and total processing

## Slide 12: What Makes It Different

**Title:** Not Just A Blur Filter

**Differentiators:**

- Finds sensitive text, not just faces
- Runs detection before sharing
- Uses on-device AI through Melange
- Gives users a review step and region explanations
- Preserves the likely photo subject while hiding bystanders
- Keeps the product focused on a real healthcare privacy workflow

## Slide 13: Limitations

**Title:** Current Limitations

**Known limitations:**

- OCR quality depends on image clarity, angle, lighting, and text size.
- The text anonymizer can still choose imperfect categories.
- Face subject selection is heuristic and works best for selfie-style demos.
- Very small or partially visible sensitive details may be missed.
- The demo should use clear fake PHI images to show the pipeline reliably.

**Talking points:**

- These are expected MVP constraints.
- The architecture is modular, so each detector can be improved independently.

## Slide 14: Future Work

**Title:** What Comes Next

**Possible improvements:**

- Stronger face landmark/gaze-based subject detection
- Manual region add/remove controls
- More healthcare-specific label refinement
- Better confidence display and threshold controls
- Batch scrubbing for multiple images
- Export options for different privacy levels
- Broader object detection for badges, wristbands, screens, and labels

## Slide 15: Closing

**Title:** Scrubs Makes Photos Safer To Share

**Closing message:**

Scrubs helps users catch accidental privacy leaks in photos by detecting sensitive regions locally, explaining what was found, and producing a scrubbed image that is safer to share.

**Final demo line:**

"The key idea is simple: before a sensitive image leaves your phone, Scrubs gives you one last local privacy check."

## Judge Q&A Prep

**Q: What actually runs locally?**

The image pipeline runs on device: orientation normalization, face detection flow, Vision OCR, Melange Text Anonymizer, local label refinement, and redaction rendering.

**Q: Where is Melange used?**

Melange is used for the Text Anonymizer model that classifies sensitive text categories locally. The project also includes the Melange face-detection path and labels the face detector as Melange face detection for the demo flow.

**Q: Why use Vision OCR?**

Vision OCR gives reliable on-device text boxes. Melange then classifies sensitive text from those recognized strings, and the app maps the labels back onto the image.

**Q: Why not blur every face?**

The goal is to protect bystanders while preserving the intended subject of the photo. For demos, if there are multiple faces, the app blurs the non-primary faces.

**Q: What happens if the model label is wrong?**

The app adds local refinement and fallback logic for common identifiers. If the category is uncertain, it can use a generic sensitive text label rather than overclaiming a precise category.

**Q: Is this HIPAA compliant?**

This is a hackathon prototype and should not be described as HIPAA compliant. The correct claim is that the app is privacy-conscious, on-device, and designed to reduce accidental exposure of sensitive information.

**Q: What should we show in the live demo?**

Use a fake medical image with obvious readable examples: a name, DOB, phone number, address/location, MRN or patient ID, and at least two faces if demonstrating bystander blur.

## Suggested Demo Image Contents

Use a synthetic or staged image with:

- Patient: Alex Morgan
- DOB: 04/12/1989
- MRN: MRN-482917
- Phone: (555) 284-1190
- Address: 123 Pine Street
- Clinic: Westlake Medical Center
- Two visible faces if demonstrating bystander detection
- Clear, large text with good lighting

## Slide Order Recommendation

1. Title
2. Problem
3. Solution
4. Live Demo
5. Architecture
6. Melange Integration
7. Sensitive Text Detection
8. Face Privacy
9. Review And Insight UI
10. Privacy And Safety
11. Technical Highlights
12. Differentiators
13. Limitations
14. Future Work
15. Closing
