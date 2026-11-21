-- Step 05: real skew demo — one hot tenant blows up one worker
-- Tenant 1 hashes to a single shard on one worker; flooding it creates imbalance.

\echo '=== BEFORE (balanced-ish) ==='
SELECT table_name::text,
       nodename,
       count(*) AS shards,
       pg_size_pretty(sum(shard_size)) AS size
FROM citus_shards
WHERE table_name IN ('orders'::regclass, 'order_items'::regclass)
GROUP BY 1, 2
ORDER BY 1, 2;

\echo '=== Tenant 1 placement ==='
SELECT get_shard_id_for_distribution_column('orders', 1::bigint) AS shard,
       nodename
FROM citus_shards
WHERE table_name = 'orders'::regclass
  AND shardid = get_shard_id_for_distribution_column('orders', 1::bigint);

-- Hot tenant: 1 tenant, 200 orders, 200 line items each = 40,000 items on ONE shard/worker
INSERT INTO orders (id, tenant_id, status, total_cents)
SELECT 900000 + g, 1, 'paid', 9999
FROM generate_series(1, 200) AS g
ON CONFLICT (tenant_id, id) DO NOTHING;

INSERT INTO order_items (id, tenant_id, order_id, sku, quantity, unit_cents)
SELECT
    (900000 + o.n) * 1000 + i.n,
    1,
    900000 + o.n,
    'HOT-SKU-' || i.n,
    1,
    100
FROM generate_series(1, 200) AS o(n)
CROSS JOIN generate_series(1, 200) AS i(n)
ON CONFLICT (tenant_id, id) DO NOTHING;

\echo '=== AFTER (skewed: hot tenant on one worker) ==='
SELECT table_name::text,
       nodename,
       count(*) AS shards,
       pg_size_pretty(sum(shard_size)) AS size
FROM citus_shards
WHERE table_name IN ('orders'::regclass, 'order_items'::regclass)
GROUP BY 1, 2
ORDER BY 1, 2;

\echo '=== Hottest order_items shards ==='
SELECT shardid, nodename, pg_size_pretty(shard_size) AS size
FROM citus_shards
WHERE table_name = 'order_items'::regclass
ORDER BY shard_size DESC
LIMIT 5;
