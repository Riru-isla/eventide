# Eventide — Idea Parking Lot

Things worth exploring **later**. Nothing here is planned, scheduled, or agreed —
it is a place to park thoughts so they are not lost or re-derived. Move an entry
into a GitHub issue when it becomes real work.

---

## Solar systems instead of a single planet view

**Status:** idea only — not planned.

Instead of managing one planet per empire, an empire could manage a whole **solar
system**: a star, several planets and moons, each with its own body type, size, and
modifiers, closer to how Stellaris presents a system.

Why it could be good:

- Much more room to min-max. Bodies differ in slot count, base yields, and hazards,
  so two players with identical tech still make different decisions.
- Specialisation becomes spatial — a mining moon, an agri-world, a research station —
  instead of one planet that does everything a bit.
- It gives the galaxy map a natural second zoom level: galaxy → system → body.
- It scales the "1 planet now, N later" plan without inventing a second concept:
  more planets simply means more bodies in the system you already hold.

What it would cost / open questions:

- Do resources pool at the system level, the empire level, or stay per-body?
- The UI grows a whole navigation layer; the planet screen would need to work as a
  body screen first, and stay readable.
- Balance surface expands a lot — every body type is a new set of numbers to tune.
- Probably wants the planet screen to be genuinely good first, so there is something
  proven to replicate per body.

Related: the `Planet` model split discussed for M2 is deliberately shaped so this stays
possible — a `Planet` belonging to a `Sector` can later become one of several bodies
belonging to a system without reworking the sector/strategic layer.
