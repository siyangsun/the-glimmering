# The Glimmering — Claude Context

Gitignored scratch context. Only things not obvious from the code itself.
Read `architecture.md` for system design and MVP plan before touching anything.

## Project
First-person surreal art game. A depressed person walks into the ocean.
Godot 4, GDScript. Rendered entirely as 2D canvas (no 3D nodes); the world is a 1D
distance simulation projected by WavePhysics.
See `brainstorm.md` for design intent; `architecture.md` for system layout.

## Engine & Language
- Godot 4.7.1, GDScript
- Renderer: GL Compatibility (all visuals are 2D canvas; shaders are canvas_item + screen texture)
- CanvasLayer stack for world + overlays (see layer table in Main.gd)
- No camera node: GameManager.cam_y/cam_x/cam_roll (bob/sway/roll) are applied by the 2D renderers

## Architecture
Five autoloads: `GameManager`, `DrownMeter`, `ImpairmentSystem`, `AudioManager`, `SignalBus`.
Everything communicates via SignalBus — wave hits fan out to impairments, visuals,
knockback, and audio independently. See `architecture.md` for full signal flow.

## Validating Changes
DO NOT attempt headless smoke tests — Godot install path changes between sessions and
the test reliably fails. Ask the user to test in the editor instead.

## GDScript Conventions
- Explicit type annotations always (`var x: float = ...` not `:=` with max()/ternaries)
- Signals past-tense verb phrases: `wave_hit`, `impairment_changed`, `game_ended`
- No Node dependencies in simulation classes (DrownMeter, ImpairmentSystem pure logic)

## Current MVP
MVP 0 — skeleton loop. Grey planes, walk forward, placeholder wave every 5s,
drown meter prints to console, DevOverlay shows all state. See `architecture.md`.

## Explicit Decisions — Don't Silently Revert
- Drown meter is never shown to the player — diegetic audio only
- Wave visual scale IS the threat signal — no other warning
- UI philosophy: as little information as possible; any text is surreal/non-linear
- Clearing actions: simultaneous with walking (not pause-to-clear) — revisit in playtesting
