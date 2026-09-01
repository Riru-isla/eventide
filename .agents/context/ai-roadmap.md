# Faction AI — roadmap

## The principle

**Factions play by the players' rules.** Same ship catalogue, same costs, same build times,
same travel speeds, same need to hold ground to earn anything. Their advantage is
*multipliers*, never exemptions.

Why that is worth the extra work:

- **Legible.** A player who scouts a faction can reason about what it is capable of,
  because it obeys rules they already understand. A faction that conjures ships is noise.
- **Starvable.** If a faction's income comes from the systems it holds, taking them is a
  strategy. Instant spawning makes attrition pointless.
- **Tunable.** Difficulty becomes a number — build speed, yield — rather than a second
  rulebook to balance and debug.

## What factions already have

More than it looks, because generation laid the groundwork:

| | |
|---|---|
| Territory | one sector each |
| Garrisons | systems carrying `defense_strength` |
| Income, latent | every system already carries `metal_rate` and `crystal_rate` |
| A state | `aggression` — unaware → dormant → aware → hunting → total_war |
| A trait | `awareness`, rolled per faction and scaled by the galaxy's setting |
| Something to lose | `capital_system` — a faction dies when it falls |

Note that `Planet` and `Fleet` both `belong_to :empire` today, so neither can be owned by a
faction. That is one consistent change rather than two hacks: both become ownable by an
empire *or* a faction.

## What is missing

Adjacency, an economy, production, fleets, decisions, and a way for players to see any of
it happening.

---

## Where this stands

Steps 1–3 are built. A faction wakes only when something falls next door, holds territory
and worlds, banks a war chest it spends only once roused, and hardens its garrisons up to a
ceiling. Factions became **empires** partway through — see `design-decisions.md` — which
deleted most of what step 4 was going to cost.

**Combat comes before fleets and raids.** Raiding is a form of combat, and the current
resolution cannot support it: a winning attacker loses *nothing*, and the fight only fires
when the defender is a faction. Fixing that is felt by players immediately, and leaves the
machinery ready for faction fleets rather than building both at once.

Not yet true, despite the foundation being done:

- **Factions have no fleets.** They can own one — `Fleet` belongs to an empire, and
  `power`/`retreat!` work fine for an NPC — but nothing builds one.
- **Combat is one-directional.** Point a faction fleet at a commander's system and the
  fight never fires; the fleet parks there.
- **Nothing escalates past `aware`.** `rouse!` is the only writer, so `hunting` and
  `total_war` are unreachable and their `TEMPO` entries are dead until threat exists.
- **`fallen_outcome: decay` is a setting with no behaviour.** A beaten faction's systems
  keep full defence and never rot.

---

## 1. Adjacency and awakening — **done**

Persist which sectors border which — the generator already builds the ownership grid, so
it is one scan over it — then wire the design already settled: a faction has **no clock at
all** while every neighbour stands; an adjacent capital falling rolls against `awareness`
and the power gap; a lost roll starts the clock rather than doing nothing; direct contact
wakes a faction regardless of the front.

`TickProcessor#resolve_combat` does not currently mark a faction fallen even when its
capital is taken, so nothing can trigger. That is the first thing to fix.

**What a player notices:** taking a capital ends a faction, and the galaxy reacts — the
neighbours stir. Nothing hunts them yet.

**Guarding principle:** punish recklessness, not slowness. Nothing escalates ahead of where
players have actually pushed.

---

## 2. Worlds and an economy — **done**

Factions get **real infrastructure**, for the same reason they get real fleets: if a
shipyard is what lets a player build a ship, a faction conjuring one from a stockpile is
not playing by the same rules. It also reuses `Planet`, `Structure` and `Shipyard` rather
than inventing a parallel abstraction beside them.

**Two to five worlds per faction, spread through its territory** — count scaling with power
level, chosen at generation from systems it already garrisons, and **never the capital**.
Not one, and not all 133 garrisons. Keeping industry off the capital matters: the capital already ends the faction when it
falls, so infrastructure there would never be worth attacking on its own. Kept elsewhere,
a player can **cripple a faction's ability to answer without finishing it**, and
"cripple, then kill" becomes a real strategy rather than a race to one coordinate.

Income has two sources, exactly as it does for a player: the `metal_rate` and
`crystal_rate` of every system held — data that already exists and is ignored today — plus
whatever their worlds' extractors produce. Both only accrue once awake.

