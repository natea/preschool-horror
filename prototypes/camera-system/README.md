# Camera System Prototype

## Hypothesis
The photography loop — raise camera, frame an anomaly, snap a photo, review the result — feels satisfying and scary in first-person Godot 4.6.

## How to Run
```bash
cd prototypes/camera-system
godot --path .
```
Or open the project in the Godot editor and press F5.

## Controls
- **WASD** — Move
- **Mouse** — Look
- **RMB (hold)** — Raise camera (viewfinder mode, slows movement to 1.5 m/s)
- **LMB** — Take photo (only while camera raised)
- **G** — Toggle evidence gallery
- **Shift** — Run (4.0 m/s, blocks camera raise)
- **E** — Interact (placeholder)
- **ESC** — Release mouse cursor

## What's in the Scene
- One preschool-scale room (6m x 5m, 3m ceiling)
- Warm overhead lighting (two omni lights)
- Furniture: table, two chairs (one normal, one anomaly)
- Three anomalies:
  - **Rotated chair** — tilted at a wrong angle
  - **Floating blocks** — hovering 30cm off the floor
  - **Wrong-color painting** — red instead of expected color, on the back wall

## What to Test
1. Does raising the camera feel vulnerable (speed reduction)?
2. Does the anomaly detection feedback (score %) feel accurate or arbitrary?
3. Does the flash effect feel like a real camera moment?
4. Can you reliably frame anomalies and get good scores?
5. Does the photo gallery capture recognizable evidence?

## Status
In progress — first build, untested visually.

## Findings
[To be updated after testing]
