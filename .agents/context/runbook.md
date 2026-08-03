# Eventide — Runbook

## Reset everything and seed demo data

```bash
cd /Users/disla/projects/eventide
bin/rails db:reset db:seed
```

## Start the game locally

Terminal 1 — Rails + assets:
```bash
cd /Users/disla/projects/eventide
bin/dev
```

Terminal 2 — background jobs:
```bash
cd /Users/disla/projects/eventide
bin/rails solid_queue:start
```

Terminal 3 — first tick:
```bash
cd /Users/disla/projects/eventide
bin/rails runner 'TickJob.perform_now(Galaxy.first.id)'
```

After the first tick, `TickJob` reschedules itself every minute.

## Demo accounts

After `db:seed`, three demo accounts exist:

- Username: `ada`, Password: `eventide`
- Username: `ben`, Password: `eventide`
- Username: `cara`, Password: `eventide`

New players can sign up at `/users/new`.

## Run tests

```bash
cd /Users/disla/projects/eventide
bundle exec rspec
```

View coverage report:
```bash
open coverage/index.html
```

## Useful Rails commands

```bash
bin/rails console
bin/rails routes
bin/rails db:migrate
bin/rails db:test:prepare
```

## Git workflow

```bash
git status
git log --oneline -10
git push origin main
```

Note: CI workflow file was removed for the initial push because the GitHub token lacked `workflow` scope. Re-add `.github/workflows/ci.yml` when ready.
