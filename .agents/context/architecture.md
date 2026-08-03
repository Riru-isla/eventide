# Eventide — Architecture

## Models

| Model | Responsibility |
|-------|----------------|
| `Galaxy` | One game instance. Has dimensions, current tick, status enum. |
| `Sector` | A coordinate on the galaxy map. Has kind, owner (empire or NPC faction), resource rates, defense. |
| `Empire` | Player's in-game presence. Belongs to a `Player`, has a role, resources, home sector, password for login. |
| `Player` | Just a name. One player can have many empires across galaxies. |
| `NpcFaction` | AI faction controlling sectors; stronger closer to the core. |
| `Fleet` | Group of ships moving between sectors or orbiting a sector. JSON `ships` stores counts by ship type name. |
| `ShipType` | Static ship definitions with costs and stats. Some are role-locked. |

## Key Associations

- `Galaxy` has many `Sector`, `Empire`, `NpcFaction`, `Fleet`.
- `Empire` belongs to `Player` and `Galaxy`; has many `Sector` (owned), `Fleet`.
- `Sector` belongs to `Galaxy`; optionally belongs to `Empire` or `NpcFaction`.
- `Fleet` belongs to `Empire`, `Galaxy`, `origin_sector`; optionally belongs to `target_sector`.

## Services

- `GalaxyGenerator` — procedural galaxy creation, NPC placement, player home sectors, starting fleets.
- `TickProcessor` — runs each tick: resource collection, fleet arrival resolution, simple combat.

## Jobs

- `TickJob` — wrapper around `TickProcessor`. Reschedules itself every minute.

## Controllers

- `SessionsController` — empire login/logout.
- `GalaxiesController` — main map view.
- `SectorsController` — sector detail / planet management.
- `FleetsController` — dispatch fleets from a sector to a target.
- `ShipyardController` — build ships at owned sectors.

## Authentication

- Session-based: `session[:empire_id]`.
- `ApplicationController#current_empire` + `require_login`.
- Empire passwords use `has_secure_password` (bcrypt).

## Databases

- Primary: `storage/development.sqlite3` / `storage/test.sqlite3`
- Queue: `storage/development_queue.sqlite3` / `storage/test_queue.sqlite3`

Configured in `config/database.yml`; Solid Queue connects to the `:queue` database in development/production.
