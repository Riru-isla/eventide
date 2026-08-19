# Eventide — Design Decisions

Decisions that are settled and that later work should build on rather than revisit.
Speculative ideas live in `.agents/ideas/ideas.md`.

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

Buildings complete after N ticks, queued per planet. Instant construction removes the
reason to log in again, which is the core rhythm for a game played by colleagues
checking in a couple of times a day.

**Implemented** for structures and ships. Durations grow with level (or quantity) and
are shortened by the Robotics Bay and Construction Technology.

Durations are counted in **ticks**, so a queue only advances while the server is up.
That is the same limitation as the game-time model below, and `completes_at_tick` is
the field that changes if game time moves to wall-clock timestamps.

## Resources are capped

Each resource has a storage capacity, set by that resource's silo. Income stops once a
store is full, so a player cannot bank indefinitely while logged out — the same
pressure OGame uses to make people come back and spend.

A stockpile already above capacity is left alone rather than trimmed. Running out of
room should stall growth, never destroy what someone has banked.

**Deliveries may overfill, mining may not.** There are two ceilings:

- `storage_capacity` — where an empire's own extraction stops. Unchanged, and what
  keeps silos worth building.
- `overflow_capacity` — 1.5x that, and the ceiling for anything arriving from outside:
  shipments and battle loot.

Without this, gifting is unreliable rather than merely capped: a shipment to someone
who happens to be topped up makes a pointless round trip and comes home, and the sender
cannot see the recipient's storage to know in advance. In a cooperative game that is the
wrong failure mode. Generosity and spoils get past the ceiling; your own mining does not.

Nothing decays. A store sitting above the cap waits there until it is spent — a drain
would be exactly the "log in or lose it" pressure this project avoids elsewhere.

Deliberately **not** added yet: protected resources that cannot be raided. Nothing in
Eventide steals from anyone today — `plunder!` mints loot from the captured sector's
rates rather than debiting a victim — so protection would guard against a mechanic that
does not exist, and its shape depends entirely on how raiding ends up working. It
belongs with that design, likely as a field on a Vault structure.

Silos sit on the planet but resources belong to the empire. With one planet per empire
those are the same thing; this is the seam to revisit for multiple planets.

## Research is empire-wide, and gated

Technologies apply to every planet and fleet an empire holds. Each has prerequisites —
a minimum Research Center level, and for the deeper ones, levels in other technologies —
which is what makes the list a tree rather than a menu. An empire researches one project
at a time.

Technologies sharing an effect stack additively (Weapons and Laser both feed the attack
multiplier), so a new technology never has to know what already exists.

## Crew is a third resource, and it dies with its ship

Crew is trained at the Pilot Academy, held in Crew Quarters, and **spent** when a hull is
laid down — not lent. It sails with the ship and never returns to the pool, so losing a
fleet costs the crew aboard as well as the hulls. That makes combat expensive on purpose.

Rejected: crew as a *capacity* that ships occupy and release, with an active/inactive
toggle. It would have been arithmetic rather than a decision — always crew the best hulls
you can and mothball the rest. The interesting version of that idea is **fleet capacity**
(field N ships, you choose which), which is parked until combat gives ship composition a
reason to vary.

Also rejected for now: energy upkeep on active ships, and letting some crew escape a
destroyed ship. The second opens questions — survival odds, transit home, interception —
that need combat designed first.

Crew is throttled by an energy deficit like all other generation, and capped by Crew
Quarters, which grow far more slowly than a silo (x1.35 against x1.75) because crew is
meant to stay scarce.

A population layer underneath crew is parked in `.agents/ideas/ideas.md`.

## Defences are structures, not ships

Emplacements are immobile and permanent, so they are levelled `Structure` entries in
the `defence` category rather than counted hulls. That reuses the whole structure
system — catalogue, build queue, upgrade UI, groups — with no new tables.

They cost no crew, which makes them the military option available to an empire that
has none. They do draw energy, so a heavy defensive line throttles the economy: that
cost is real today even though their benefit waits on an AI that attacks.

`Sector#total_defence` combines the sector's own strength with its planet's
emplacements, and combat already reads it, so defences take effect the moment
something attacks a player.

## Structures can have prerequisites

A structure may require other structures and technologies, the same gating shape as
research and hulls. Locked rows are dimmed and name exactly what is missing.

## Ships are gated like research

Hulls need a Shipyard of a given level plus, for the heavier ones, technologies — the
same gating shape as research so both screens read alike.

