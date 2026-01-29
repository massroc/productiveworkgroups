# Claude Code Instructions

This file contains instructions for AI assistants working on this codebase.

## Development Environment

**IMPORTANT: Elixir/Phoenix runs in Docker, not locally.**

Do NOT attempt to run `mix`, `elixir`, or `iex` commands directly. All Elixir commands must be run through Docker.

### Common Commands

```bash
# Compile the project
docker compose exec app mix compile

# Compile with warnings as errors
docker compose exec app mix compile --warnings-as-errors

# Run tests
docker compose --profile test run --rm test

# Run tests in TDD mode (watches for file changes)
docker compose --profile tdd run --rm test_watch

# Run a specific test file
docker compose --profile test run --rm test mix test test/path/to/test.exs

# Open IEx shell
docker compose exec app iex -S mix

# Run database migrations
docker compose exec app mix ecto.migrate

# Reset database (drop, create, migrate, seed)
docker compose exec app mix ecto.reset

# Run code quality checks
docker compose exec app mix quality
```

### Starting the Development Environment

```bash
# Start all services (Phoenix app + PostgreSQL)
docker compose up

# Start in detached mode
docker compose up -d

# View logs
docker compose logs -f app
```

### Service Names

- `app` - The Phoenix application container
- `db` - PostgreSQL database (development)
- `db_test` - PostgreSQL database (test)
- `test` - Test runner container (profile: test)
- `test_watch` - TDD watcher container (profile: tdd)

## Project Structure

- `lib/productive_workgroups/` - Business logic (contexts)
- `lib/productive_workgroups_web/` - Web layer (LiveView, controllers, components)
- `test/` - Test files
- `priv/repo/migrations/` - Database migrations
- `priv/repo/seeds.exs` - Database seed data

## Documentation

- [README.md](README.md) - Project overview and setup
- [REQUIREMENTS.md](REQUIREMENTS.md) - Functional requirements
- [SOLUTION_DESIGN.md](SOLUTION_DESIGN.md) - Technical architecture

## Testing

This project uses TDD. When making changes:

1. Run tests to verify current state: `docker compose --profile test run --rm test`
2. Make your changes
3. Run tests again to verify nothing broke
4. All 143+ tests should pass before considering work complete

## Code Style

- The project uses `mix format` for code formatting
- Run `docker compose exec app mix format` to format code
- Compilation warnings should be treated as errors in CI
