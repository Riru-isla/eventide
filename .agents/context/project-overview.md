# Eventide — Project Overview

Eventide is a cooperative, PvE-first, sci-fi web strategy game. Players control empires on a shared galaxy map, expand toward the core, and fight escalating NPC factions together.

## Current Goal

Build a playable local prototype for 2–4 friends connecting to a Rails server on one laptop. A full "season" should last roughly 2–4 weeks.

## Core Design Pillars

- **PvE / cooperative**: players work together against AI factions, not against each other.
- **Race to the center**: the galaxy core holds the strongest enemies and the best rewards.
- **Asymmetric roles**: empires specialize in cultivating, building, or military.
- **Background maintenance**: ticks run automatically; players log in to manage empires.

## Tech Stack

- **Backend**: Ruby 3.3.12, Rails 8.1.3, SQLite
- **Frontend**: Hotwire/Turbo/Stimulus, Tailwind CSS, SVG galaxy map
- **Background jobs**: Solid Queue (separate `queue` database)
- **Testing**: RSpec, FactoryBot, Shoulda Matchers, SimpleCov (100% line coverage)

## Repository

- GitHub: `https://github.com/Riru-isla/eventide`
- Local path: `/Users/disla/projects/eventide`

## How to Run

```bash
cd /Users/disla/projects/eventide
bin/rails db:reset db:seed   # reset galaxy and demo empires
bin/dev                       # starts Rails + Tailwind watcher
```

In a second terminal:

```bash
bin/rails solid_queue:start   # background job runner
```

Then trigger the first tick:

```bash
bin/rails runner 'TickJob.perform_now(Galaxy.first.id)'
```

Open `http://localhost:3333`.

### Auth

- Devise on `User`, authenticated by `username` (no email column).
- Sign up at `/users/sign_up` with username, password, and empire role; the
  commander name is taken from the username.
- Existing demo accounts: `ada`, `ben`, `cara` — password `eventide`.
- Devise holds the user session; `session[:empire_id]` tracks the active empire.

## Last Known State

- All 94 specs passing, 100% line coverage (314/314).
- `bin/ci` green: rubocop, bundler-audit, importmap audit, Brakeman, RSpec, seeds.
- Latest commit: Devise-based auth replacing the hand-rolled sessions controller.
