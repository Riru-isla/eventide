# Eventide — Features

## Implemented

- [x] Procedural galaxy generation (15×15 demo, scalable).
- [x] Escalating NPC factions toward the galaxy core.
- [x] Empire roles: `cultivator`, `foundry`, `warden` with resource bonuses.
- [x] Tick-based resource income.
- [x] Player signup and login with username/password (Devise, username-keyed).
- [x] Session-based active empire (`session[:empire_id]`).
- [x] **Galaxy view**: a drawn galaxy — core bulge, spiral arms, star field on canvas —
      with sectors laid over it, plus the commander roster and the closest approach to
      the core. Read-only; fleets are dispatched from the Fleet screen.
- [x] Sector detail view with resource generation rates.
- [x] **Planet Overview** (the site root): what is building, extractor levels, the energy
      balance, and the planet's vital statistics.
- [x] **Resources and Facilities** sections: structures with levels, an energy bus, and an
      output breakdown showing every contributing modifier.
- [x] **Build queue**: upgrades are charged up front, take ticks to complete, and the
      Robotics Bay shortens them.
- [x] **Storage caps**: silos set how much the empire can hold; mining stops when full.
      Shipments and loot may overfill to 1.5x the cap, so a gift never bounces off a
      topped-up recipient. A stockpile already over capacity is kept, not confiscated.
- [x] Facilities: Metal and Crystal Refineries, Metal and Crystal Silos, Pilot Academy,
      Crew Quarters, Robotics Bay, Research Center, Shipyard.
- [x] **Defences**: Light Turret, Ion Turret and Planetary Shield, gated on Shipyard
      level and research. They raise the sector's defence and draw energy.
- [x] **Structure prerequisites**: a structure can require other structures and
      technologies; locked rows name what is missing.
- [x] **Crew**: a third stored resource, trained at the Pilot Academy and held in Crew
      Quarters. Hulls cost crew, and it dies with the ship.
- [x] **Research**: eight empire-wide technologies in a small tree, gated on Research
      Center level and on each other. Every one has a real effect — extraction, energy,
      storage, build speed, travel time, fleet attack, and surviving a failed attack.
- [x] Energy as a balance: a deficit throttles extraction to 30% and exempts energy buildings.
- [x] Fleet dispatch from owned sectors to targets.
- [x] **Shipments**: send resources to another commander's planet. Cargo is charged at
      dispatch, delivered on arrival within the recipient's storage cap, and the fleet
      turns around and comes home by itself.
- [x] **Fleet screen**: what is under way, with holds and time out.
- [x] **Inbound card** on the Overview: appears only when something is on its way,
      showing shipments and their holds, your own fleets returning, and hostile fleets
      flagged separately.
- [x] Basic combat: attacker power vs defender strength.
- [x] **Shipyard**: five hulls gated on Shipyard level and research, built in a timed
      queue and delivered into the planet's garrison.
- [x] **Live updates**: a tick broadcasts a Turbo refresh, so resources, build queues
      and research update in place without reloading.
- [x] RSpec test suite with 100% line coverage.

## In Progress / Next Up

- [ ] **Fleet management**: split/merge fleets, view all fleets.
- [ ] **Build queue**: ships take ticks to build instead of instant.
- [ ] **Galaxy map interactions**: click sector to view/dispatch without using the sidebar list.
- [ ] **Win condition**: capture the core sector.
- [ ] **NPC aggression**: factions counter-attack or expand.
- [ ] **Multi-galaxy support**: create new games/seasons from UI.
- [ ] **Role-locked ship types**: only certain roles can build specialized ships.
- [ ] **Alliances / shared vision**: cooperative tools.

## Known Rough Edges

- Build queues advance in ticks, so they only progress while the server is running.
- Defences raise `Sector#total_defence`, which combat already reads — but nothing
  attacks a player yet, so their benefit is future. Their energy draw is real today.
- Fleet movement has no screen of its own; it belongs with the galaxy layer.
- `ShipType#energy_cost` and `Empire#energy` are dead columns since energy became a
  balance.
- **Fleet dispatch does not check or spend ships.** `FleetsController#create` takes
  ship counts straight from `params[:fleet][:ships]`, so any player can dispatch an
  arbitrarily large fleet for free and take the core on the first tick. Until this is
  fixed, no economy or balance change can be meaningfully playtested.
- Password recovery and `/users/edit` are broken (no `email` column) — see
  `architecture.md` "Known gaps".
- `sector_color` runs one query per sector, so the map issues ~225 queries per load.
- Signup picks a home sector with `sectors.where(...).to_a.sample`: it loads every
  sector, can place a new player next to the core, and raises `NoMethodError` (not the
  rescued `RecordInvalid`) when no free sector remains.
- Galaxy map only supports selecting origin/target for fleet dispatch; no direct sector navigation.
- Only one galaxy exists; it is hardcoded as the root page.
