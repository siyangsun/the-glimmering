# The Glimmering — Architecture

## Scene Tree

```
Main.tscn                        ← root; owns game state machine
├── World                        ← 3D environment (MeshInstance3Ds, no physics needed)
│   ├── BeachFloor               ← flat plane, sand texture/color
│   ├── WaterSurface             ← flat plane extending forward, shifts in depth
│   └── Sky                     ← WorldEnvironment / sky shader
├── WaveSpawner                  ← spawns and queues Wave instances
│   └── [Wave] (instanced)       ← one active at a time; handles its own lifecycle
├── Player                       ← CharacterBody3D or just a Node3D (no physics body needed)
│   └── Camera3D
├── ImpairmentLayer (CanvasLayer)← always on top of 3D, below HUD
│   ├── EyeBlur                  ← ColorRect + blur shader; hidden when eyes clear
│   └── NoseVignette             ← optional subtle vignette when nose clogged
├── AudioLayer                   ← not a scene node, managed by AudioManager autoload
└── UI (CanvasLayer)             ← HUD; deliberately near-empty
    ├── DevOverlay               ← debug info (distance, meter, impairments) — stripped for release
    └── EndScreen                ← shown on drown or 100m arrival; surreal text
```

---

## Autoloads

| Name | Purpose |
|------|---------|
| `GameManager` | owns game state (playing, paused, ended), distance, run count |
| `DrownMeter` | hidden float 0–1; drives breathing audio; emits `filled` signal |
| `ImpairmentSystem` | tracks eye/ear/nose state; emits `impairment_changed` |
| `AudioManager` | ocean ambience, wave hits, breathing layer, muffling bus effect |
| `SignalBus` | cross-system events (wave_hit, action_performed, game_ended) |

---

## Key Systems

### WaveSystem
- `WaveSpawner` generates a `WaveData` resource per wave: `{size, force, delay_after}`
- Waves arrive on a timer; `delay_after` controls the gap before the next wave
- On wave hit: `SignalBus.wave_hit.emit(wave_data)`
- `WaveData` is the only place size and force live — nothing else hardcodes values

### ImpairmentSystem
- Three boolean states: `eyes_impaired`, `ears_impaired`, `nose_impaired`
- Listens to `SignalBus.wave_hit` — applies impairments based on wave characteristics
- Exposes `clear(type)` called by player input
- Emits `impairment_changed(type, is_impaired)` — subscribers update visuals/audio/movement

### DrownMeter
- Float 0.0–1.0, never exposed to player directly
- Passive fill rate from wave submersion (small constant when in water)
- Multiplied when `nose_impaired` is true
- At 1.0: emits `filled` → GameManager triggers drown ending
- AudioManager subscribes and crossfades breathing layer based on value

### PlayerController
- Holds `walk_speed_base`; actual speed = `walk_speed_base * ear_speed_modifier`
- `ear_speed_modifier` is 1.0 normally, ~0.6 when ears impaired (from ImpairmentSystem)
- Distance tracked in GameManager, not PlayerController
- At 100m: GameManager triggers arrival ending

### Wave Visual
- A SubViewport or CanvasLayer element displaying a looping animation/GIF
- Scaled on X and Y by `wave_data.size` (0.0–1.0 → 0%–100% viewport fill)
- Plays the animation, then hides; meanwhile physics knockback resolves separately
- Visual and mechanical are driven by the same `WaveData` but execute independently

---

## Signal Flow

```
WaveSpawner
  → SignalBus.wave_hit(wave_data)
      → ImpairmentSystem: apply impairments
      → PlayerController: apply knockback (distance -= wave_data.force)
      → WaveVisual: play animation scaled to wave_data.size
      → AudioManager: play hit sound

ImpairmentSystem.impairment_changed(type, state)
  → EyeBlur: show/hide shader overlay
  → AudioManager: apply/remove muffle bus effect
  → PlayerController: update ear_speed_modifier
  → DrownMeter: update nose_active multiplier

DrownMeter.filled()
  → GameManager: trigger drown ending

GameManager (distance >= 100.0)
  → GameManager: trigger arrival ending
```

---

## MVP Phases

### MVP 0 — Skeleton (no assets, placeholder everything)
Goal: the loop runs end to end.

- Flat grey `MeshInstance3D` planes for beach and water (different shades of grey)
- `WorldEnvironment` set to overcast grey
- Player walks forward with W key; distance increments
- One placeholder wave: arrives every 5 seconds, knocks back 2m, no visual yet
- DrownMeter fills at fixed rate; prints "DROWNED" and quits at 1.0
- Reaching 100m prints "ARRIVED" and quits
- DevOverlay Label showing: distance, drown meter value, impairment states

### MVP 1 — Impairment Loop
Goal: all four actions work and affect the game.

- Wave hits apply random combination of impairments
- Wipe eyes / blow nose / clear ears inputs clear respective impairment
- EyeBlur ColorRect appears (solid semi-transparent grey, no shader yet)
- Ear muffle: AudioManager lowers SFX bus volume when ears impaired
- Nose: DrownMeter fill rate doubles when nose impaired
- Walk speed reduces when ears impaired
- DevOverlay updated to show all states clearly

### MVP 2 — Wave Visual
Goal: waves feel present.

- WaveSpawner generates waves with varied size and force
- Wave visual: a large ColorRect (blue-grey) that scales up from bottom of screen,
  holds for a beat, then drops — no GIF yet, just the shape language
- Scale on screen matches `wave_data.size`
- Cadence has slight random variance
- Sound: placeholder audio (single WAV for ocean loop, single WAV for wave hit)

### MVP 3 — Feel Pass
Goal: the drown meter lives in audio, not UI.

- AudioManager crossfades a breathing audio layer as DrownMeter rises
- Ocean ambience plays on loop from start
- Muffle effect on AudioBus when ears impaired (LowPassFilter on SFX bus)
- DevOverlay can be toggled off with a key so we can feel the game without numbers
- Both ending screens appear with placeholder surreal text

### MVP 4 — Asset Integration
Goal: real visuals and audio drop in without code changes.

- Wave GIFs/videos slot into WaveVisual scene
- Real ocean ambience and breathing audio
- Sky and water shaders replace flat planes
- EyeBlur becomes a real blur shader (screen-space, exempts UI CanvasLayer)
- Ending screen text finalized

---

## File Layout

```
the-glimmering/
├── scenes/
│   ├── Main.tscn
│   ├── Wave.tscn               ← single wave instance
│   └── ui/
│       ├── DevOverlay.tscn
│       └── EndScreen.tscn
├── scripts/
│   ├── autoloads/
│   │   ├── GameManager.gd
│   │   ├── DrownMeter.gd
│   │   ├── ImpairmentSystem.gd
│   │   ├── AudioManager.gd
│   │   └── SignalBus.gd
│   ├── WaveSpawner.gd
│   ├── WaveVisual.gd
│   ├── PlayerController.gd
│   └── ui/
│       ├── DevOverlay.gd
│       └── EndScreen.gd
├── data/
│   └── WaveData.gd             ← Resource subclass
├── assets/                     ← empty until MVP 4
│   ├── audio/
│   ├── waves/                  ← GIFs / video go here
│   └── shaders/
├── brainstorm.md
├── architecture.md
└── CLAUDE.md
```

---

## Deferred Decisions

- Clearing actions: pause walking or simultaneous? Start with simultaneous; playtest.
- Wave size vs. force: start correlated (big wave = big knockback); decouple later if needed.
- Hands during clearing actions: skip for MVP; add in feel pass if it reads as empty.
- Ambient surreal text during walk: evaluate after MVP 3 when the feel is established.
