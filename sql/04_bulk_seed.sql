-- Step 04: bulk seed so hash sharding spreads rows across many shards / both workers.
-- Safe to re-run (ON CONFLICT DO NOTHING). Works after tables are distributed.

-- 200 tenants → enough distinct distribution keys to land on most of the 32 shards
INSERT INTO tenants (id, name)
SELECT g, 'Tenant ' || g
FROM generate_series(1, 200) AS g
ON CONFLICT (id) DO NOTHING;

-- 5 orders per tenant → 1000 orders
INSERT INTO orders (id, tenant_id, status, total_cents, created_at)
SELECT
    (t.id * 1000) + o.n,
    t.id,
    (ARRAY['paid', 'pending', 'canceled', 'shipped', 'paid'])[o.n],
    500 + (t.id * 10) + (o.n * 100),
    now() - ((t.id + o.n) || ' hours')::interval
FROM tenants t
CROSS JOIN generate_series(1, 5) AS o(n)
ON CONFLICT (tenant_id, id) DO NOTHING;

-- 3 line items per order → 3000 order_items
INSERT INTO order_items (id, tenant_id, order_id, sku, quantity, unit_cents)
SELECT
    (o.id * 10) + i.n,
    o.tenant_id,
    o.id,
    'SKU-' || o.tenant_id || '-' || i.n,
    1 + (i.n % 3),
    100 + (o.tenant_id * 5) + (i.n * 25)
FROM orders o
CROSS JOIN generate_series(1, 3) AS i(n)
ON CONFLICT (tenant_id, id) DO NOTHING;

-- Totals
SELECT 'tenants' AS table_name, count(*) AS rows FROM tenants
UNION ALL
SELECT 'orders', count(*) FROM orders
UNION ALL
SELECT 'order_items', count(*) FROM order_items;

-- How many shards actually hold rows (orders)
SELECT
    nodename,
    count(*) FILTER (WHERE shard_size > 8192) AS nonempty_ish_shards,
    count(*) AS total_shards,
    pg_size_pretty(sum(shard_size)) AS total_size
FROM citus_shards
WHERE table_name = 'orders'::regclass
GROUP BY nodename
ORDER BY nodename;

-- Sample: which order shards have data (by disk size)
SELECT shardid, shard_name, nodename, pg_size_pretty(shard_size) AS size
FROM citus_shards
WHERE table_name = 'orders'::regclass
  AND shard_size > 8192
ORDER BY shard_size DESC, shardid
LIMIT 20;
