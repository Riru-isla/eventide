# Eventide — Agent Guidance

This file helps future AI sessions get oriented quickly when working on Eventide.

## First thing to do when resuming

Read the context files in this order:

1. `.agents/context/project-overview.md` — goals, stack, run instructions.
2. `.agents/context/architecture.md` — models, services, controllers.
3. `.agents/context/design-decisions.md` — settled design calls; build on these.
4. `.agents/context/features.md` — what is implemented and what is next.
5. `.agents/context/runbook.md` — commands for running, testing, git.

Speculative ideas that are explicitly **not** planned live in `.agents/ideas/ideas.md`.

Then check `git status` and `git log --oneline -10` to see the current state.

## Project conventions

- **Language**: Ruby 3.3.12, Rails 8.1, SQLite.
- **Frontend**: Hotwire / Turbo / Stimulus, Tailwind CSS, SVG map.
- **Tests**: RSpec with FactoryBot and Shoulda Matchers. **100% line coverage is required.**
- **Background jobs**: Solid Queue uses the `:queue` database.
- **Auth**: Devise on `User`, keyed on `username` (there is no email column). The
  active empire is tracked separately in `session[:empire_id]`.

## Before making changes

1. Check the GitHub milestone/issues for the current focus (e.g., Planet Management v1).
2. Create a feature branch: `git checkout -b feature/issue-short-name`.
3. Run the test suite to confirm baseline: `bundle exec rspec`.

## After making changes

1. Run `bundle exec rspec`. All tests must pass.
2. Check coverage: `coverage/index.html` must show 100%.
3. Update or add specs for any new code.
4. Update `.agents/context/features.md` if the feature backlog changes.
5. Update `.agents/context/architecture.md` if models/services change significantly.
6. Commit with a clear message referencing the issue number when possible.

## How to run locally

```bash
bin/rails db:reset db:seed   # reset demo galaxy
bin/dev                       # Rails + Tailwind
bin/rails solid_queue:start   # background jobs
bin/rails runner 'TickJob.perform_now(Galaxy.first.id)'  # first tick
```

Open `http://localhost:3333`. Demo empires use password `eventide`.

## How to test

```bash
bundle exec rspec
open coverage/index.html
```

Or run every gate the same way CI does (style, audits, Brakeman, specs, seeds):

```bash
bin/ci
```

## Context maintenance

When a major feature lands, update the context files so the next session does not rely only on git history. In particular:

- Add completed items to `.agents/context/features.md`.
- Update architecture diagrams/descriptions in `.agents/context/architecture.md`.
- Record new run commands in `.agents/context/runbook.md`.
- Keep `.agents/context/project-overview.md` up to date with the latest commit and known state.

## GitHub

- Repository: `https://github.com/Riru-isla/eventide`
- Use GitHub Issues and milestones for task tracking.
- CI workflow file was removed for initial push (token lacked `workflow` scope). Re-add `.github/workflows/ci.yml` when ready.
