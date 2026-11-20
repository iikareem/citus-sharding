-- Fix: Citus requires PRIMARY KEY / UNIQUE to include the shard column (tenant_id).
-- Only needed if you created tables with PRIMARY KEY (id) alone.
-- After this, run 03_distribute.sql again.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_dist_partition WHERE logicalrelid = 'order_items'::regclass) THEN
    PERFORM undistribute_table('order_items', cascade_via_foreign_keys => true);
  END IF;
  IF EXISTS (SELECT 1 FROM pg_dist_partition WHERE logicalrelid = 'orders'::regclass) THEN
    PERFORM undistribute_table('orders', cascade_via_foreign_keys => true);
  END IF;
  IF EXISTS (SELECT 1 FROM pg_dist_partition WHERE logicalrelid = 'tenants'::regclass) THEN
    PERFORM undistribute_table('tenants', cascade_via_foreign_keys => true);
  END IF;
END $$;

ALTER TABLE order_items DROP CONSTRAINT IF EXISTS order_items_pkey;
ALTER TABLE order_items ADD PRIMARY KEY (tenant_id, id);

ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_pkey;
ALTER TABLE orders ADD PRIMARY KEY (tenant_id, id);
