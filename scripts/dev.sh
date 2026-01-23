#!/bin/bash
# Development helper script

set -e

case "$1" in
  start)
    echo "Starting development environment..."
    docker compose up -d db
    echo "Waiting for PostgreSQL..."
    sleep 3
    docker compose up app
    ;;

  stop)
    echo "Stopping development environment..."
    docker compose down
    ;;

  test)
    echo "Running tests..."
    docker compose up -d db_test
    sleep 2
    docker compose --profile test run --rm test
    ;;

  tdd)
    echo "Starting TDD mode (watching for changes)..."
    docker compose up -d db_test
    sleep 2
    docker compose --profile tdd run --rm test_watch
    ;;

  shell)
    echo "Opening IEx shell..."
    docker compose exec app iex -S mix
    ;;

  migrate)
    echo "Running migrations..."
    docker compose exec app mix ecto.migrate
    ;;

  reset)
    echo "Resetting database..."
    docker compose exec app mix ecto.reset
    ;;

  quality)
    echo "Running code quality checks..."
    docker compose exec app mix quality
    ;;

  logs)
    docker compose logs -f
    ;;

  *)
    echo "Productive Work Groups - Development Commands"
    echo ""
    echo "Usage: ./scripts/dev.sh <command>"
    echo ""
    echo "Commands:"
    echo "  start    - Start development server"
    echo "  stop     - Stop all containers"
    echo "  test     - Run test suite"
    echo "  tdd      - Start TDD mode (watch for changes)"
    echo "  shell    - Open IEx shell"
    echo "  migrate  - Run database migrations"
    echo "  reset    - Reset database"
    echo "  quality  - Run code quality checks"
    echo "  logs     - Follow container logs"
    ;;
esac
