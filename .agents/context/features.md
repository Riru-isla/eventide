# Eventide — Features

## Implemented

- [x] Procedural galaxy generation (15×15 demo, scalable).
- [x] Escalating NPC factions toward the galaxy core.
- [x] Empire roles: `cultivator`, `foundry`, `warden` with resource bonuses.
- [x] Tick-based resource income.
- [x] Player signup and login with username/password (Devise, username-keyed).
- [x] Session-based active empire (`session[:empire_id]`).
- [x] Galaxy map (SVG) showing sectors, owners, and core.
- [x] Sector / planet detail view with resource generation rates.
- [x] Fleet dispatch from owned sectors to targets.
- [x] Basic combat: attacker power vs defender strength.
- [x] Ship construction at owned sectors (instant build).
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

- Ship construction is instant; no build queue yet.
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
