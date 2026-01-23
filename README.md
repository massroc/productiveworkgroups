# Productive Work Groups

A self-guided team collaboration web application that guides teams through the "Six Criteria of Productive Work" workshop without requiring a trained facilitator.

Built with Elixir/Phoenix LiveView and PostgreSQL, deployed on Fly.io.

## Tech Stack

- **Backend**: Elixir 1.17 / Phoenix 1.7 with LiveView
- **Database**: PostgreSQL 16
- **Frontend**: Phoenix LiveView + Tailwind CSS
- **Deployment**: Fly.io (Sydney region)
- **CI/CD**: GitHub Actions

## Development Setup

### Prerequisites

- Docker and Docker Compose

### Quick Start

```bash
# Start development server (Phoenix + PostgreSQL)
docker compose up

# Access the app at http://localhost:4000
```

### Development Commands

```bash
# Start development environment
docker compose up

# Run tests
docker compose --profile test run --rm test

# TDD mode (watches for file changes)
docker compose --profile tdd run --rm test_watch

# Open IEx shell
docker compose exec app iex -S mix

# Run database migrations
docker compose exec app mix ecto.migrate

# Reset database
docker compose exec app mix ecto.reset

# Run code quality checks (format, credo, sobelow, dialyzer)
docker compose exec app mix quality
```

Alternatively, use the helper script:

```bash
chmod +x scripts/dev.sh
./scripts/dev.sh start   # Start dev server
./scripts/dev.sh tdd     # TDD mode
./scripts/dev.sh test    # Run tests
./scripts/dev.sh shell   # IEx shell
```

## Testing (TDD)

The project is configured for Test-Driven Development:

1. **Start TDD mode**: `docker compose --profile tdd run --rm test_watch`
2. **Write a failing test** in `test/`
3. **Implement code** in `lib/`
4. **Tests auto-run** on file changes
5. Press Enter to re-run all tests

### Test Libraries

- **ExUnit** - Unit testing
- **ExMachina** - Test data factories
- **Mox** - Mocking
- **Wallaby** - Browser/E2E testing
- **ExCoveralls** - Code coverage

## CI/CD Pipeline

GitHub Actions runs on every push and pull request:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Test      │     │  Dialyzer   │     │   Deploy    │
│             │     │             │     │  (main only)│
│ • Format    │     │ • Type      │     │             │
│ • Credo     │────▶│   checking  │────▶│ • Fly.io    │
│ • Sobelow   │     │             │     │   deploy    │
│ • Tests     │     │             │     │             │
│ • Coverage  │     │             │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
```

### Pipeline Stages

1. **Test Job**
   - Code formatting check
   - Credo static analysis
   - Sobelow security scan
   - ExUnit tests with PostgreSQL
   - Coverage report to Codecov

2. **Dialyzer Job**
   - Static type analysis
   - PLT caching for faster runs

3. **Deploy Job** (main branch only)
   - Automatic deployment to Fly.io

## Production Deployment

### Fly.io Resources

| Resource | Name | Region |
|----------|------|--------|
| App | `productive-workgroups` | Sydney (syd) |
| Database | `productive-workgroups-db` | Sydney (syd) |
| URL | https://productive-workgroups.fly.dev | |

### Manual Deployment

```bash
# Deploy to Fly.io
flyctl deploy

# View logs
flyctl logs

# Open production console
flyctl ssh console

# Check app status
flyctl status
```

### Environment Variables

Set via Fly.io secrets:

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection string (auto-set) |
| `SECRET_KEY_BASE` | Phoenix secret key |
| `PHX_HOST` | Production hostname |

## Project Structure

```
├── lib/
│   ├── productive_workgroups/        # Business logic (contexts)
│   │   ├── application.ex
│   │   └── repo.ex
│   └── productive_workgroups_web/    # Web layer
│       ├── components/               # UI components
│       ├── controllers/              # Error handlers
│       ├── live/                     # LiveView modules
│       ├── endpoint.ex
│       ├── router.ex
│       └── telemetry.ex
├── test/
│   ├── support/                      # Test helpers & factories
│   └── productive_workgroups_web/    # Web tests
├── priv/
│   ├── repo/migrations/              # Database migrations
│   └── static/                       # Static assets
├── assets/                           # Frontend (JS, CSS)
├── config/                           # Environment configs
├── docker-compose.yml                # Development environment
├── Dockerfile                        # Production build
├── Dockerfile.dev                    # Development build
└── fly.toml                          # Fly.io configuration
```

## Documentation

- [REQUIREMENTS.md](REQUIREMENTS.md) - Functional requirements
- [SOLUTION_DESIGN.md](SOLUTION_DESIGN.md) - Technical architecture

## License

Private - All rights reserved.
