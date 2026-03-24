# Docker + PostgreSQL Local Setup (VaultTrackerAPI)

## Summary of work completed
- Installed Docker Desktop via Homebrew cask.
- Started Docker Desktop and verified Docker engine + Compose are working.
- Added a local PostgreSQL Docker Compose configuration in `docker-compose.postgres.yml`.
- Updated `.env` to point the API at local Postgres:
  - `DATABASE_URL=postgresql://vaulttracker:vaulttracker_dev_password@localhost:5432/vaulttracker`
- Updated `.env.example` with the same local Docker database URL example.
- Started the Postgres container and verified readiness and SQL connectivity.

## Files changed
- `docker-compose.postgres.yml` (new)
- `.env` (updated `DATABASE_URL`)
- `.env.example` (added local Docker `DATABASE_URL` example)

## Docker/Postgres commands
```bash
# Start PostgreSQL container
docker compose -f docker-compose.postgres.yml up -d

# Show container status
docker compose -f docker-compose.postgres.yml ps

# Stop PostgreSQL container (keep data)
docker compose -f docker-compose.postgres.yml down

# Stop PostgreSQL container and remove data volume (full reset)
docker compose -f docker-compose.postgres.yml down -v

# Check database readiness
docker exec vaulttracker-postgres pg_isready -U vaulttracker -d vaulttracker

# Run a quick SQL connectivity/version check
docker exec vaulttracker-postgres psql -U vaulttracker -d vaulttracker -c "select version();"
```

## Optional backend verification
```bash
# Start API (from project root)
./start.sh

# Health check
curl http://localhost:8000/health
```
