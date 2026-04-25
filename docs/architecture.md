# MediMask Architecture

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

All MVP processing is intended to run on-device.
