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

## Population underneath crew

**Status:** idea only — revisit when the AI and combat are designed.

Today crew appears from nothing: the Pilot Academy trains it, Crew Quarters hold it, hulls
cost it. The richer version, closer to Stellaris, is a **population** layer beneath that:
people grow in habitats, are fed by farms, and specialise into crew, miners, researchers
and so on.

### The thing that makes it work

**Stellaris does not actually make you micromanage pops.** They auto-assign to jobs by
priority; the manual tuning is optional min-maxing on top. A casual player never touches
it and the planet still runs.

That is the whole trick, and it answers the "is this casual friendly?" worry: **automatic
allocation by default, manual override for people who want to optimise.** The min-maxer
gets a dial, the once-a-day player never learns it exists. If population is ever built, it
must arrive that way round.

### Field evidence from a competitor

*Nexus: Downfall* (browser 4X, launched August 2026) ships a settings toggle:

> "Auto-assign population — automatically assigns the maximum available population to a
> structure whenever it finishes upgrading."

Worth reading as evidence rather than as a feature to copy. A game adds that switch when
assigning the maximum is the right answer nearly every time — at which point the step is a
confirmation dialog, not a decision, and the toggle exists to skip it. It is possible
assignment is genuinely interesting there and the switch is only kindness for the routine
90%, but the shape of it suggests otherwise. It is also precisely what the note below
already warned against building.

The conclusion: **population only earns its place if allocation is contested.** If you
cannot staff everything, then staffing the refinery starves the shipyard, there is no
"maximum available" to auto-assign, and the toggle is meaningless because the decision is
real. If it is not contested, population is crew with extra clicks — and crew already
exists.

### The real risk to watch

The feeling of *having* to log in does not come from systems existing — it comes from
things that **expire or stall while you are away**. Eventide already has two: storage caps
(a full silo throws income away every tick) and the build queue (an idle queue is wasted
hours). Population adds no third pressure *if* allocation is automatic and nothing decays.

What would genuinely hurt: pops that starve, riot, or need reassigning after every
building completes. Do not build that. The cumulative weight of these pressures is what
kills a game, not any single one.

### Why it waits

The allocation decision only becomes interesting when demands **compete** — pops in the
mines mean fewer as crew, and you cannot have both. That tension needs a reason to want
crew badly, which means combat that actually costs ships. Until the AI pushes back,
"miners or crew?" has one obvious answer and is a queue rather than a decision.

Population and combat want designing together.

### How it slots in without a rewrite

Crew stays exactly what it is — a resource hulls cost, with its own HUD slot and storage.
Only its *source* changes:

- Today: Pilot Academy **generates** crew.
- Later: Pilot Academy **converts** population into crew, and a farm/habitat pair generates
  population the way the Academy generates crew now.

### Open question parked with it

Crew currently dies with its ship. Letting some survive raises a chain of questions that
need combat designed first: what fraction reaches escape pods, do they return to the pool
instantly or travel home, and can they be intercepted on the way? Deliberately deferred —
see the crew decision in `design-decisions.md`.

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

---

## An LLM driving faction behaviour

**Status:** idea only — deliberately not planned. A non-LLM faction AI is being built
instead.

The appeal is obvious: a faction that reasons about what the players are doing and
responds in character would feel alive in a way a rules engine has to work hard to fake.

### Why it does not fit *this* game, now

- **It would share a laptop with the game server.** A local model on Ollama competes for
  CPU and memory with Puma, Solid Queue and SQLite on the same machine, during a session
  people are playing over the LAN. The tick is one minute; a model that takes ten seconds
  to decide has eaten a sixth of it, per faction.
- **A paid API moves the problem rather than solving it.** Now there is a per-tick cost,
  a network dependency for a game hosted on a desk, and a key to manage.
- **Called rarely enough to be affordable, it stops feeling alive.** The thing that reads
  as intelligence is *responsiveness* — noticing a raid and answering it. A model
  consulted every few hours produces considered decisions nobody connects to their own
  actions, which is worse than a fast dumb one.

### What it would actually be good at, if revisited

Worth separating two very different jobs:

- **Voice, not decisions.** Naming a faction, writing the message it sends when it wakes,
  describing why it is coming for a particular commander, the intercepted-transmission
  flavour on a scouting report. Low frequency, no latency budget, failure is cosmetic, and
  it is exactly where a rules engine reads as canned.
- **Per-tick decisions.** High frequency, latency-bound, needs to be deterministic enough
  to test and tune, and failure is a faction doing something incoherent. This is the part
  a utility-scored AI does better *and* cheaper.

So if this is ever revisited, the shape is probably: the rules engine decides what a
faction does, and a model is asked — rarely, asynchronously, with a cached fallback — to
say it in character. That splits along the grain of what each is good at, and nothing
breaks when the model is unavailable.

### Related

The behaviour system being built instead is in `design-decisions.md`. If it ends up
feeling mechanical, the fix to try first is more legible telegraphing, not a bigger brain
— players read intent from what they can *see* a faction doing.

---

## Factions that grow while dormant

**Status:** idea only — a harder difficulty mode for later. The shipped behaviour is that
dormant factions are static.

Today a faction accumulates nothing until something wakes it: it starts with a war chest
sized by its power level and spends only once roused. The alternative is that factions run
their economy from tick zero, so one left alone for three weeks is genuinely more dangerous
than one met on day two.

### Why it is not the default

It punishes **slowness**, which is the one thing that should not cost players. A group
playing two hours a day would face a harder galaxy than one playing six, through no
decision either of them made — the same failure the "no clock until a neighbour falls"
rule exists to prevent.

A cooldown between builds only softens it: 50 ticks across a 40,320-tick season is still
800 builds. A slower ramp to the same place, with more dials to tune.

### Why it is still interesting

As an **opt-in difficulty setting** it is a different game rather than a broken one, because
the group has chosen it. "The galaxy does not wait for you" is a legitimate mode, and it
would reward scouting early and picking fights on your own schedule.

### What it would need

- A growth rate slow enough that a late-met faction is *harder*, not *unbeatable* —
  probably logarithmic, or capped at some multiple of its starting strength.
- Per-tick economy for every faction rather than only awake ones. On a large galaxy that
  is 25 factions ticking from the start, where today they cost nothing at all.
- A way to see it, or it is invisible: a faction that quietly tripled is only interesting
  if scouting can tell you before you commit.

Probably belongs beside the existing threat and awareness settings on the new-galaxy form.

