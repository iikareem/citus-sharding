-- Step 02: create tables on the coordinator (still local Postgres — not sharded yet)

CREATE TABLE IF NOT EXISTS tenants (
    id          bigint PRIMARY KEY,
    name        text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- PK must include tenant_id so Citus can distribute by tenant_id later
CREATE TABLE IF NOT EXISTS orders (
    id          bigint NOT NULL,
    tenant_id   bigint NOT NULL REFERENCES tenants (id),
    status      text NOT NULL,
    total_cents integer NOT NULL CHECK (total_cents >= 0),
    created_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, id)
);

CREATE TABLE IF NOT EXISTS order_items (
    id          bigint NOT NULL,
    tenant_id   bigint NOT NULL REFERENCES tenants (id),
    order_id    bigint NOT NULL,
    sku         text NOT NULL,
    quantity    integer NOT NULL CHECK (quantity > 0),
    unit_cents  integer NOT NULL CHECK (unit_cents >= 0),
    PRIMARY KEY (tenant_id, id)
);

-- Helpful for later colocated lookups (still local for now)
CREATE INDEX IF NOT EXISTS orders_tenant_id_idx ON orders (tenant_id);
CREATE INDEX IF NOT EXISTS order_items_tenant_order_idx ON order_items (tenant_id, order_id);
