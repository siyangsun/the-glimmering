extends Node
# Global event bus — add as Autoload named "SignalBus" in Project > Autoload.
#
# Add project-specific signals below. Keep each signal's payload minimal;
# pass data objects (Resources, Dictionaries) rather than many loose args.
#
# Convention: signal names are past-tense verb phrases matching the event that
# occurred — player_died, card_played, score_changed — not imperative commands.

# ── Lifecycle ────────────────────────────────────────────────────────────────
signal game_started
signal game_paused(is_paused: bool)
signal game_over(winner: StringName)

# ── Player ───────────────────────────────────────────────────────────────────
signal player_died
signal player_scored(points: int)

# ── Add project-specific signals below ───────────────────────────────────────
