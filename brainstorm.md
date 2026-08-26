# The Glimmering — Brainstorm

## Premise

A depressed person with a thanatos drive walks into the ocean. Grey day. Beach.
First-person. The player walks toward the water, depth increasing as waves batter them.
The game offers no explanation and asks for nothing except presence.

This is a creative multimedia art project first, a game second.

---

## Core Loop

Player walks forward (0–100m from shore). Waves arrive at a cadence, each with
characteristics (size, force) that determine knockback distance and visual scale.
Impairments accumulate from waves. Player triages which impairment to clear.
Game ends when the drown meter fills or the player reaches 100m.

---

## Player Actions

Only four things the player can do:

| Action | Input | Effect |
|--------|-------|--------|
| Walk forward | held | advances distance |
| Wipe eyes | press | clears eye impairment |
| Blow nose | press | clears nose impairment |
| Clear ears | press | clears ear impairment |

Actions are not simultaneous — unclear yet whether clearing takes time (pauses walk)
or is instant. To decide: does the act of stopping to blow your nose feel meaningful,
or just frustrating?

---

## Impairment System

Waves apply impairments on hit. Each has a sensory effect and a mechanical consequence:

| Impairment | Screen effect | Mechanical effect |
|------------|--------------|-------------------|
| Eyes | screen blur (not HUD) | harder to read incoming waves |
| Ears | audio muffle | move slower |
| Nose | none visible | drown meter drains faster |

Impairments stack and compound: muffled ears keep you in the wave zone longer, meaning
more hits, meaning more nose clogs, meaning faster drowning. The triage decision
(which to clear first) is the core skill expression without ever being stated.

---

## Wave System

Each wave has two defining characteristics:
- **Size** — determines visual scale (how much of the screen the GIF fills)
- **Force** — determines knockback (meters pushed back)

These may correlate or diverge — a slow-rolling massive wave vs. a sharp small one.
Visual size is the only information the player gets. No numbers. No warning text.

Wave arrival has a cadence (timing interval) that may vary. Between waves: the only
time the player can recover ground and clear impairments.

**Visual:** waves rendered as a GIF (or looping animation) stretched/scaled in
first-person to match size. The fill percentage IS the threat signal.

---

## Drown Meter

Hidden. Never shown as a number or bar.

Manifests diegetically:
- Breathing audio becomes louder, shorter, more desperate as it fills
- Possibly color grading shift (greyer, more washed out) at high values
- Player never knows the exact value — only feels it

Fills faster when nose is clogged. Fills slowly passively from wave submersion.
If it reaches max: drown ending.

---

## Endings

Two endings unlocked from the start:

**Drown** — drown meter fills. Screen goes under. Surreal text.

**100m** — player reaches 100m from shore. What happens there? Something.
Not safety — arrival. Surreal text.

Meta-progression unlocks further endings through repeated play. Conditions TBD —
candidates: turning back, standing still, specific sequences of actions, reaching
100m multiple times, drowning multiple times. The new endings should recontextualize
earlier ones.

---

## UI Philosophy

As little information as possible. What must exist:
- Wave visual (the GIF/animation itself)
- Blur overlay for eye impairment
- Audio effects for ear impairment (no visual)
- No distance counter. No impairment indicators. No drown meter display.

Any text in the game (menus, endings, possibly ambient) should be:
- Surreal and non-linear
- Not instructional
- Possibly contradictory between runs

The game teaches nothing. The player figures it out or doesn't.

---

## Art Direction

- Greyscale-leaning palette, desaturated blues and greys
- Overcast sky, flat water light
- First-person, no visible body (or minimal — maybe hands during clearing actions)
- Wave GIFs: real ocean footage, desaturated, stretched to fill viewport
- Audio: ocean ambience, wind, muffled breathing, water sounds on submersion

---

## Open Questions

- Do clearing actions pause walking or happen simultaneously?
- Does wave force vary independently from wave size, or are they directly linked?
- What is at 100m? What does the player see/experience on arrival?
- What triggers meta-progression unlocks — run count, specific actions, both?
- Is there ambient surreal text during the walk, or only at endings?
- Hands visible during clearing actions, or entirely invisible?
