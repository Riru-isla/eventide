# Eventide — Features

## Implemented

- [x] Procedural galaxy generation (15×15 demo, scalable).
- [x] Escalating NPC factions toward the galaxy core.
- [x] Empire roles: `cultivator`, `foundry`, `warden` with resource bonuses.
- [x] Tick-based resource income.
- [x] Player signup and login with username/password (Devise, username-keyed).
- [x] Session-based active empire (`session[:empire_id]`).
- [x] Galaxy map (SVG) showing sectors, owners, and core.
- [x] Sector detail view with resource generation rates.
- [x] **Planet Overview** (the site root): what is building, extractor levels, the energy
      balance, and the planet's vital statistics.
- [x] **Resources and Facilities** sections: structures with levels, an energy bus, and an
      output breakdown showing every contributing modifier.
- [x] **Build queue**: upgrades are charged up front, take ticks to complete, and the
      Robotics Bay shortens them.
- [x] **Storage caps**: silos set how much the empire can hold; income stops when full.
      A stockpile already over capacity is kept, not confiscated.
- [x] Facilities: Metal and Crystal Refineries, Metal and Crystal Silos, Robotics Bay,
      Research Center, Shipyard.
- [x] **Research**: eight empire-wide technologies in a small tree, gated on Research
      Center level and on each other. Every one has a real effect — extraction, energy,
      storage, build speed, travel time, fleet attack, and surviving a failed attack.
- [x] Energy as a balance: a deficit throttles extraction to 30% and exempts energy buildings.
- [x] Fleet dispatch from owned sectors to targets.
- [x] Basic combat: attacker power vs defender strength.
- [x] **Shipyard**: five hulls gated on Shipyard level and research, built in a timed
      queue and delivered into the planet's garrison.
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
- The Fleet nav section is still a placeholder shown disabled, and needs a design
  decision first: garrison, ground defences, or something else.
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
