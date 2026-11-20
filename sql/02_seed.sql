-- Step 02: seed sample multi-tenant data (all rows still on the coordinator)

INSERT INTO tenants (id, name) VALUES
    (1, 'Acme Shop'),
    (2, 'Beta Books'),
    (3, 'Cedar Coffee')
ON CONFLICT (id) DO NOTHING;

INSERT INTO orders (id, tenant_id, status, total_cents) VALUES
    (101, 1, 'paid',     4500),
    (102, 1, 'pending',  1200),
    (201, 2, 'paid',     8900),
    (301, 3, 'paid',     1500),
    (302, 3, 'canceled',  500)
ON CONFLICT (tenant_id, id) DO NOTHING;

INSERT INTO order_items (id, tenant_id, order_id, sku, quantity, unit_cents) VALUES
    (1001, 1, 101, 'SKU-A', 2, 1500),
    (1002, 1, 101, 'SKU-B', 1, 1500),
    (1003, 1, 102, 'SKU-C', 1, 1200),
    (2001, 2, 201, 'SKU-D', 1, 8900),
    (3001, 3, 301, 'SKU-E', 3,  500),
    (3002, 3, 302, 'SKU-F', 1,  500)
ON CONFLICT (tenant_id, id) DO NOTHING;
