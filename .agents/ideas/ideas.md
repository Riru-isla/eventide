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

---

## Soft cap: flattening yields past a threshold

**Status:** idea only — a balance patch for later, not now.

Today the two curves are simple and opposed, set in `app/models/structure.rb`:

- **Cost** grows exponentially: `base_cost * COST_GROWTH ** level`, with `COST_GROWTH = 1.6`.
- **Yield** grows linearly: every extractor level adds a flat `base_rate` per tick.

So the price per extra unit of output already climbs steeply — level 11 buys the same
+30/tick as level 1 for roughly 110x the metal.

The idea is to make that bite harder past a point: **beyond some level the cost curve
steepens and the yield curve flattens**, so gains become genuinely marginal rather than
merely expensive. A logarithmic (or otherwise decelerating) yield term instead of a
linear one.

Why it could be good:

- A **soft cap** rather than a hard one. Nothing forbids level 30; it just stops being
  worth it, which is a better feeling than a wall.
- It makes **breadth beat depth** past the threshold — a second refinery, a silo, or
  expanding to another sector becomes the obvious play instead of grinding one
  extractor upward forever.
- It keeps very long seasons from turning into a single number going up.

What it would cost / open questions:

- Where is the threshold, and is it per structure or global? Extractors and facilities
  probably want different shapes.
- Should research be able to **raise** the threshold? That gives the Research Center a
  concrete job and a reason to exist beyond unlocking things.
- The output breakdown on the planet screen has to stay honest about it, or a player
  cannot tell why a level "did nothing". Probably a visible contribution line naming
  the diminishing-returns term.
- Retuning changes every existing save's economics. Worth doing while the galaxy is
  still disposable, or alongside a season reset.

Where it would change: `Structure#upgrade_cost` for the cost side, and the extractor
term in `PlanetEconomy#contributions` for the yield side. Both are single methods, and
the contribution list is already shaped to show an extra named term.
