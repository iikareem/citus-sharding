# Citus Sharding Lab

Hands-on practice for learning **horizontal sharding with Citus** on PostgreSQL.

## Goal

Build intuition for when sharding helps, how Citus routes data, and what breaks (or gets expensive) when you pick a bad distribution key or write cross-shard queries.

By the end of this lab you should be able to:

- Stand up a small Citus cluster locally (coordinator + workers)
- Distribute tables and choose a shard key on purpose
- Explain reference tables vs distributed tables
- Write colocated queries and recognize cross-shard pain
- Inspect shard placement and rebalance after adding capacity

## What we will learn

### 1. Cluster basics
- Coordinator vs worker roles
- How clients talk only to the coordinator
- How Citus extends Postgres (not a separate database product)

### 2. Table types
- **Local tables** — normal Postgres, stay on the coordinator
- **Reference tables** — full copy on every node (small, shared lookup data)
- **Distributed tables** — rows split across shards by a distribution column

### 3. Choosing a distribution key
- Good keys: high cardinality, matches query filters/joins (e.g. `tenant_id`, `user_id`)
- Bad keys: low cardinality, hot partitions, keys you rarely filter on
- Why the same key across related tables enables **colocation**

### 4. Query patterns
- Single-shard / colocated joins (cheap)
- Cross-shard joins and fan-out queries (costly)
- Aggregations and how Citus pushes work to workers
- Using `EXPLAIN` to see multi-node plans

### 5. Data lifecycle
- Inserts and routing by shard key
- Looking up which shard/worker owns a row
- Adding a worker and rebalancing shards
- What “rebalance” means operationally (move shards, not rewrite the app)

### 6. Practical tradeoffs
- When sharding is worth it vs a single Postgres
- App constraints (always send the shard key when you can)
- Consistency / transaction boundaries across shards
- Ops surface: monitoring, backups, schema changes on distributed tables

## Lab path (practice order)

| Step | Topic | Outcome |
|------|--------|---------|
| 01 | Bring up cluster | Coordinator + 2 workers via Docker Compose |
| 02 | Schema + seed | Tenants, orders, order items model |
| 03 | Distribute | Mark reference vs distributed tables |
| 04 | Good queries | Filter/join on `tenant_id`, measure locality |
| 05 | Bad queries | Cross-tenant joins / missing shard key |
| 06 | Inspect shards | Placement, shard counts, routing |
| 07 | Scale out | Add a worker, rebalance, re-check placement |

## Suggested domain model

Multi-tenant commerce (simple, realistic shard key):

- `tenants` — reference or lightly used lookup
- `orders` — distributed by `tenant_id`
- `order_items` — distributed by `tenant_id` (colocated with orders)

This keeps joins local when you always scope by tenant.

## Out of scope (for now)

- Production HA / Patroni / cloud Citus managed ops
- Complex CDC or multi-region setups
- Full app backend — SQL + scripts are enough to learn the model

## Quick start (step 01)

```bash
cp .env.example .env          # optional; defaults work for local lab
docker compose up -d
docker compose logs register-workers   # should show both workers registered
```

> Host port defaults to **5433** so it does not clash with another local Postgres on 5432.

Connect to the **coordinator** only:

```bash
docker compose exec coordinator psql -U postgres -d postgres
```

**DataGrip:** host `localhost`, port `5433`, user `postgres`, password `citus`, database `postgres`.

Then check the cluster:

```sql
SELECT * FROM citus_get_active_worker_nodes();
```

Stop / reset:

```bash
docker compose down          # keep data volumes if any were added later
docker compose down -v       # full reset
```

### Cluster layout

| Service | Role | Reachable from host |
|---------|------|---------------------|
| `coordinator` | SQL entrypoint, metadata | `localhost:5433` (host) → `5432` inside container |
| `worker1` | shard storage | internal (`citus` bridge network) |
| `worker2` | shard storage | internal (`citus` bridge network) |
| `register-workers` | one-shot init | exits after registering nodes |

## Step 02–03: schema, seed, distribute

In DataGrip (connected to `localhost:5433`), run in order:

1. `sql/02_schema.sql` — create tables (coordinator only)
2. `sql/02_seed.sql` — insert sample tenants/orders
3. `sql/03_distribute.sql` — reference + distribute by `tenant_id`

If distribute fails on PK/UNIQUE, run `sql/03a_fix_pkeys.sql` then `03_distribute.sql` again.
(Citus requires primary keys on distributed tables to include `tenant_id`.)

Or from the terminal:

```bash
docker compose exec -T coordinator psql -U postgres -d postgres < sql/02_schema.sql
docker compose exec -T coordinator psql -U postgres -d postgres < sql/02_seed.sql
docker compose exec -T coordinator psql -U postgres -d postgres < sql/03_distribute.sql
```

Quick checks after seed (before or after distribute):

```sql
SELECT * FROM tenants;
SELECT tenant_id, COUNT(*) FROM orders GROUP BY 1 ORDER BY 1;
```
