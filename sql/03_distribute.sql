-- Step 03: turn local tables into Citus reference / distributed tables
-- Run AFTER 02_schema.sql and 02_seed.sql

-- Small shared lookup → full copy on every node
SELECT create_reference_table('tenants');

-- Big tables → shard by tenant_id (same key = colocated joins)
SELECT create_distributed_table('orders', 'tenant_id');
SELECT create_distributed_table('order_items', 'tenant_id');

-- Sanity checks
SELECT logicalrelid::regclass AS table_name,
       partmethod,
       partkey
FROM pg_dist_partition
ORDER BY 1;

SELECT table_name::text,
       citus_table_type,
       nodename,
       COUNT(*) AS shards
FROM citus_shards
GROUP BY 1, 2, 3
ORDER BY 1, 3;