**Starting stock:** each faction begins with a war chest sized to its power level, and
spends nothing until roused. Resources are the *stock*; build time is the *tempo* — a full
stockpile means a woken faction never stalls on money, not that a fleet appears from
nowhere. The number is derived from the player storage formula so the two economies stay
calibrated against each other:

```ruby
capacity = Structure::BASE_STORAGE * (Structure::STORAGE_GROWTH ** silo_level(power_level))
```

Dormant factions cost **nothing** — no income, no production, no decisions — which matters
when a large galaxy holds 25 of them. The alternative, factions that grow from tick zero,
is parked in `ideas.md` as an opt-in difficulty mode: it punishes slowness, which is the
one thing that should not cost players.

**What a player notices:** nothing yet, directly. But this is what makes every later step
matter, because a faction can now be **starved** — take its systems and its ability to
answer shrinks.

---

## 3. Production — defences first — **done**

Awake factions spend on raising `defense_strength` and on their own structures, over ticks,
at a rate set by their build-speed multiplier. Defences before fleets deliberately: it
needs no new movement or combat code, and it is immediately felt.

### Aggression is how many hours a day the faction plays

The clarifying idea, and worth keeping as the spine of the whole design. Aggression is not
a mood; it is an engagement level, and it answers "what should each state change?" without
inventing anything per state.

| State | plays like | tempo | repertoire |
|---|---|---|---|
| `unaware` | offline | — | nothing |
| `dormant` | knows you exist, is not looking | — | nothing until struck |
| `aware` | two hours a day, reactive | slow | rebuild losses, harden the front |
| `hunting` | on daily, engaged | medium | + build ships, scout, raid |
| `total_war` | eight hours, micromanaging | fast | + research, upgrade worlds, coordinated strikes |

It drives two table lookups, not branching logic: a **multiplier** on how much gets done
per tick, and an **eligible action set**. The scoring loop is unchanged — actions outside
the repertoire simply are not candidates. The difference in feel between a `total_war`
faction and an `aware` one is large for very little code.

Composes with the power-level and threat-level multipliers. This is also where an
escalating cooldown belongs: shaping how a faction fights once roused, rather than a
separate system governing what it hoarded before anyone met it.

### Aggression and threat are orthogonal

Easy to conflate, worth keeping apart:

- **Aggression** — *how hard it is playing*. Global to the faction, escalates through
  awakening, decays never.
- **Threat, per commander** — *who it is playing against*. Local, rises with what you do
  to it, decays over time.

A `total_war` faction with no threat on anyone builds and researches furiously with nobody
to hit. An `aware` faction carrying high threat on one commander comes for **them**,
slowly. Both are needed.

**What a player notices:** a faction you woke and then ignored **gets harder**. Hitting the
frontier early is now worth something, and dithering costs.

---

## 4. The combat rewrite

Raiding is a form of combat, so this comes first: the current resolution cannot carry it,
and fixing it is felt by commanders straight away rather than only once the AI can attack.

What is wrong with what exists:

```ruby
if attacker_power >= defender_power
  # attacker takes the system and loses NOTHING
else
  # attacker loses EVERYTHING, bar an armour retreat
end
```

- **Winning is free.** Survivable while only commanders attack, because they choose when to
  commit. Point it the other way and one faction fleet grinds a planet down forever at no
  cost.
- **It is binary.** A thousand fighters against 999 defence is a flawless victory; against
  1,001 it is annihilation. Nothing in between, and no reason to bring a margin.
- **It only fires when the defender is a faction.** A faction fleet arriving at a
  commander's system falls through to `join_garrison!` and simply parks there.
- **Composition does not matter.** Only the total matters, so hulls are interchangeable.
- **Nothing is reported.** A fleet leaves and either the system changes hands or the fleet
  is gone.

What it has to deliver:

- Casualties on **both** sides, in proportion to what was faced.
- Resolution that does not care who owns the attacker or the defender.
- An outcome a player can read afterwards and learn from.
- A home system that can be **raided rather than captured**, so being away for a weekend
  cannot end a run.

Deliberately still out: staging several fleets into one strike, and scouting — that is
telegraphing, further down.

---

## 5. Fleets and raids *(after combat)*

`Fleet` currently `belongs_to :empire`, so a faction cannot own one. Make a fleet belong to
*either*, teach combat to resolve NPC-versus-player, and let factions build ships from the
same `ShipType` catalogue at the same costs and build times.

