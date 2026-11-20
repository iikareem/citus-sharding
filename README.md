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

## Next

Scaffold Docker Compose, init SQL, and short exercise scripts that follow the lab path above.
