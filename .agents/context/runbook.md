# Eventide — Runbook

## Reset everything and seed demo data

```bash
cd /Users/disla/projects/eventide
bin/rails db:reset db:seed
```

## Host a session

One command runs everything — web server, asset watcher, and the job worker
(Solid Queue runs inside Puma via `SOLID_QUEUE_IN_PUMA`):

```bash
cd /Users/disla/projects/eventide
bin/dev
```

Ticks are scheduled by Solid Queue from `config/recurring.yml` (every minute) and
start on their own. No manual first tick is needed. To force one:

```bash
bin/rails runner 'TickJob.perform_now'                  # every active galaxy
bin/rails runner 'TickJob.perform_now(Galaxy.first.id)' # one galaxy
```

### Letting other people connect

`bin/dev` binds to `0.0.0.0`, so anyone on the same network can join. Give them:

```bash
echo "http://$(ipconfig getifaddr en0):3000"
```

They sign up at `/users/sign_up` and get their own empire and home sector.

## Demo accounts

After `db:seed`, three demo accounts exist:

- Username: `ada`, Password: `eventide`
- Username: `ben`, Password: `eventide`
- Username: `cara`, Password: `eventide`

New players can sign up at `/users/sign_up`.

## After pulling schema changes

```bash
bin/rails db:prepare
```

Creates any new database, including the cable database that live updates need.

## Run tests

```bash
cd /Users/disla/projects/eventide
bundle exec rspec
```

View coverage report:
```bash
open coverage/index.html
```

Run every CI gate locally (style, audits, Brakeman, specs, seeds):
```bash
bin/ci
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
