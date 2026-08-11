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
| `Fleet` | Group of ships moving between sectors or orbiting a sector. JSON `ships` stores counts by ship type name. |
| `ShipType` | Static ship definitions with costs and stats. Some are role-locked. |

## Key Associations

- `User` has many `Player`; a `Player` belongs to exactly one `Galaxy`.
- `Galaxy` has many `Sector`, `Player`, `Empire`, `NpcFaction`, `Fleet`.
- `Empire` belongs to `Player` and `Galaxy`; has many `Sector` (owned), `Fleet`.
- `Sector` belongs to `Galaxy`; optionally belongs to `Empire` or `NpcFaction`.
- `Fleet` belongs to `Empire`, `Galaxy`, `origin_sector`; optionally belongs to `target_sector`.

## Services

- `GalaxyGenerator` — procedural galaxy creation, NPC placement, player home sectors, starting fleets.
- `TickProcessor` — runs each tick: resource collection, fleet arrival resolution, simple combat.

## Jobs

- `TickJob` — wrapper around `TickProcessor`. Reschedules itself every minute.

## Controllers

- `Devise::SessionsController` — login/logout (default Devise, custom views under `app/views/users/sessions`).
- `Users::RegistrationsController` — signup; also creates the player, empire, home sector, and starting fleet.
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
