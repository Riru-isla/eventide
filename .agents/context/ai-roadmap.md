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

## What is missing

Adjacency, an economy, production, fleets, decisions, and a way for players to see any of
it happening.

---

## 1. Adjacency and awakening

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

## 2. A faction economy

Income is the sum of `metal_rate` and `crystal_rate` across the systems a faction holds,
which is data that already exists and is currently ignored. A stockpile on `NpcFaction`,
and a per-tick collection that only runs for awake factions.

Multipliers by power level and by the galaxy's `threat_level` — a level 5 faction in a
`brutal` galaxy earns far faster than a level 1 in a `calm` one, without either breaking a
rule.

**What a player notices:** nothing yet, directly. But this is the step that makes every
later one meaningful, because now a faction can be **starved**: take its systems and its
ability to answer shrinks.

---

## 3. Production — defences first

Awake factions spend on raising `defense_strength` at their own systems, over ticks, at a
rate set by their build-speed multiplier. Defences before fleets deliberately: it needs no
new movement or combat code, and it is immediately felt.

**What a player notices:** a faction you woke and then ignored **gets harder**. Hitting the
frontier early is now worth something, and dithering costs. That is real pressure from a
small amount of code.

---

## 4. Fleets and raids

`Fleet` currently `belongs_to :empire`, so a faction cannot own one. Make a fleet belong to
*either*, teach combat to resolve NPC-versus-player, and let factions build ships from the
same `ShipType` catalogue at the same costs and build times.

**Real fleets rather than abstract effects**, because the whole design rests on being able
to watch it coming: a raid should be a thing on the map with travel time that can be
intercepted, met in orbit, or beaten before it lands.

**What a player notices:** the game starts pushing back. This is the big one.

**Risk:** a faction that raids while everyone is asleep can grind a planet down
unanswerably. Raids must cost the raider and be survivable — being caught out of position
should hurt, not end you.

---

## 5. Threat and temperament

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

## 6. Telegraphing

Scouting reports, and a visible faction posture on the galaxy view. A faction massing for
three days is only tense if there is a way to find out.

**This is not polish.** Sophisticated behaviour a player cannot observe is
indistinguishable from randomness — if the AI ever feels mechanical, this is the first
thing to reach for, not a bigger brain.

---

## Sequencing

The order is forced by dependency: awakening decides *when* a faction acts, the economy and
production give it the *means*, behaviour decides *what*, and telegraphing makes any of it
land. Steps 1–3 need no new combat code at all, which is why they come first.
