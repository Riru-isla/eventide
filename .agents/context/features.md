# Eventide — Features

## Implemented

- [x] Procedural galaxy generation (15×15 demo, scalable).
- [x] Escalating NPC factions toward the galaxy core.
- [x] Empire roles: `cultivator`, `foundry`, `warden` with resource bonuses.
- [x] Tick-based resource income.
- [x] Session-based empire login/logout with passwords.
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
- Fleets are created with ships "from thin air" when dispatching (existing prototype behavior).
- Galaxy map only supports selecting origin/target for fleet dispatch; no direct sector navigation.
- Only one galaxy exists; it is hardcoded as the root page.