Fleets store counts keyed by the catalogue **key**, never the display name, so a hull
can be renamed without orphaning every fleet holding one. Every hull stat is used:
attack feeds combat, cargo decides how much plunder a victory brings home, and
speed_factor sets travel time from the fleet's slowest hull.

## Shipments are a fleet mission

A fleet carries a `mission` — attack or transport — and a `cargo` hold. A transport
unloads into whoever holds the destination and turns straight around; `origin_sector`
is untouched throughout, so coming home is a matter of clearing the target.

Cargo leaves the sender's stores **at dispatch**, so nothing in transit can be spent
twice. It lands capped by the recipient's storage, and anything that will not fit —
their silos were full, or nobody holds the destination — stays in the hold and comes
back rather than evaporating.

Ships settling anywhere **join the fleet already in orbit** rather than forming a
second one. Two orbiting fleets at the same sector would strand the ships in the
second: the dispatch form, the shipyard and the garrison count all read the first only.

Any player's planet is a valid destination. This is a cooperative game — shipping to
another commander is the point, not an exploit.

## The galaxy is big because engagements, not travel, make a season

A four-week season needs several hundred fights, not slower ticks. Travel is cheap at any
size — a researched fast fleet crosses a 150x150 map in about half an hour — so map size
buys **exploration and room**, while the count of NPC-held sectors buys **duration**. The
two are separate dials and live in `Galaxy::SIZES`.

Size is fixed when a session is created and never changes: growing a galaxy under players
who have already explored it would mean seeding new space into somewhere already scouted.

Bands are measured from the **rim inward**, so the faction a player meets first is the
weakest. Each tier inward holds more sectors *and* defends them harder, so difficulty
compounds on both axes. Density rises from about 1% of a band held at the frontier to
40% at the core.

Normalising by the **inscribed** radius, not the corner distance: bands measured against
the corner would only exist diagonally, since on a 150x150 the corners are 106 from the
centre but the edge midpoints only 75.

## Factions are a ladder, and escalation is shared

Each faction holds one **capital**. Taking it ends the faction — not clearing every
sector it owns, so a tier finishes with a battle worth organising rather than a mop-up.

When a faction falls the next tier wakes **for the whole galaxy**, not just for whoever
struck the blow. Shared fate: helping the commanders who are behind becomes self-interest,
because the tier you just unlocked will hunt them too.

Aggression runs `unaware` -> `dormant` -> `aware` -> `hunting` -> `total_war`. Only the
frontier faction starts awake. Nothing reads these yet; faction behaviour is a later step.

## Screen structure

Overview, Resources and Facilities are views onto **the current planet**; Research is
empire-wide. Overview is a planet's dashboard — what is building, extractor levels, the
energy balance, and the planet's vital statistics — not an empire summary.

The game is **cooperative**, so nothing should rank players against each other. Shared
progress toward the core is the framing, never "you are behind".

## `Planet` is its own model

`System` stays the **strategic** layer: map position, ownership, defense, NPC faction,
distance to the core. `Planet` is the **management** layer: mines, structures, build
queue. A planet belongs to an empire and sits in a system.

Rationale: putting mine and building columns on `systems` would give tens of thousands
of rows per galaxy fields that only a handful use, and would make capturing a system
imply inheriting a second management screen.

**One planet per empire for now.** Raising that limit later should be a matter of
relaxing a validation, not a redesign.

## Seasons exist structurally but do not end

`Galaxy` remains the season container, so seasons stay possible. There is no season
length, end condition, or reset for now — the running galaxy is effectively infinite
so the game can be developed and played against continuously.

## "Sector" means a region; a single coordinate is a "system"

A `System` is one coordinate: one planet, one place a fleet flies to. A `Sector` is a
large region of a few hundred to a few thousand systems.

Rationale: the region sense is both the conventional sci-fi meaning and the word already
being used to design the galaxy, and renaming was far cheaper than living with a
permanent mismatch between how we talk and what the code says. It also leaves room for
the parked idea of a system holding several bodies without needing another rename.

## The galaxy is a disc with the core on its rim

The playable area is the disc inscribed in the grid — corners get no systems at all — and
the core sits about 0.72 of the radius out from the centre, at a random bearing per
galaxy. The players share one sector directly opposite it.

Rationale: with a core in the middle, each player only ever cares about the wedge between
their spawn and the centre. About a third of the map lay outside the spawn ring entirely,
and whole angular sections went unvisited whenever players clustered. From the rim, the
entire disc lies between the players and the objective. The random bearing stops every
run being "head southwest".

