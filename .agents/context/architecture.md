# Eventide — Architecture

## Models

| Model | Responsibility |
|-------|----------------|
| `Galaxy` | One game instance. Has dimensions, current tick, status enum. |
| `Sector` | A coordinate on the galaxy map. Has kind, owner (empire or NPC faction), resource rates, defense. |
| `User` | Login account. Devise-backed, authenticated by `username` (no email column). Has many `Player`. |
| `Empire` | Player's in-game presence. Belongs to a `Player`, has a role, resources, and a home sector. |
| `Player` | A commander within one galaxy. Belongs to a `User` and a `Galaxy`; has many empires. |
| `NpcFaction` | AI faction controlling sectors; stronger closer to the core. |
| `Planet` | The management layer: what an empire builds on. Belongs to an empire and sits in a sector. One per empire for now. |
| `PlanetStructure` | A structure on a planet, stored as `kind` + `level`. |
| `BuildOrder` | A queued construction job. Only the front of the queue has a `completes_at_tick`. |
| `Structure` | **Not** an Active Record model — a static Ruby catalogue of every buildable structure and its balance numbers. |
| `Fleet` | Group of ships moving between sectors or orbiting a sector. JSON `ships` stores counts by ship type name. |
| `ShipType` | Static ship definitions with costs and stats. Some are role-locked. |

## Key Associations

- `User` has many `Player`; a `Player` belongs to exactly one `Galaxy`.
- `Galaxy` has many `Sector`, `Player`, `Empire`, `NpcFaction`, `Fleet`.
- `Empire` belongs to `Player` and `Galaxy`; has many `Sector` (owned), `Fleet`.
- `Sector` belongs to `Galaxy`; optionally belongs to `Empire` or `NpcFaction`.
- `Fleet` belongs to `Empire`, `Galaxy`, `origin_sector`; optionally belongs to `target_sector`.

## Services

- `GalaxyGenerator` — procedural galaxy creation, NPC placement, seeded empires.
- `EmpireFounder` — creates a player, empire, home sector, and starting fleet. Used by
  both galaxy seeding and signup so demo and real empires are identical.
- `HomeSectorPlacement` — picks a starting sector from fixed ring slots around the core.
- `PlanetEconomy` — the planet's numbers: energy production/draw, and resource output
  reported as named contributions that sum to the total, so the screen can show where
  each figure comes from. Balance changes belong here.
- `BuildQueue` — adds orders, starts the next one, and applies finished ones. Resources
  are charged when an order is queued, not when it completes. A finished order chains
  the next from *its* completion tick, so downtime does not lose queue time.
- `TickProcessor` — runs each tick: completes builds, collects resources, resolves
  fleet arrivals and combat.

## Jobs

- `TickJob` — wrapper around `TickProcessor`. With no argument it advances every
  active galaxy; Solid Queue runs it every minute from `config/recurring.yml`. It does
  **not** reschedule itself, so a failed run cannot silently end the season.

## Controllers

- `Devise::SessionsController` — login/logout (default Devise, custom views under `app/views/users/sessions`).
- `Users::RegistrationsController` — signup; also creates the player, empire, home sector, and starting fleet.
- `PlanetsController` — `#show` is the planet Overview (and the site root); `#structures`
  serves the Resources and Facilities sections, which are the same structure list
  filtered by catalogue category.
- `PlanetStructuresController` — adds an upgrade to the planet's build queue.
- `GalaxiesController` — main map view.
- `SectorsController` — sector detail / planet management.
- `FleetsController` — dispatch fleets from a sector to a target.
- `ShipyardController` — build ships at owned sectors.

## Authentication

- Devise on `User`, with `config.authentication_keys = [:username]`.
- `ApplicationController` calls `authenticate_user!` on every request.
- `current_player` resolves the current user's player in `Galaxy.first`;
  `current_empire` reads `session[:empire_id]`, falling back to that player's
  first empire.

### Known gaps

- There is **no `email` column**, so `:recoverable` cannot work — `/users/password/new`
  raises `no such column: users.email` on submit. The login and signup views do not
  link to it, so it is only reachable by typing the URL.
- `/users/edit` (Devise's generated account-edit view) renders an email field and
  fails for the same reason.
- The unused generated views under `app/views/users/{confirmations,unlocks,mailer}`
  belong to modules that are not enabled.

## Databases

- Primary: `storage/development.sqlite3` / `storage/test.sqlite3`
- Queue: `storage/development_queue.sqlite3` / `storage/test_queue.sqlite3`

Configured in `config/database.yml`; Solid Queue connects to the `:queue` database in development/production.
