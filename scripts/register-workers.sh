#!/usr/bin/env bash
# Register worker1 / worker2 / worker3 on the coordinator (safe to re-run).
set -euo pipefail

COORDINATOR_HOST="${COORDINATOR_HOST:-coordinator}"
export PGPASSWORD="${PGPASSWORD:-citus}"

echo "Waiting for coordinator and workers..."
until pg_isready -h "$COORDINATOR_HOST" -U "${PGUSER:-postgres}" >/dev/null 2>&1; do sleep 1; done
until pg_isready -h worker1 -U "${PGUSER:-postgres}" >/dev/null 2>&1; do sleep 1; done
until pg_isready -h worker2 -U "${PGUSER:-postgres}" >/dev/null 2>&1; do sleep 1; done
until pg_isready -h worker3 -U "${PGUSER:-postgres}" >/dev/null 2>&1; do sleep 1; done

psql -h "$COORDINATOR_HOST" -U "${PGUSER:-postgres}" -d postgres <<'SQL'
SELECT citus_set_coordinator_host('coordinator', 5432);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_dist_node WHERE nodename = 'worker1' AND nodeport = 5432
  ) THEN
    PERFORM citus_add_node('worker1', 5432);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_dist_node WHERE nodename = 'worker2' AND nodeport = 5432
  ) THEN
    PERFORM citus_add_node('worker2', 5432);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_dist_node WHERE nodename = 'worker3' AND nodeport = 5432
  ) THEN
    PERFORM citus_add_node('worker3', 5432);
  END IF;
END $$;

SELECT nodename, nodeport, isactive
FROM pg_dist_node
ORDER BY nodeid;
SQL

echo "Workers registered."
