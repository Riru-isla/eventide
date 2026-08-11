# Eventide — Design Decisions

Decisions that are settled and that later work should build on rather than revisit.
Speculative ideas live in `ideas.md` at the repo root.

## Reference points

Eventide is **inspired by** OGame, not a clone of it. Borrow the parts that work —
resource buildings with levels, an energy balance, timed construction — but do not
treat OGame's specific rules as a spec. Stellaris' planetary view is the other
reference: its depth comes from **modifiers that interact**, which is the quality to
aim for, not its exact systems.

## Energy is a balance with soft penalties, not an upgrade cost

Energy is **not** a stored resource and **not** a gate on construction. There is no
"this upgrade needs 48 energy" check.

Instead each planet has:

- **Energy production** from generation buildings (solar and similar).
- **Energy consumption** from mines and other consumers, scaling with their level.

While the balance is **negative**, the empire suffers:

- **-70% resource generation.**
- **-70% build speed**, *except* for energy generation buildings — so a player can
  always dig themselves out of a deficit.
- **Research slowed.** (Stated as "research time decreased" in the original
  discussion; read here as a penalty consistent with the other two. Worth confirming
  before implementing.)

The point is that a deficit is survivable but painful, so managing the balance is an
ongoing decision rather than a wall.

This is **implemented** as of the planet screen:

- `Empire#energy` no longer accumulates. `TickProcessor` collects metal and crystal only.
  The column still exists and is unused.
- `ShipType#energy_cost` is no longer charged — hulls cost metal and crystal. The column
  still exists, pending a decision on a third stored resource.
- The Warden bonus applies to **energy production** in `PlanetEconomy`, so a Warden
  sustains higher structure levels than anyone else on the same buildings.

Still open: whether a third stored resource (deuterium or similar) replaces the role
`energy_cost` used to play in ship pricing.

## Construction takes time

Buildings and ships complete after N ticks, queued per planet. Instant construction
removes the reason to log in again, which is the core rhythm for a game played by
colleagues checking in a couple of times a day.

## `Planet` is its own model

`Sector` stays the **strategic** layer: map position, ownership, defense, NPC faction,
distance to the core. `Planet` is the **management** layer: mines, structures, build
queue. A planet belongs to an empire and sits in a sector.

Rationale: putting mine and building columns on `sectors` would give all ~225 rows
per galaxy fields that only a handful use, and would make capturing a sector imply
inheriting a second management screen.

**One planet per empire for now.** Raising that limit later should be a matter of
relaxing a validation, not a redesign.

## Seasons exist structurally but do not end

`Galaxy` remains the season container, so seasons stay possible. There is no season
length, end condition, or reset for now — the running galaxy is effectively infinite
so the game can be developed and played against continuously.