The framing is that the map is a *section* of a galaxy rather than a whole one, so a core
at the edge needs no explanation.

## Sectors are grown from weighted seeds, not measured in bands

Every coordinate joins the seed minimising `distance / weight`, so weight is region size:
the core sector is the largest on the map and sectors grow as they near it. Three seeds
are laid along the line from the players to the core and two off the spawn's shoulders
before the rest are scattered, and the core's reach is capped outright.

Rationale: concentric bands gave a faction no interior. You skirted a ring hunting for one
coordinate on an 880-system circumference, and the faction gating everyone's progress
could sit 117 ticks from half the players while being 40 from the rest. Regions have to be
pushed into and crossed.

The structure is not decoration. Without the spine and the reach cap, the core sector —
much the heaviest on the map — sweeps around everything else and borders the spawn, so a
new commander can wander into 2,800-defence systems twenty ticks from home. Weighted
Voronoi also splits regions into detached lobes, so each sector is reduced to the
component holding its own seed and the leftovers are absorbed by their neighbours.

## Power level is depth, not a running order

Sectors are ranked by distance to the **players** and dealt levels 1–5 by that rank, with
more factions at the rim than at the core. The core sector is always the deepest level.

Rationale: bucketing raw distance left whole runs with no level 1 faction to open against
and no level 4 at all — a cliff straight from level 3 to the core. Ranking by distance to
the players rather than to the core guarantees that whatever borders the spawn is the
weakest thing on the map.

Level is *strength*, not a ladder to be climbed in order: which faction wakes next comes
from what borders a fallen one. Garrison size is a per-faction weight normalised across
the whole map, not a share of the budget split per level — splitting per level made a lone
rim faction garrison 43 systems while each of the four behind it held 16.

## A capital stands on its sector's seed

A seed is always the deepest point of its own region, so a capital placed there is
guaranteed to sit inside the territory rather than on an edge.

Rationale: the sector has to be crossed to reach the thing that ends it. Putting a capital
at the innermost edge of a band let it be clipped off a corner instead.

## Everyone spawns in one shared sector

A single spawn sector holds every commander, packed toward its seed but never closer than
six systems to each other.

Rationale: the whole group gets one frontier, shipments between players stay cheap, and
helping whoever is behind is easy. Spreading commanders to the region's edges — which a
farthest-point placement does — works against the reason for sharing a sector at all.

## Galaxies are created from a form, not seeded

A galaxy is generated from `/galaxies/new` with its own settings: name, size, NPC faction
count (minimum four), victory condition, threat level and awareness level. Teams is a
fixed field showing 1. The settings are stored on the galaxy rather than derived from
`size`, and generation runs inline — it takes two to eight seconds, happens rarely, and
the point is to look at the result immediately.

Rationale: one hardcoded world meant the only way to try a different shape was to edit
constants and reseed, which is no way to tune a campaign. Threat scales garrison defence;
awareness scales how readily each faction reacts, which the awakening step reads.

## Signing up no longer founds an empire

An account is just an account. Which galaxy to command in, and which role to take, is
chosen from the lobby afterwards, and the session remembers which empire is being played.

Rationale: with more than one galaxy, role and galaxy are properties of an empire rather
than of an account, and a player may sit out a galaxy or join a later one.

## One admin flag, granted only from the console

`users.admin` is a boolean on the **account**, so an administrator is one everywhere: in
every galaxy, and in none, since they need no empire at all. There is no per-galaxy admin.

It is granted with `bin/rails "admin:grant[username]"` and nowhere else. Nothing in the
game promotes an account, and the admin screens deliberately offer no way to — so there is
no path from being a player to being an administrator.

Rationale: the only distinction that exists is "can run the server", and a role table
would be machinery for a single bit. Administrators are the people running the game rather
than playing it, which makes the console the honest place for it. An earlier version
promoted the first account to register and let admins grant each other rights in-game;
both were dropped as more mechanism than the need justifies. If several admins with
different powers are ever wanted, that is when a super-admin tier earns its place.

`/admin` is read-only: every galaxy with its settings and tick, every account with what it
commands, and a link to inspect each galaxy's generation.

## The inspect screen is the fog-of-war stand-in

`/galaxies/:id/preview` shows an admin everything: every sector, the core, capitals, and
where commanders will land, alongside each player's distance to their first fight and
first capital.

Rationale: the numbers that decide whether a campaign is worth playing are invisible in
the game itself, and will be more so once fog of war hides them from players. Tuning needs
something that shows the whole thing at once.