**Real fleets rather than abstract effects**, because the whole design rests on being able
to watch it coming: a raid should be a thing on the map with travel time that can be
intercepted, met in orbit, or beaten before it lands.

**What a player notices:** the game starts pushing back. This is the big one.

### How far a faction may expand

- **More systems inside its own sector** — yes. It already owns that ground, it needs no
  model change, and it is how a faction you woke and then ignored grows in *territory*
  rather than only in stockpile.
- **Keeping systems taken from a player** — yes. `System#npc_faction_id` is already
  independent of `sector_id`, so holdings can reach outside a faction's own sector without
  any change. It also makes losing ground genuinely costly.
- **Founding new sectors** — no. Sector boundaries are fixed at generation and are
  load-bearing for adjacency and awakening; a faction creating one would ripple through
  all of it. Parked.

**Risk:** a faction that raids while everyone is asleep can grind a planet down
unanswerably. Raids must cost the raider and be survivable — being caught out of position
should hurt, not end you.

### Open: what falling actually does to a faction's territory

`fallen_at_tick` is set when a capital is taken, and it stops the faction rolling into
anything. But its remaining systems still carry its `npc_faction_id`, still hold full
defence, and still have to be cleared one at a time — so falling currently means nothing
to the ground it held.

It is a **galaxy setting** — `fallen_outcome`, chosen when a session is created — so
alternatives are an entry in `Galaxy::FALLEN_OUTCOMES` rather than a migration. The column
exists already; the behaviour is what waits for this step.

### `decay` — the default, and the only one so far

The faction is **out of the game**: it stops acting, stops producing, stops defending
itself as an organisation. What it held does not vanish, it **rots**:

- Its remaining systems and worlds keep their id but stop being reinforced.
- `defense_strength` decays over some number of ticks, so a system that was a hard fight
  becomes an easy one the longer it is left.
- Stockpiles and yields decay with it, so there is still something worth taking — a player
  who mops up a dead faction's territory pillages a diminishing prize.

The shape of that is deliberate: clearing up after a kill stays *worth doing* without being
urgent, and the reward for doing it promptly is that there is more left.

### Alternatives worth keeping in mind

- **Neutral** — survivors simply stop being hostile, so the territory becomes free ground.
  Simplest, but taking a capital then means the sector is instantly solved.
- **Defect** — the remnant joins a neighbouring faction, which makes killing a capital
  *feed* the next enemy. Dangerous, and genuinely interesting.
- **Leaderless** — they fight on at full strength but cannot rebuild or coordinate.

Whichever is picked has to be **legible**: someone who takes a capital should be able to
tell what they just won.

---

## 6. Threat and temperament

**Threat**, held per faction *per commander*: rises when you take their systems, hit their
capital, or are seen in their space; decays over time. It is both the "different behaviour
at different threat levels" dial and the reason retaliation lands on **the player who
actually provoked them** — the single detail that most reads as intelligence.

**Temperament**, rolled at generation beside `awareness`. Same situation, different
faction, different answer: a Raider bleeds you early and never masses; a Warden fortifies
and is brutal to invade; a Reclaimer fixates on retaking what it lost; a Hunter masses
quietly and goes for a homeworld.

**The loop:** score fortify / retake / raid / mass / strike / probe from temperament ×
situation, take the best, add enough noise that it is not solvable. Deterministic, fast,
testable — no model involved. See `ideas.md` for why an LLM is parked.

**What a player notices:** factions have character, and the one they hurt is the one that
comes for them.

---

## 7. Telegraphing

Scouting reports, and a visible faction posture on the galaxy view. A faction massing for
three days is only tense if there is a way to find out.

**This is not polish.** Sophisticated behaviour a player cannot observe is
indistinguishable from randomness — if the AI ever feels mechanical, this is the first
thing to reach for, not a bigger brain.

---

## Sequencing

The order is forced by dependency: awakening decides *when* a faction acts, the economy and
production give it the *means*, combat decides how a fight *resolves*, behaviour decides
*what* to do, and telegraphing makes any of it land.

Steps 1–3 needed no combat code at all, which is why they came first. Combat then comes
before fleets because raiding is a form of combat and the current resolution cannot carry
it — and because a better fight is something commanders feel immediately, long before the
AI is able to start one.
