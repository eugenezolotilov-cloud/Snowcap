# Snowcap CPU optimization, 2026-11-09

The local macOS app is now named Snowcap. Its bundle identifier and preference keys are unchanged.

## Changes

- Check the idle window-motion sentinel at about 30 Hz instead of every rendered frame. Active window dragging, detected motion and Space animations retain their previous polling cadence. Initial detection of unannounced motion can take about 32 ms; rendering still runs at its existing rate.
- Decode only window bounds for that sentinel instead of every window metadata field.
- Reuse collision-span storage and reject impossible window collisions before indexing their height fields. The original per-column collision test remains authoritative.
- Use a snow-only particle count and avoid leaf rotation/tumbling calculations that snow shaders never read.
- Use equivalent pure-snow paths for melting, settling and surface preparation, avoiding unused leaf/petal arithmetic.
- Rebuild window occluder arrays only when their source rectangles change.

No changes to frame-rate policy, drawable resolution, particle targets, snow defaults or shaders.

## Validation

On the current Apple A18 Pro Mac, successive three-second process CPU samples were 14.0%, 14.3%, 14.6% before the restart and 9.1%, 9.5%, 9.5%, 9.7% with the updated app. These are live desktop observations, not a controlled whole-app benchmark: restarting clears the current snow, and desktop activity can change the results.

A separate deterministic simulation benchmark used a 2560 × 1440 scene, ten window surfaces, intensity 0.5, 7,200 frames at 60 Hz, periodic cursor sweeps, and sprite/height-field serialization each frame. Only scratch test copies used fixed particle/grain seeds and SWIFT_DETERMINISTIC_HASHING=1. The old and new versions produced the same sampled position/opacity/height-field checksum (14084987585880943846) and final sprite count (1446). Paired wall-clock times were 1.098 → 0.885 seconds and 1.234 → 0.903 seconds, approximately 19–27% less CPU-side calculation time. Production retains random seeds.

The existing physics checks passed for accumulation, melting, frame-rate independence, resized-window shedding, display handoff, cursor interaction, live depth changes and finite particle positions. Metal initialized and rendered a nonempty offscreen frame. The universal arm64/x86_64 app passed deep/strict code-signature verification. The original PolyForm Noncommercial license, Sparkle license and copyright notice were retained.
