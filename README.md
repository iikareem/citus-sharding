# Citus Sharding Lab

Local hands-on lab for horizontal sharding with [Citus](https://github.com/citusdata/citus) on PostgreSQL.

The cluster is three containers: one coordinator and two workers. You connect only to the coordinator. Citus routes queries and places shards on the workers.

## Prerequisites

- Docker and Docker Compose
- A SQL client (DataGrip, `psql`, etc.)
- Ports: host **5433** is published for the coordinator (avoids clashing with a local Postgres on 5432)

## Architecture

```text
                 DataGrip / psql
                        │
                        ▼
              ┌─────────────────┐
              │   coordinator   │  localhost:5433
              │  plan / route   │
              └────────┬────────┘
                       │  citus bridge network
           ┌───────────┴───────────┐
           ▼                       ▼
     ┌──────────┐            ┌──────────┐
     │ worker1  │            │ worker2  │
     │  shards  │            │  shards  │
     └──────────┘            └──────────┘
```

| Service | Role | Host access |
|---------|------|-------------|
| `coordinator` | Client endpoint, metadata, query planning | `localhost:5433` |
| `worker1` | Shard storage / local execution | internal only |
| `worker2` | Shard storage / local execution | internal only |
| `register-workers` | One-shot: registers workers on the coordinator | exits after setup |

Workers are registered with `citus_add_node` (see `scripts/register-workers.sh`). Without that step you have three isolated Postgres instances, not a cluster.

## Quick start

```bash
cp .env.example .env   # optional; defaults are fine for local use
docker compose up -d
docker compose logs register-workers
```

Confirm workers are active:

```sql
SELECT * FROM citus_get_active_worker_nodes();
```

**DataGrip / JDBC**

| Setting | Value |
|---------|--------|
| Host | `localhost` |
| Port | `5433` |
| User | `postgres` |
| Password | `citus` |
| Database | `postgres` |

**CLI**

```bash
docker compose exec coordinator psql -U postgres -d postgres
```

**Stop**

```bash
docker compose down      # stop containers
docker compose down -v   # stop and remove volumes (full reset)
```

## Lab path

| Step | Topic | Artifacts |
|------|--------|-----------|
| 01 | Bring up cluster | `docker-compose.yml`, `scripts/register-workers.sh` |
| 02 | Schema + seed | `sql/02_schema.sql`, `sql/02_seed.sql` |
| 03 | Reference + distribute | `sql/03_distribute.sql` |
| 04 | Bulk seed + single-shard / colocated queries | `sql/04_bulk_seed.sql` |
| 05 | Cross-shard / missing shard-key queries | (next) |
| 06 | Inspect placement and routing | `citus_shards`, placement SQL |
| 07 | Add a worker and rebalance | (next) |

### Steps 02–03

Run against the coordinator, in order:

1. `sql/02_schema.sql` — create tables (local on coordinator)
2. `sql/02_seed.sql` — sample tenants, orders, items
3. `sql/03_distribute.sql` — reference `tenants`; distribute `orders` / `order_items` by `tenant_id`

```bash
docker compose exec -T coordinator psql -U postgres -d postgres < sql/02_schema.sql
docker compose exec -T coordinator psql -U postgres -d postgres < sql/02_seed.sql
docker compose exec -T coordinator psql -U postgres -d postgres < sql/03_distribute.sql
```

If distribute fails because a primary key does not include `tenant_id`, run `sql/03a_fix_pkeys.sql`, then `03_distribute.sql` again.

Citus rule: on a distributed table, `PRIMARY KEY` / `UNIQUE` must include the distribution column.

## Domain model

Multi-tenant commerce. Shard key: `tenant_id`.

| Table | Citus type | Notes |
|-------|------------|--------|
| `tenants` | Reference | Full copy on every node; small shared lookup |
| `orders` | Distributed (`tenant_id`) | Rows split across workers |
| `order_items` | Distributed (`tenant_id`) | Same key as `orders` for colocation |

Primary keys on distributed tables are `(tenant_id, id)` so they satisfy Citus constraint rules.

## Concepts covered

**Coordinator vs workers**  
Clients talk to the coordinator. Workers store shards and run local SQL. The coordinator plans, routes, and merges results.

**Table types**

| Type | Placement |
|------|-----------|
| Local | Coordinator only |
| Reference | Full replica on every node |
| Distributed | Partitioned into shards by a distribution column |

**Shards**  
A shard is one physical slice of a distributed table (e.g. `orders_102015` on a worker). By default Citus creates 32 shards per distributed table and spreads them across workers (~16 each with two workers). Most shards start empty; rows land in a shard via `hash(tenant_id)`.

**Colocation**  
Related tables distributed on the same key share a colocation group, so a given `tenant_id` maps to the same worker. Joins scoped by that key can run locally.

## Useful checks

```sql
-- Cluster nodes
SELECT * FROM citus_get_active_worker_nodes();

-- Table / shard map
SELECT table_name::text, citus_table_type, nodename, COUNT(*) AS shards
FROM citus_shards
GROUP BY 1, 2, 3
ORDER BY 1, 3;

-- Which worker owns each tenant's orders
SELECT t.tenant_id, t.order_rows, t.shard_id, p.nodename AS worker
FROM (
  SELECT tenant_id,
         COUNT(*) AS order_rows,
         get_shard_id_for_distribution_column('orders', tenant_id) AS shard_id
  FROM orders
  GROUP BY tenant_id
) t
JOIN pg_dist_shard_placement p ON p.shardid = t.shard_id
ORDER BY t.tenant_id;
```

## Learning outcomes

After this lab you should be able to:

- Run a small Citus cluster locally
- Choose when to use reference vs distributed tables
- Pick a distribution key that matches query filters and joins
- Inspect shard placement and explain coordinator/worker execution
- Recognize why missing the shard key in `WHERE` causes fan-out

## Out of scope

- Production HA (Patroni, failover, managed Citus/Azure)
- Multi-region and CDC pipelines
- Application service layer (SQL-only lab)

## Repository layout

```text
.
├── docker-compose.yml
├── .env.example
├── scripts/
│   └── register-workers.sh
├── sql/
│   ├── 02_schema.sql
│   ├── 02_seed.sql
│   ├── 03_distribute.sql
│   └── 03a_fix_pkeys.sql
└── README.md
```

## License

Personal learning project. Use freely for study and experimentation.
